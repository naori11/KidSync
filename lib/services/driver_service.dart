import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_models.dart';

class DriverService {
  final supabase = Supabase.instance.client;

  /// Get driver assignments for the current driver
  Future<List<DriverAssignment>> getDriverAssignments(String driverId) async {
    try {
      print('Fetching driver assignments for driver: $driverId');
      
      final response = await supabase
          .from('driver_assignments')
          .select('''
            *,
            students!driver_assignments_student_id_fkey (
              id,
              fname,
              mname,
              lname,
              grade_level,
              section_id,
              rfid_uid,
              profile_image_url,
              sections!students_section_id_fkey (
                id,
                name,
                grade_level
              )
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'active');

      print('Raw response: $response');
      
      final assignments = <DriverAssignment>[];
      for (final json in response) {
        try {
          print('Processing assignment: $json');
          final assignment = DriverAssignment.fromJson(json);
          assignments.add(assignment);
        } catch (e) {
          print('Error parsing assignment: $e');
          print('JSON data: $json');
        }
      }
      
      print('Successfully parsed ${assignments.length} assignments');
      return assignments;
    } catch (e) {
      print('Error fetching driver assignments: $e');
      return [];
    }
  }

  /// Get today's pickup tasks for a driver
  Future<List<PickupTask>> getTodaysPickupTasks(String driverId) async {
    try {
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
      
      // Get driver assignments for today
      final assignments = await getDriverAssignments(driverId);
      
      // Filter assignments that have today in their schedule_days
      final todaysAssignments = assignments.where((assignment) {
        if (assignment.scheduleDays == null || assignment.scheduleDays!.isEmpty) {
          return false;
        }
        
        // Check if today's day is in the schedule
        final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final todayName = dayNames[dayOfWeek];
        
        return assignment.scheduleDays!.any((day) => 
          day.toLowerCase().contains(todayName.toLowerCase().substring(0, 3)) ||
          day.toLowerCase() == todayName.toLowerCase()
        );
      }).toList();

      if (todaysAssignments.isEmpty) {
        return [];
      }

      // Group assignments by school/pickup time
      final Map<String, List<DriverAssignment>> groupedAssignments = {};
      
      for (final assignment in todaysAssignments) {
        final student = assignment.student;
        if (student?.section?.name != null) {
          final key = '${student!.section!.name}_${assignment.pickupTime ?? 'default'}';
          groupedAssignments.putIfAbsent(key, () => []).add(assignment);
        }
      }

      // Create pickup tasks
      final tasks = <PickupTask>[];
      int taskId = 1;
      
      for (final entry in groupedAssignments.entries) {
        final assignments = entry.value;
        final firstAssignment = assignments.first;
        final student = firstAssignment.student!;
        
        final students = assignments.map((assignment) {
          final s = assignment.student!;
          return Student(
            id: s.id.toString(),
            name: '${s.fname} ${s.mname ?? ''} ${s.lname}'.trim(),
            grade: s.gradeLevel ?? student.section?.gradeLevel ?? 'Unknown',
            studentDbId: s.id,
            sectionName: s.section?.name,
          );
        }).toList();

        tasks.add(PickupTask(
          id: 'task_$taskId',
          date: today,
          schoolName: student.section?.name ?? 'School',
          pickupTime: firstAssignment.pickupTime ?? '3:30 PM',
          students: students,
        ));
        
        taskId++;
      }

      return tasks;
    } catch (e) {
      print('Error fetching today\'s pickup tasks: $e');
      return [];
    }
  }

  /// Record a pickup event
  Future<bool> recordPickup({
    required int studentId,
    required String driverId,
    required DateTime pickupTime,
    String? notes,
  }) async {
    try {
      await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'pickup_time': pickupTime.toIso8601String(),
        'event_type': 'pickup',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify parents
      await _notifyParents(studentId, 'pickup', pickupTime);
      
      return true;
    } catch (e) {
      print('Error recording pickup: $e');
      return false;
    }
  }

  /// Record a dropoff event
  Future<bool> recordDropoff({
    required int studentId,
    required String driverId,
    required DateTime dropoffTime,
    String? notes,
  }) async {
    try {
      await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'dropoff_time': dropoffTime.toIso8601String(),
        'event_type': 'dropoff',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify parents
      await _notifyParents(studentId, 'dropoff', dropoffTime);
      
      return true;
    } catch (e) {
      print('Error recording dropoff: $e');
      return false;
    }
  }

  /// Get pickup/dropoff logs for today
  Future<List<PickupDropoffLog>> getTodaysLogs(String driverId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('''
            *,
            students!pickup_dropoff_logs_student_id_fkey (
              id,
              fname,
              mname,
              lname,
              grade_level
            )
          ''')
          .eq('driver_id', driverId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false);

      return response.map<PickupDropoffLog>((json) => PickupDropoffLog.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching today\'s logs: $e');
      return [];
    }
  }

  /// Check if student was picked up today
  Future<bool> wasStudentPickedUpToday(int studentId, String driverId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'pickup')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking pickup status: $e');
      return false;
    }
  }

  /// Check if student was dropped off today
  Future<bool> wasStudentDroppedOffToday(int studentId, String driverId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'dropoff')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking dropoff status: $e');
      return false;
    }
  }

  /// Get pickup time for a student today
  Future<DateTime?> getStudentPickupTime(int studentId, String driverId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('pickup_time')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'pickup')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty && response.first['pickup_time'] != null) {
        return DateTime.parse(response.first['pickup_time']);
      }
      return null;
    } catch (e) {
      print('Error getting pickup time: $e');
      return null;
    }
  }

  /// Private method to notify parents
  Future<void> _notifyParents(int studentId, String eventType, DateTime eventTime) async {
    try {
      // Get parent information for the student
      final parentResponse = await supabase
          .from('parent_student')
          .select('''
            parents!parent_student_parent_id_fkey (
              id,
              fname,
              lname,
              email,
              phone,
              user_id
            )
          ''')
          .eq('student_id', studentId);

      // Get student information
      final studentResponse = await supabase
          .from('students')
          .select('fname, mname, lname')
          .eq('id', studentId)
          .single();

      final studentName = '${studentResponse['fname']} ${studentResponse['mname'] ?? ''} ${studentResponse['lname']}'.trim();

      // Get driver information
      final driverResponse = await supabase
          .from('users')
          .select('fname, lname')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      final driverName = '${driverResponse['fname']} ${driverResponse['lname']}'.trim();

      // Create notification records for each parent
      for (final parentData in parentResponse) {
        final parent = parentData['parents'];
        if (parent != null) {
          await supabase.from('notifications').insert({
            'recipient_id': parent['user_id'],
            'title': eventType == 'pickup' ? 'Student Picked Up' : 'Student Dropped Off',
            'message': '$studentName has been ${eventType == 'pickup' ? 'picked up' : 'dropped off'} by $driverName at ${_formatTime(eventTime)}',
            'type': eventType,
            'student_id': studentId,
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });
        }
      }
    } catch (e) {
      print('Error notifying parents: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}