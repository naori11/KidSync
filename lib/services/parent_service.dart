import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parent_models.dart';

class ParentService {
  final supabase = Supabase.instance.client;

  /// Get student's assigned driver information
  Future<Map<String, dynamic>?> getStudentDriver(int studentId) async {
    try {
      final response = await supabase
          .from('driver_assignments')
          .select('''
            pickup_time,
            dropoff_time,
            schedule_days,
            status,
            drivers:users!driver_assignments_driver_id_fkey(
              id,
              fname,
              lname,
              contact_number,
              email,
              profile_image_url,
              plate_number
            )
          ''')
          .eq('student_id', studentId)
          .eq('status', 'active')
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting student driver: $e');
      return null;
    }
  }

  /// Get today's pickup/dropoff status for a student
  Future<Map<String, dynamic>> getTodayPickupStatus(int studentId) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check pickup status
      final pickupResponse = await supabase
          .from('pickup_records')
          .select('''
            pickup_time,
            driver_id,
            drivers!inner(fname, lname)
          ''')
          .eq('student_id', studentId)
          .gte('pickup_time', '${todayStr}T00:00:00')
          .lt('pickup_time', '${todayStr}T23:59:59')
          .maybeSingle();

      // Check dropoff status
      final dropoffResponse = await supabase
          .from('dropoff_records')
          .select('''
            dropoff_time,
            driver_id,
            drivers!inner(fname, lname)
          ''')
          .eq('student_id', studentId)
          .gte('dropoff_time', '${todayStr}T00:00:00')
          .lt('dropoff_time', '${todayStr}T23:59:59')
          .maybeSingle();

      return {
        'pickup': pickupResponse,
        'dropoff': dropoffResponse,
        'date': todayStr,
      };
    } catch (e) {
      print('Error getting today pickup status: $e');
      return {
        'pickup': null,
        'dropoff': null,
        'date': null,
      };
    }
  }

  /// Get student's pickup/dropoff patterns for today
  Future<Map<String, dynamic>> getTodayPatterns(int studentId) async {
    try {
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check for exceptions first
      final exceptionResponse = await supabase
          .from('pickup_dropoff_exceptions')
          .select('pickup_person, dropoff_person, reason')
          .eq('student_id', studentId)
          .eq('exception_date', todayStr)
          .maybeSingle();

      if (exceptionResponse != null) {
        return {
          'pickup_person': exceptionResponse['pickup_person'] ?? 'driver',
          'dropoff_person': exceptionResponse['dropoff_person'] ?? 'driver',
          'exception_reason': exceptionResponse['reason'],
          'is_exception': true,
        };
      }

      // Check regular patterns
      final patternResponse = await supabase
          .from('pickup_dropoff_patterns')
          .select('pickup_person, dropoff_person')
          .eq('student_id', studentId)
          .eq('day_of_week', dayOfWeek)
          .maybeSingle();

      if (patternResponse != null) {
        return {
          'pickup_person': patternResponse['pickup_person'] ?? 'driver',
          'dropoff_person': patternResponse['dropoff_person'] ?? 'driver',
          'exception_reason': null,
          'is_exception': false,
        };
      }

      // Default to driver
      return {
        'pickup_person': 'driver',
        'dropoff_person': 'driver',
        'exception_reason': null,
        'is_exception': false,
      };
    } catch (e) {
      print('Error getting today patterns: $e');
      return {
        'pickup_person': 'driver',
        'dropoff_person': 'driver',
        'exception_reason': null,
        'is_exception': false,
      };
    }
  }

  /// Get student's basic information
  Future<Map<String, dynamic>?> getStudentInfo(int studentId) async {
    try {
      final response = await supabase
          .from('students')
          .select('''
            id,
            fname,
            lname,
            grade_level,
            address,
            sections(name, grade_level)
          ''')
          .eq('id', studentId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error getting student info: $e');
      return null;
    }
  }

  /// Get parent's notifications for a specific student
  Future<List<Map<String, dynamic>>> getStudentNotifications(int studentId, {int limit = 20}) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('''
            id,
            title,
            message,
            type,
            created_at,
            read_at,
            data
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting student notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Get unread notification count for a student
  Future<int> getUnreadNotificationCount(int studentId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('student_id', studentId)
          .isFilter('read_at', null);

      return response.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }
}