import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final supabase = Supabase.instance.client;
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Stream controllers for real-time updates
  final _pickupStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _dropoffStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get pickupStatusStream =>
      _pickupStatusController.stream;
  Stream<Map<String, dynamic>> get dropoffStatusStream =>
      _dropoffStatusController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  RealtimeChannel? _pickupChannel;
  RealtimeChannel? _dropoffChannel;
  RealtimeChannel? _notificationChannel;

  /// Initialize real-time subscriptions for a specific student
  void initializeForStudent(int studentId) {
    _subscribeToPickupUpdates(studentId);
    _subscribeToDropoffUpdates(studentId);
    _subscribeToNotifications(studentId);
  }

  /// Subscribe to pickup record updates
  void _subscribeToPickupUpdates(int studentId) {
    _pickupChannel?.unsubscribe();

    _pickupChannel =
        supabase
            .channel('pickup_records_$studentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'pickup_records',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'student_id',
                value: studentId,
              ),
              callback: (payload) {
                print('Pickup record inserted: ${payload.newRecord}');
                _pickupStatusController.add({
                  'type': 'pickup',
                  'action': 'insert',
                  'data': payload.newRecord,
                  'student_id': studentId,
                });
              },
            )
            .subscribe();
  }

  /// Subscribe to dropoff record updates
  void _subscribeToDropoffUpdates(int studentId) {
    _dropoffChannel?.unsubscribe();

    _dropoffChannel =
        supabase
            .channel('dropoff_records_$studentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'dropoff_records',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'student_id',
                value: studentId,
              ),
              callback: (payload) {
                print('Dropoff record inserted: ${payload.newRecord}');
                _dropoffStatusController.add({
                  'type': 'dropoff',
                  'action': 'insert',
                  'data': payload.newRecord,
                  'student_id': studentId,
                });
              },
            )
            .subscribe();
  }

  /// Subscribe to notification updates
  void _subscribeToNotifications(int studentId) {
    _notificationChannel?.unsubscribe();

    _notificationChannel =
        supabase
            .channel('notifications_$studentId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'student_id',
                value: studentId,
              ),
              callback: (payload) {
                print('New notification: ${payload.newRecord}');
                _notificationController.add({
                  'type': 'notification',
                  'action': 'insert',
                  'data': payload.newRecord,
                  'student_id': studentId,
                });
              },
            )
            .subscribe();
  }

  // Legacy notification methods removed - notifications are now handled 
  // directly in driver_service._notifyParents() method

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Get notifications for a parent filtered by student and date
  Future<List<Map<String, dynamic>>> getParentNotifications(
    int parentId, {
    int? studentId,
    bool todayOnly = false,
    int limit = 5,
  }) async {
    try {
      // Resolve parent -> user id (notifications.recipient_id references users.id)
      final parent =
          await supabase
              .from('parents')
              .select('user_id')
              .eq('id', parentId)
              .maybeSingle();

      if (parent == null || parent['user_id'] == null) {
        return [];
      }

      final String userId = parent['user_id'];

      // Build query
      var query = supabase
          .from('notifications')
          .select('*')
          .eq('recipient_id', userId);

      // Filter by student if provided
      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }

      // Filter by today if requested
      if (todayOnly) {
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        
        query = query
            .gte('created_at', todayStart.toIso8601String())
            .lt('created_at', todayEnd.toIso8601String());
      }

      final notifications = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(notifications);
    } catch (e) {
      print('Error getting parent notifications: $e');
      return [];
    }
  }

  /// Get unread notification count for a parent
  Future<int> getUnreadNotificationCount(int parentId, {int? studentId}) async {
    try {
      final parent =
          await supabase
              .from('parents')
              .select('user_id')
              .eq('id', parentId)
              .maybeSingle();

      if (parent == null || parent['user_id'] == null) {
        return 0;
      }

      final String userId = parent['user_id'];

      var query = supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  /// Mark notifications as read for a parent and student
  Future<bool> markNotificationsAsRead(int parentId, {int? studentId}) async {
    try {
      final parent =
          await supabase
              .from('parents')
              .select('user_id')
              .eq('id', parentId)
              .maybeSingle();

      if (parent == null || parent['user_id'] == null) {
        return false;
      }

      final String userId = parent['user_id'];

      var query = supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('recipient_id', userId)
          .eq('is_read', false);

      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }

      await query;
      return true;
    } catch (e) {
      print('Error marking notifications as read: $e');
      return false;
    }
  }

  /// Get today's pickup/dropoff status for a student
  Future<Map<String, dynamic>> getTodayStatus(int studentId) async {
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check pickup status from logs
      final pickupResponse =
          await supabase
              .from('pickup_dropoff_logs')
              .select('''
            pickup_time,
            driver_id,
            drivers:users!pickup_dropoff_logs_driver_id_fkey (fname, lname, profile_image_url)
          ''')
              .eq('student_id', studentId)
              .eq('event_type', 'pickup')
              .gte('created_at', '${todayStr}T00:00:00')
              .lt('created_at', '${todayStr}T23:59:59')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      // Check dropoff status from logs
      final dropoffResponse =
          await supabase
              .from('pickup_dropoff_logs')
              .select('''
            dropoff_time,
            driver_id,
            drivers:users!pickup_dropoff_logs_driver_id_fkey (fname, lname, profile_image_url)
          ''')
              .eq('student_id', studentId)
              .eq('event_type', 'dropoff')
              .gte('created_at', '${todayStr}T00:00:00')
              .lt('created_at', '${todayStr}T23:59:59')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      return {
        'pickup': pickupResponse,
        'dropoff': dropoffResponse,
        'date': todayStr,
      };
    } catch (e) {
      print('Error getting today status: $e');
      return {'pickup': null, 'dropoff': null, 'date': null};
    }
  }

  /// Get student's assigned driver information
  Future<Map<String, dynamic>?> getStudentDriver(int studentId) async {
    try {
      // Query driver_assignments and include the related users record via FK
      // Alias the users relation as 'drivers' so UI can access driverInfo['drivers']
      final response =
          await supabase
              .from('driver_assignments')
              .select('''
            pickup_time,
            dropoff_time,
            drivers:users!driver_assignments_driver_id_fkey (
              id, fname, mname, lname, contact_number, profile_image_url
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

  /// Clean up subscriptions
  void dispose() {
    _pickupChannel?.unsubscribe();
    _dropoffChannel?.unsubscribe();
    _notificationChannel?.unsubscribe();
    _pickupStatusController.close();
    _dropoffStatusController.close();
    _notificationController.close();
  }

  /// Unsubscribe from current student
  void unsubscribeFromStudent() {
    _pickupChannel?.unsubscribe();
    _dropoffChannel?.unsubscribe();
    _notificationChannel?.unsubscribe();
  }
}
