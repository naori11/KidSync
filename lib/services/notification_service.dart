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

  /// Get all recent notifications for a parent (including pickup denials) - not limited to today
  Future<List<Map<String, dynamic>>> getParentAllNotifications(
    int parentId, {
    int? studentId,
    int limit = 10,
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

      // Build query - include all notification types
      var query = supabase
          .from('notifications')
          .select('*')
          .eq('recipient_id', userId);

      // Filter by student if provided
      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }

      // Get recent notifications, prioritizing unread ones
      final notifications = await query
          .order('is_read', ascending: false) // Unread first
          .order('created_at', ascending: false) // Then by creation time
          .limit(limit);

      return List<Map<String, dynamic>>.from(notifications);
    } catch (e) {
      print('Error getting parent all notifications: $e');
      return [];
    }
  }

  /// Get notifications by type for a parent
  Future<List<Map<String, dynamic>>> getParentNotificationsByType(
    int parentId, {
    int? studentId,
    String? notificationType,
    int limit = 20,
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

      // Filter by type if provided
      if (notificationType != null) {
        query = query.eq('type', notificationType);
      }

      // Get notifications, prioritizing unread ones
      final notifications = await query
          .order('is_read', ascending: false) // Unread first
          .order('created_at', ascending: false) // Then by creation time
          .limit(limit);

      return List<Map<String, dynamic>>.from(notifications);
    } catch (e) {
      print('Error getting parent notifications by type: $e');
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
            drivers:users!pickup_dropoff_logs_driver_id_fkey (fname, lname, profile_image_url, plate_number)
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
            drivers:users!pickup_dropoff_logs_driver_id_fkey (fname, lname, profile_image_url, plate_number)
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
              id, fname, mname, lname, contact_number, profile_image_url, plate_number
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

  /// Get today's RFID scan records for a student
  Future<Map<String, dynamic>> getTodayRfidStatus(int studentId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get today's scan records ordered by scan time
      final scanRecords = await supabase
          .from('scan_records')
          .select('''
            action,
            scan_time,
            status,
            verified_by,
            notes,
            guard_id
          ''')
          .eq('student_id', studentId)
          .gte('scan_time', todayStart.toIso8601String())
          .lt('scan_time', todayEnd.toIso8601String())
          .order('scan_time', ascending: true);

      // Find the latest entry and exit records
      Map<String, dynamic>? latestEntry;
      Map<String, dynamic>? latestExit;

      for (final record in scanRecords) {
        if (record['action'] == 'entry') {
          latestEntry = record;
        } else if (record['action'] == 'exit') {
          latestExit = record;
        }
      }

      return {
        'entry': latestEntry,
        'exit': latestExit,
        'all_records': scanRecords,
        'date': todayStart.toIso8601String().split('T')[0],
      };
    } catch (e) {
      print('Error getting today RFID status: $e');
      return {
        'entry': null,
        'exit': null,
        'all_records': [],
        'date': null,
      };
    }
  }

  /// Send RFID tap notification to all parents of a student
  Future<bool> sendRfidTapNotification({
    required int studentId,
    required String action, // 'entry' or 'exit'
    required String studentName,
    String? guardName,
  }) async {
    try {
      // Try using the RPC function first (better for RLS and performance)
      final result = await supabase.rpc('create_rfid_notification', params: {
        'p_student_id': studentId,
        'p_action': action,
        'p_student_name': studentName,
        'p_guard_name': guardName,
      });
      
      if (result == true) {
        print('DEBUG: RFID notification sent successfully via RPC for student $studentId, action: $action');
        return true;
      } else {
        print('DEBUG: RPC function returned false for RFID notification');
        return false;
      }
    } catch (rpcError) {
      print('Error calling create_rfid_notification RPC: $rpcError');
      
      // Fallback to direct insert if RPC fails
      try {
        // Get all parents for this student
        final parentStudentResponse = await supabase
            .from('parent_student')
            .select('''
              parent_id,
              parents!inner(
                user_id,
                fname,
                lname
              )
            ''')
            .eq('student_id', studentId);

        if (parentStudentResponse.isEmpty) {
          print('DEBUG: No parents found for student $studentId');
          return false;
        }

        // Prepare notification data
        String title;
        String message;
        String notificationType;

        if (action == 'entry') {
          title = 'Student Arrival';
          message = '$studentName has arrived at school and tapped in.';
          notificationType = 'rfid_entry';
        } else if (action == 'exit') {
          title = 'Student Departure';
          message = '$studentName has left school and tapped out.';
          notificationType = 'rfid_exit';
        } else {
          print('DEBUG: Invalid action type: $action');
          return false;
        }

        // Add guard info if available
        if (guardName != null && guardName.isNotEmpty) {
          message += ' Verified by: $guardName';
        }

        // Send notification to each parent
        final List<Map<String, dynamic>> notifications = [];
        for (final parentData in parentStudentResponse) {
          final userId = parentData['parents']['user_id'];
          if (userId != null) {
            notifications.add({
              'recipient_id': userId,
              'title': title,
              'message': message,
              'type': notificationType,
              'student_id': studentId,
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (notifications.isNotEmpty) {
          try {
            await supabase.from('notifications').insert(notifications);
            print('DEBUG: RFID notification sent successfully via direct insert for student $studentId, action: $action');
            return true;
          } catch (insertError) {
            print('Error inserting RFID notifications: $insertError');
            return false;
          }
        }

        return false;
      } catch (fallbackError) {
        print('Error in fallback RFID notification method: $fallbackError');
        return false;
      }
    }
  }

  /// Send pickup denial notification to all parents of a student
  Future<bool> sendPickupDenialNotification({
    required int studentId,
    required String studentName,
    required String denyReason,
    String? guardName,
    String? fetcherName,
    String? fetcherType, // 'authorized' or 'temporary'
  }) async {
    try {
      print('DEBUG: Attempting to send pickup denial notification for student $studentId');
      
      // Try using the RPC function first (better for RLS)
      try {
        final result = await supabase.rpc('create_pickup_denial_notification', params: {
          'p_student_id': studentId,
          'p_student_name': studentName,
          'p_deny_reason': denyReason,
          'p_guard_name': guardName,
          'p_fetcher_name': fetcherName,
          'p_fetcher_type': fetcherType,
        });
        
        if (result == true) {
          print('DEBUG: Pickup denial notification sent successfully via RPC for student $studentId');
          return true;
        } else {
          print('DEBUG: RPC function returned false for pickup denial notification');
        }
      } catch (rpcError) {
        print('DEBUG: RPC function call failed: $rpcError');
      }
      
      // Fallback to direct insert if RPC fails or returns false
      print('DEBUG: Falling back to direct insert for pickup denial notification');
      
      try {
        // Get all parents for this student
        final parentStudentResponse = await supabase
            .from('parent_student')
            .select('''
              parent_id,
              parents!inner(
                user_id,
                fname,
                lname
              )
            ''')
            .eq('student_id', studentId);

        if (parentStudentResponse.isEmpty) {
          print('DEBUG: No parents found for student $studentId');
          return false;
        }

        print('DEBUG: Found ${parentStudentResponse.length} parents for student $studentId');

        // Prepare notification data
        String title = 'Pickup Request Denied';
        String message = 'Your pickup request for $studentName has been denied.';
        
        // Add fetcher information if available
        if (fetcherName != null && fetcherName.isNotEmpty) {
          if (fetcherType == 'temporary') {
            message += ' Temporary fetcher: $fetcherName';
          } else {
            message += ' Fetcher: $fetcherName';
          }
        }
        
        // Add denial reason
        message += ' Reason: $denyReason';
        
        // Add guard info if available
        if (guardName != null && guardName.isNotEmpty) {
          message += ' Denied by: $guardName';
        }

        print('DEBUG: Prepared pickup denial message: $message');

        // Send notification to each parent
        final List<Map<String, dynamic>> notifications = [];
        for (final parentData in parentStudentResponse) {
          final userId = parentData['parents']['user_id'];
          if (userId != null) {
            notifications.add({
              'recipient_id': userId,
              'title': title,
              'message': message,
              'type': 'pickup_denied',
              'student_id': studentId,
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
            print('DEBUG: Added notification for parent user $userId');
          } else {
            print('DEBUG: Parent ${parentData['parent_id']} has no user_id');
          }
        }

        if (notifications.isNotEmpty) {
          try {
            // Insert notifications directly as fallback
            final insertResult = await supabase.from('notifications').insert(notifications);
            print('DEBUG: Pickup denial notification sent successfully via direct insert for student $studentId');
            print('DEBUG: Insert result: $insertResult');
            return true;
          } catch (insertError) {
            print('Error inserting pickup denial notifications: $insertError');
            return false;
          }
        } else {
          print('DEBUG: No valid notifications to insert');
          return false;
        }

      } catch (fallbackError) {
        print('Error in fallback pickup denial notification method: $fallbackError');
        return false;
      }
    } catch (e) {
      print('Unexpected error in sendPickupDenialNotification: $e');
      return false;
    }
  }

  /// Test method to manually test notification creation
  Future<bool> testNotificationSystem({
    required int studentId,
    required String studentName,
  }) async {
    try {
      print('DEBUG: Testing notification system for student $studentId');
      
      // Test direct database access first
      final parentStudentResponse = await supabase
          .from('parent_student')
          .select('''
            parent_id,
            parents!inner(
              user_id,
              fname,
              lname,
              status
            )
          ''')
          .eq('student_id', studentId);

      print('DEBUG: Parent-student relationship query result: $parentStudentResponse');

      if (parentStudentResponse.isEmpty) {
        print('DEBUG: No parent-student relationships found for student $studentId');
        return false;
      }

      // Test RPC function
      try {
        final rpcResult = await supabase.rpc('create_pickup_denial_notification', params: {
          'p_student_id': studentId,
          'p_student_name': studentName,
          'p_deny_reason': 'Test notification from Flutter app',
          'p_guard_name': 'Test Guard',
          'p_fetcher_name': 'Test Fetcher',
          'p_fetcher_type': 'authorized',
        });
        
        print('DEBUG: RPC function test result: $rpcResult');
        
        // Check if notifications were created
        final notifications = await supabase
            .from('notifications')
            .select('*')
            .eq('student_id', studentId)
            .eq('type', 'pickup_denied')
            .order('created_at', ascending: false)
            .limit(5);
            
        print('DEBUG: Found ${notifications.length} pickup denial notifications for student $studentId');
        
        return rpcResult == true;
      } catch (rpcError) {
        print('DEBUG: RPC function test failed: $rpcError');
        return false;
      }
    } catch (e) {
      print('DEBUG: Test notification system error: $e');
      return false;
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