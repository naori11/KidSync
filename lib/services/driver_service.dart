import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/driver_models.dart';
import '../utils/time_utils.dart';
import 'notification_service.dart';
import 'verification_service.dart';

class DriverService {
  final supabase = Supabase.instance.client;
  final notificationService = NotificationService();
  final verificationService = VerificationService();

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

  /// Get today's students with pickup/dropoff patterns for driver
  Future<Map<String, dynamic>> getTodaysStudentsWithPatterns(String driverId) async {
    try {
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
      final todayDate = DateFormat('yyyy-MM-dd').format(today);

      print('Loading students for driver: $driverId, day: $dayOfWeek, date: $todayDate');

      // Get students assigned to this driver
      final assignedStudentsResponse = await supabase
          .from('driver_assignments')
          .select('''
            student_id,
            pickup_time,
            dropoff_time,
            schedule_days,
            students!inner(
              id,
              fname,
              lname,
              grade_level,
              address,
              sections(name, grade_level)
            )
          ''')
          .eq('driver_id', driverId)
          .eq('status', 'active');

      print('Found ${assignedStudentsResponse.length} assigned students');

      List<Map<String, dynamic>> allStudents = [];
      List<Map<String, dynamic>> morningPickupList = [];
      List<Map<String, dynamic>> afternoonDropoffList = [];

      for (var assignment in assignedStudentsResponse) {
        final student = assignment['students'];
        final studentId = student['id'];

        // Check if today is in the schedule days
        final scheduleDays = assignment['schedule_days'];
        bool isScheduledToday = false;

        if (scheduleDays != null) {
          List<String> days = [];
          if (scheduleDays is List) {
            days = scheduleDays.cast<String>();
          } else if (scheduleDays is String) {
            // Handle PostgreSQL array format
            String daysStr = scheduleDays.toString();
            if (daysStr.startsWith('{') && daysStr.endsWith('}')) {
              daysStr = daysStr.substring(1, daysStr.length - 1);
            }
            days = daysStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }

          // Check if today's day name is in the schedule
          final dayNames = [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          final todayName = dayNames[dayOfWeek - 1];
          isScheduledToday = days.contains(todayName);
        }

        if (!isScheduledToday) continue; // Skip if not scheduled today

        // Check for exceptions for today
        final exceptionResponse = await supabase
            .from('pickup_dropoff_exceptions')
            .select('pickup_person, dropoff_person, reason')
            .eq('student_id', studentId)
            .eq('exception_date', todayDate);

        // Check pattern for today
        final patternResponse = await supabase
            .from('pickup_dropoff_patterns')
            .select('pickup_person, dropoff_person')
            .eq('student_id', studentId)
            .eq('day_of_week', dayOfWeek);

        String pickupPerson = 'driver'; // default
        String dropoffPerson = 'driver'; // default
        String? exceptionReason;

        // Use exception if exists, otherwise use pattern, otherwise default
        if (exceptionResponse.isNotEmpty) {
          final exception = exceptionResponse.first;
          pickupPerson = exception['pickup_person'] ?? 'driver';
          dropoffPerson = exception['dropoff_person'] ?? 'driver';
          exceptionReason = exception['reason'];
        } else if (patternResponse.isNotEmpty) {
          final pattern = patternResponse.first;
          pickupPerson = pattern['pickup_person'] ?? 'driver';
          dropoffPerson = pattern['dropoff_person'] ?? 'driver';
        }

        final studentData = {
          ...assignment,
          'pickup_person': pickupPerson,
          'dropoff_person': dropoffPerson,
          'exception_reason': exceptionReason,
          'full_name': '${student['fname']} ${student['lname']}',
          'is_driver_responsible_pickup': pickupPerson == 'driver',
          'is_driver_responsible_dropoff': dropoffPerson == 'driver',
        };

        allStudents.add(studentData);

        // Add to morning pickup list if driver should pick up (dropoff_person = driver means morning pickup)
        if (dropoffPerson == 'driver') {
          morningPickupList.add({...studentData, 'task_type': 'morning_pickup'});
        }

        // Add to afternoon dropoff list if driver should drop off (pickup_person = driver means afternoon dropoff)
        if (pickupPerson == 'driver') {
          afternoonDropoffList.add({...studentData, 'task_type': 'afternoon_dropoff'});
        }
      }

      // Sort by time
      morningPickupList.sort(
        (a, b) => (a['pickup_time'] ?? '').compareTo(b['pickup_time'] ?? ''),
      );
      afternoonDropoffList.sort(
        (a, b) => (a['dropoff_time'] ?? '').compareTo(b['dropoff_time'] ?? ''),
      );

      print('Loaded ${allStudents.length} students for today');
      print('Morning pickup tasks: ${morningPickupList.length}');
      print('Afternoon dropoff tasks: ${afternoonDropoffList.length}');

      return {
        'all_students': allStudents,
        'morning_pickup': morningPickupList,
        'afternoon_dropoff': afternoonDropoffList,
      };
    } catch (e) {
      print('Error loading today\'s students with patterns: $e');
      rethrow;
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
      // Insert pickup log and get the ID
      final logResponse = await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'pickup_time': pickupTime.toIso8601String(),
        'event_type': 'pickup',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      final logId = logResponse['id'];

      // Create verification request for parents
      await verificationService.createVerificationRequest(
        studentId: studentId,
        driverId: driverId,
        eventType: 'pickup',
        eventTime: pickupTime,
        pickupDropoffLogId: logId,
      );

      // Get student and driver names for notification
      final studentResponse = await supabase
          .from('students')
          .select('fname, lname')
          .eq('id', studentId)
          .maybeSingle();

      final driverResponse = await supabase
          .from('users')
          .select('fname, lname')
          .eq('id', driverId)
          .maybeSingle();

      if (studentResponse != null && driverResponse != null) {
        final studentName = '${studentResponse['fname']} ${studentResponse['lname']}';

        // Send verification request notification to driver
        await notificationService.sendVerificationRequestNotification(
          driverId: driverId,
          studentId: studentId,
          studentName: studentName,
          eventType: 'pickup',
          eventTime: pickupTime,
        );
      }

      // Notify parents (legacy method)
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
      // Insert dropoff log and get the ID
      final logResponse = await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'dropoff_time': dropoffTime.toIso8601String(),
        'event_type': 'dropoff',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();

      final logId = logResponse['id'];

      // Create verification request for parents
      await verificationService.createVerificationRequest(
        studentId: studentId,
        driverId: driverId,
        eventType: 'dropoff',
        eventTime: dropoffTime,
        pickupDropoffLogId: logId,
      );

      // Get student and driver names for notification
      final studentResponse = await supabase
          .from('students')
          .select('fname, lname')
          .eq('id', studentId)
          .maybeSingle();

      final driverResponse = await supabase
          .from('users')
          .select('fname, lname')
          .eq('id', driverId)
          .maybeSingle();

      if (studentResponse != null && driverResponse != null) {
        final studentName = '${studentResponse['fname']} ${studentResponse['lname']}';

        // Send verification request notification to driver
        await notificationService.sendVerificationRequestNotification(
          driverId: driverId,
          studentId: studentId,
          studentName: studentName,
          eventType: 'dropoff',
          eventTime: dropoffTime,
        );
      }

      // Notify parents (legacy method)
      await _notifyParents(studentId, 'dropoff', dropoffTime);
      
      return true;
    } catch (e) {
      print('Error recording dropoff: $e');
      return false;
    }
  }

  /// Cancel a pickup event with reason and cleanup
  Future<bool> cancelPickup({
    required int studentId,
    required String driverId,
    required String reason,
    String? notes,
  }) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Find the pickup record to cancel
      final existingPickup = await supabase
          .from('pickup_dropoff_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'pickup')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingPickup == null) {
        print('No pickup record found to cancel for student $studentId');
        return false;
      }

      final logId = existingPickup['id'];

      // Insert cancellation record
      await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'event_type': 'pickup_cancelled',
        'notes': 'CANCELLED - Reason: $reason${notes != null ? '. Notes: $notes' : ''}',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update original pickup record to mark as cancelled
      await supabase
          .from('pickup_dropoff_logs')
          .update({
            'notes': (existingPickup['notes'] ?? '') + ' [CANCELLED - $reason]',
          })
          .eq('id', logId);

      // Cancel any pending verification requests
      await _cancelVerificationRequest(logId, studentId, driverId, 'pickup');

      // Notify parents of cancellation
      await _notifyParentsCancellation(studentId, 'pickup', reason);

      return true;
    } catch (e) {
      print('Error cancelling pickup: $e');
      return false;
    }
  }

  /// Cancel a dropoff event with reason and cleanup
  Future<bool> cancelDropoff({
    required int studentId,
    required String driverId,
    required String reason,
    String? notes,
  }) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Find the dropoff record to cancel
      final existingDropoff = await supabase
          .from('pickup_dropoff_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'dropoff')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingDropoff == null) {
        print('No dropoff record found to cancel for student $studentId');
        return false;
      }

      final logId = existingDropoff['id'];

      // Insert cancellation record
      await supabase.from('pickup_dropoff_logs').insert({
        'student_id': studentId,
        'driver_id': driverId,
        'event_type': 'dropoff_cancelled',
        'notes': 'CANCELLED - Reason: $reason${notes != null ? '. Notes: $notes' : ''}',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update original dropoff record to mark as cancelled
      await supabase
          .from('pickup_dropoff_logs')
          .update({
            'notes': (existingDropoff['notes'] ?? '') + ' [CANCELLED - $reason]',
          })
          .eq('id', logId);

      // Cancel any pending verification requests
      await _cancelVerificationRequest(logId, studentId, driverId, 'dropoff');

      // Notify parents of cancellation
      await _notifyParentsCancellation(studentId, 'dropoff', reason);

      return true;
    } catch (e) {
      print('Error cancelling dropoff: $e');
      return false;
    }
  }

  /// Helper method to cancel verification requests
  Future<void> _cancelVerificationRequest(int logId, int studentId, String driverId, String eventType) async {
    try {
      // Update verification status to cancelled
      await supabase
          .from('pickup_dropoff_verifications')
          .update({
            'status': 'cancelled',
            'notes': 'Cancelled by driver',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('pickup_dropoff_log_id', logId)
          .eq('status', 'pending');
      
      print('✅ Verification request cancelled for $eventType log $logId');
    } catch (e) {
      print('Error cancelling verification request: $e');
    }
  }

  /// Helper method to notify parents of cancellations
  Future<void> _notifyParentsCancellation(int studentId, String eventType, String reason) async {
    try {
      // Get student information
      final studentResponse = await supabase
          .from('students')
          .select('fname, lname')
          .eq('id', studentId)
          .maybeSingle();

      if (studentResponse != null) {
        final studentName = '${studentResponse['fname']} ${studentResponse['lname']}';
        
        // Create notification record for cancellation
        await supabase.from('notifications').insert({
          'user_id': null, // Will be sent to all parents of this student
          'type': 'pickup_dropoff_cancellation',
          'title': '${eventType == 'pickup' ? 'Pickup' : 'Dropoff'} Cancelled',
          'message': '$studentName\'s ${eventType} has been cancelled. Reason: $reason',
          'data': {
            'student_id': studentId,
            'student_name': studentName,
            'event_type': eventType,
            'reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          },
          'created_at': DateTime.now().toIso8601String(),
        });
        
        print('✅ Cancellation notification sent for $studentName $eventType');
      }
    } catch (e) {
      print('Error notifying parents of cancellation: $e');
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