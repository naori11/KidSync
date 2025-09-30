import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_notification_service.dart';

class NotificationService {
  final supabase = Supabase.instance.client;
  final PushNotificationService _pushService = PushNotificationService();
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

        return true;
      } else {

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

            
            // Send push notifications to each parent
            for (final parentData in parentStudentResponse) {
              final userId = parentData['parents']['user_id'];
              if (userId != null) {
                await _sendPushNotification(
                  recipientId: userId,
                  title: title,
                  message: message,
                  type: notificationType,
                  studentId: studentId,
                  extraData: {
                    'guard_name': guardName ?? '',
                    'action': action,
                  },
                );
              }
            }
            
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

          return true;
        } else {

        }
      } catch (rpcError) {

      }
      
      // Fallback to direct insert if RPC fails or returns false

      
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
            
            // Send push notifications to each parent
            for (final parentData in parentStudentResponse) {
              final userId = parentData['parents']['user_id'];
              if (userId != null) {
                await _sendPushNotification(
                  recipientId: userId,
                  title: title,
                  message: message,
                  type: 'pickup_denied',
                  studentId: studentId,
                  extraData: {
                    'guard_name': guardName ?? '',
                    'fetcher_name': fetcherName ?? '',
                    'fetcher_type': fetcherType ?? '',
                    'deny_reason': denyReason,
                  },
                );
              }
            }
            
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

  /// Test method to manually test pickup/dropoff approval notification creation
  Future<bool> testApprovalNotificationSystem({
    required String driverId,
    required int studentId,
    required String studentName,
  }) async {
    try {
      print('DEBUG: Testing approval notification system');
      print('  - Driver ID: $driverId');
      print('  - Student ID: $studentId');
      print('  - Student Name: $studentName');
      
      // Test pickup approval notification
      print('\\nTesting pickup approval notification...');
      final pickupApprovalResult = await sendPickupApprovalNotification(
        driverId: driverId,
        studentId: studentId,
        studentName: studentName,
        parentName: 'Test Parent',
        approvalTime: DateTime.now(),
        isApproved: true,
        notes: 'Test approval from Flutter app',
      );
      
      print('Pickup approval notification result: $pickupApprovalResult');
      
      // Test pickup decline notification
      print('\\nTesting pickup decline notification...');
      final pickupDeclineResult = await sendPickupApprovalNotification(
        driverId: driverId,
        studentId: studentId,
        studentName: studentName,
        parentName: 'Test Parent',
        approvalTime: DateTime.now(),
        isApproved: false,
        notes: 'Test decline from Flutter app',
      );
      
      print('Pickup decline notification result: $pickupDeclineResult');
      
      // Test dropoff approval notification
      print('\\nTesting dropoff approval notification...');
      final dropoffApprovalResult = await sendDropoffApprovalNotification(
        driverId: driverId,
        studentId: studentId,
        studentName: studentName,
        parentName: 'Test Parent',
        approvalTime: DateTime.now(),
        isApproved: true,
        notes: 'Test approval from Flutter app',
      );
      
      print('Dropoff approval notification result: $dropoffApprovalResult');
      
      // Test dropoff decline notification
      print('\\nTesting dropoff decline notification...');
      final dropoffDeclineResult = await sendDropoffApprovalNotification(
        driverId: driverId,
        studentId: studentId,
        studentName: studentName,
        parentName: 'Test Parent',
        approvalTime: DateTime.now(),
        isApproved: false,
        notes: 'Test decline from Flutter app',
      );
      
      print('Dropoff decline notification result: $dropoffDeclineResult');
      
      // Check if notifications were created in database
      print('\\nChecking database for inserted notifications...');
      final notifications = await supabase
          .from('notifications')
          .select('id, type, title, message, created_at')
          .eq('recipient_id', driverId)
          .eq('student_id', studentId)
          .inFilter('type', ['pickup_approved', 'pickup_declined', 'dropoff_approved', 'dropoff_declined'])
          .order('created_at', ascending: false)
          .limit(10);
          
      print('DEBUG: Found ${notifications.length} approval/decline notifications for driver $driverId, student $studentId');
      for (final notification in notifications) {
        print('  - ${notification['type']}: ${notification['title']} (${notification['created_at']})');
      }
      
      final allTestsPassed = pickupApprovalResult && pickupDeclineResult && dropoffApprovalResult && dropoffDeclineResult;
      print('\\nAll notification tests passed: $allTestsPassed');
      
      return allTestsPassed;
    } catch (e) {
      print('DEBUG: Test approval notification system error: $e');
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

  /// Get notifications for a driver filtered by date and type
  Future<List<Map<String, dynamic>>> getDriverNotifications(
    String driverId, {
    bool todayOnly = false,
    int limit = 50,
  }) async {
    try {
      // Build query to get notifications for this driver
      var query = supabase
          .from('notifications')
          .select('''
            *,
            students(fname, lname)
          ''')
          .eq('recipient_id', driverId);

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
      print('Error getting driver notifications: $e');
      return [];
    }
  }

  /// Get unread notification count for a driver
  Future<int> getUnreadDriverNotificationCount(String driverId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', driverId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      print('Error getting unread driver notification count: $e');
      return 0;
    }
  }

  /// Mark driver notifications as read
  Future<bool> markDriverNotificationsAsRead(String driverId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('recipient_id', driverId)
          .eq('is_read', false);

      return true;
    } catch (e) {
      print('Error marking driver notifications as read: $e');
      return false;
    }
  }

  /// Send pickup approval notification to driver
  Future<bool> sendPickupApprovalNotification({
    required String driverId,
    required int studentId,
    required String studentName,
    required String parentName,
    required DateTime approvalTime,
    bool isApproved = true,
    String? notes,
  }) async {
    try {
      String title;
      String message;
      String notificationType;

      if (isApproved) {
        title = 'Pickup Approved';
        message = '$parentName has approved the pickup of $studentName at ${_formatTime(approvalTime)}.';
        notificationType = 'pickup_approved';
      } else {
        title = 'Pickup Declined';
        message = '$parentName has declined the pickup of $studentName.';
        notificationType = 'pickup_declined';
      }

      if (notes != null && notes.isNotEmpty) {
        message += ' Notes: $notes';
      }

      print('DEBUG: Preparing to insert pickup notification');
      print('  - Driver ID: $driverId');
      print('  - Student ID: $studentId');
      print('  - Type: $notificationType');
      print('  - Title: $title');
      print('  - Message: $message');

      final notificationData = {
        'recipient_id': driverId,
        'title': title,
        'message': message,
        'type': notificationType,
        'student_id': studentId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final insertResult = await supabase.from('notifications').insert(notificationData);
        
        print('DEBUG: Notification insert result: $insertResult');
        print('✅ Pickup approval notification inserted successfully via direct insert');
        print('DEBUG: Pickup ${isApproved ? 'approval' : 'denial'} notification sent to driver $driverId for student $studentName');
        
        // Send push notification
        await _sendPushNotification(
          recipientId: driverId,
          title: title,
          message: message,
          type: notificationType,
          studentId: studentId,
          extraData: {'parent_name': parentName},
        );
        
        return true;
      } catch (insertError) {
        print('⚠️  Direct insert failed (likely RLS issue): $insertError');
        print('DEBUG: Attempting RPC function fallback...');
        
        // Fallback to RPC function which bypasses RLS
        try {
          final rpcResult = await supabase.rpc('create_verification_notification', params: {
            'p_recipient_id': driverId,
            'p_title': title,
            'p_message': message,
            'p_type': notificationType,
            'p_student_id': studentId,
          });
          
          if (rpcResult == true) {
            print('✅ Pickup approval notification sent successfully via RPC function');
            print('DEBUG: RPC fallback successful for driver $driverId');
            
            // Send push notification
            await _sendPushNotification(
              recipientId: driverId,
              title: title,
              message: message,
              type: notificationType,
              studentId: studentId,
              extraData: {'parent_name': parentName},
            );
            
            return true;
          } else {
            print('❌ RPC function returned false');
            return false;
          }
        } catch (rpcError) {
          print('❌ RPC function fallback also failed: $rpcError');
          throw rpcError; // Re-throw the RPC error
        }
      }
    } catch (e) {
      print('❌ Error sending pickup approval notification to driver: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Send dropoff approval notification to driver
  Future<bool> sendDropoffApprovalNotification({
    required String driverId,
    required int studentId,
    required String studentName,
    required String parentName,
    required DateTime approvalTime,
    bool isApproved = true,
    String? notes,
  }) async {
    try {
      String title;
      String message;
      String notificationType;

      if (isApproved) {
        title = 'Dropoff Approved';
        message = '$parentName has approved the dropoff of $studentName at ${_formatTime(approvalTime)}.';
        notificationType = 'dropoff_approved';
      } else {
        title = 'Dropoff Declined';
        message = '$parentName has declined the dropoff of $studentName.';
        notificationType = 'dropoff_declined';
      }

      if (notes != null && notes.isNotEmpty) {
        message += ' Notes: $notes';
      }

      print('DEBUG: Preparing to insert dropoff notification');
      print('  - Driver ID: $driverId');
      print('  - Student ID: $studentId');
      print('  - Type: $notificationType');
      print('  - Title: $title');
      print('  - Message: $message');

      final notificationData = {
        'recipient_id': driverId,
        'title': title,
        'message': message,
        'type': notificationType,
        'student_id': studentId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final insertResult = await supabase.from('notifications').insert(notificationData);
        
        print('DEBUG: Notification insert result: $insertResult');
        print('✅ Dropoff approval notification inserted successfully via direct insert');
        print('DEBUG: Dropoff ${isApproved ? 'approval' : 'denial'} notification sent to driver $driverId for student $studentName');
        
        // Send push notification
        await _sendPushNotification(
          recipientId: driverId,
          title: title,
          message: message,
          type: notificationType,
          studentId: studentId,
          extraData: {'parent_name': parentName},
        );
        
        return true;
      } catch (insertError) {
        print('⚠️  Direct insert failed (likely RLS issue): $insertError');
        print('DEBUG: Attempting RPC function fallback...');
        
        // Fallback to RPC function which bypasses RLS
        try {
          final rpcResult = await supabase.rpc('create_verification_notification', params: {
            'p_recipient_id': driverId,
            'p_title': title,
            'p_message': message,
            'p_type': notificationType,
            'p_student_id': studentId,
          });
          
          if (rpcResult == true) {
            print('✅ Dropoff approval notification sent successfully via RPC function');
            print('DEBUG: RPC fallback successful for driver $driverId');
            return true;
          } else {
            print('❌ RPC function returned false');
            return false;
          }
        } catch (rpcError) {
          print('❌ RPC function fallback also failed: $rpcError');
          throw rpcError; // Re-throw the RPC error
        }
      }
    } catch (e) {
      print('❌ Error sending dropoff approval notification to driver: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Send verification request notification to driver
  Future<bool> sendVerificationRequestNotification({
    required String driverId,
    required int studentId,
    required String studentName,
    required String eventType, // 'pickup' or 'dropoff'
    required DateTime eventTime,
  }) async {
    try {
      String title = '${eventType[0].toUpperCase() + eventType.substring(1)} Verification Required';
      String message = 'Please wait for parent verification of $studentName ${eventType} at ${_formatTime(eventTime)}.';
      String notificationType = '${eventType}_verification';

      await supabase.from('notifications').insert({
        'recipient_id': driverId,
        'recipient_type': 'user',
        'title': title,
        'message': message,
        'type': notificationType,
        'student_id': studentId,
        'is_read': false,
        'extra_data': {},
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send push notification
      await _sendPushNotification(
        recipientId: driverId,
        title: title,
        message: message,
        type: notificationType,
        extraData: {'student_id': studentId.toString()},
      );

      print('DEBUG: Verification request notification sent to driver $driverId for student $studentName');
      return true;
    } catch (e) {
      print('Error sending verification request notification to driver: $e');
      return false;
    }
  }

  /// Send route assignment notification to driver
  Future<bool> sendRouteAssignmentNotification({
    required String driverId,
    required List<String> studentNames,
    required String routeType, // 'pickup' or 'dropoff'
    String? routeNotes,
  }) async {
    try {
      String title = 'New ${routeType[0].toUpperCase() + routeType.substring(1)} Route Assignment';
      String message = 'You have been assigned to ${studentNames.length} students for $routeType: ${studentNames.join(', ')}.';
      String notificationType = 'route_assignment';

      if (routeNotes != null && routeNotes.isNotEmpty) {
        message += ' Notes: $routeNotes';
      }

      await supabase.from('notifications').insert({
        'recipient_id': driverId,
        'recipient_type': 'user',
        'title': title,
        'message': message,
        'type': notificationType,
        'student_id': null, // Multiple students involved
        'is_read': false,
        'extra_data': {},
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send push notification
      await _sendPushNotification(
        recipientId: driverId,
        title: title,
        message: message,
        type: notificationType,
        extraData: {
          'student_names': studentNames.join(', '),
          'route_type': routeType,
          if (routeNotes != null) 'notes': routeNotes,
        },
      );

      print('DEBUG: Route assignment notification sent to driver $driverId');
      return true;
    } catch (e) {
      print('Error sending route assignment notification to driver: $e');
      return false;
    }
  }

  /// Send push notification after database notification is created
  Future<void> _sendPushNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    int? studentId,
    Map<String, dynamic>? extraData,
  }) async {
    try {

      
      // Get FCM token for the recipient
      final tokenResponse = await supabase
          .from('user_fcm_tokens')
          .select('fcm_token, platform')
          .eq('user_id', recipientId)
          .maybeSingle();



      if (tokenResponse == null || tokenResponse['fcm_token'] == null) {

        return;
      }

      final fcmToken = tokenResponse['fcm_token'];
      final platform = tokenResponse['platform'];

      // Prepare push notification payload
      final payload = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': message,
          'sound': 'default',
          if (platform == 'ios') 'badge': 1,
        },
        'data': {
          'type': type,
          'student_id': studentId?.toString() ?? '',
          'recipient_id': recipientId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          ...?extraData,
        },
        if (platform == 'android') 'android': {
          'notification': {
            'channel_id': _getChannelId(type),
            'color': '#19AE61', // KidSync primary green
            'priority': 'high',
            'visibility': 'public',
          },
        },
      };

      // Send via Firebase Cloud Functions or your backend FCM service
      // This would typically call your backend API that has FCM server key
      await _sendFCMMessage(payload);


    } catch (e) {

    }
  }

  /// Send FCM message via backend API
  Future<void> _sendFCMMessage(Map<String, dynamic> payload) async {
    try {

      
      await supabase.functions.invoke(
        'send-push-notification',
        body: payload,
      );
      

    } catch (e) {

      rethrow;
    }
  }

  /// Get notification channel ID for FCM
  String _getChannelId(String type) {
    switch (type) {
      case 'pickup':
      case 'pickup_approved':
      case 'pickup_denied':
      case 'pickup_verification':
        return 'pickup_channel';
      case 'dropoff':
      case 'dropoff_approved':
      case 'dropoff_denied':
      case 'dropoff_verification':
        return 'dropoff_channel';
      case 'attendance':
      case 'rfid_entry':
      case 'rfid_exit':
        return 'attendance_channel';
      case 'emergency':
      case 'emergency_exit':
        return 'emergency_channel';
      default:
        return 'general_channel';
    }
  }

  /// Initialize push notifications for current user
  Future<void> initializePushNotifications() async {
    await _pushService.initialize();
  }

  /// Send a custom notification for testing purposes
  Future<bool> sendCustomNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      // Insert notification into database
      await supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'recipient_type': 'user',
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
        'extra_data': extraData ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send push notification
      await _sendPushNotification(
        recipientId: recipientId,
        title: title,
        message: message,
        type: type,
        extraData: extraData,
      );

      print('✅ Custom notification sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending custom notification: $e');
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
    _pushService.dispose();
  }

  /// Unsubscribe from current student
  void unsubscribeFromStudent() {
    _pickupChannel?.unsubscribe();
    _dropoffChannel?.unsubscribe();
    _notificationChannel?.unsubscribe();
  }
}