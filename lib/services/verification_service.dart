import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class VerificationService {
  final supabase = Supabase.instance.client;
  final notificationService = NotificationService();
  static final VerificationService _instance = VerificationService._internal();
  factory VerificationService() => _instance;
  VerificationService._internal();

  /// Create a verification request when driver confirms pickup/dropoff
  Future<bool> createVerificationRequest({
    required int studentId,
    required String driverId,
    required String eventType, // 'pickup' or 'dropoff'
    required DateTime eventTime,
    int? pickupDropoffLogId,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Get all parents for this student with timeout
        final parentResponse = await supabase
            .from('parent_student')
            .select('''
              parent_id,
              parents!parent_student_parent_id_fkey (
                id,
                fname,
                lname,
                user_id
              )
            ''')
            .eq('student_id', studentId)
            .timeout(Duration(seconds: 10));

        if (parentResponse.isEmpty) {
          print('No parents found for student $studentId');
          return false;
        }

        // Verify student and driver exist with error handling
        await supabase
            .from('students')
            .select('fname, lname')
            .eq('id', studentId)
            .single()
            .timeout(Duration(seconds: 10));

        await supabase
            .from('users')
            .select('fname, lname')
            .eq('id', driverId)
            .single()
            .timeout(Duration(seconds: 10));

        // Create verification requests for each parent
        int successCount = 0;
        for (final parentData in parentResponse) {
          final parent = parentData['parents'];
          if (parent != null) {
            final parentId = parent['id'];

            try {
              // Check if a verification request already exists
              final existingVerification = await supabase
                  .from('pickup_dropoff_verifications')
                  .select('id')
                  .eq('student_id', studentId)
                  .eq('parent_id', parentId)
                  .eq('event_type', eventType)
                  .eq('event_time', eventTime.toIso8601String())
                  .maybeSingle()
                  .timeout(Duration(seconds: 10));

              // Only create if it doesn't already exist
              if (existingVerification == null) {
                await supabase.from('pickup_dropoff_verifications').insert({
                  'student_id': studentId,
                  'driver_id': driverId,
                  'parent_id': parentId,
                  'event_type': eventType,
                  'event_time': eventTime.toIso8601String(),
                  'pickup_dropoff_log_id': pickupDropoffLogId,
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                }).timeout(Duration(seconds: 10));
                
                successCount++;
              } else {
                successCount++; // Count existing as success
              }
            } catch (parentError) {
              print('Error creating verification for parent $parentId: $parentError');
              // Continue with other parents
            }
          }
        }

        return successCount > 0; // Success if at least one verification was created
        
      } catch (e) {
        retryCount++;
        print('Error creating verification request (attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          print('Failed to create verification request after $maxRetries attempts');
          return false;
        } else {
          // Exponential backoff
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    }
    
    return false;
  }

  /// Get pending verification requests for a parent
  Future<List<Map<String, dynamic>>> getPendingVerifications(int parentId) async {
    try {
      final response = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            students!pickup_dropoff_verifications_student_id_fkey (
              id, fname, lname, profile_image_url
            ),
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (
              id, fname, lname, profile_image_url, plate_number
            )
          ''')
          .eq('parent_id', parentId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting pending verifications: $e');
      return [];
    }
  }

  /// Confirm a verification request (parent confirms pickup/dropoff)
  /// This will only confirm the specific verification for the logged-in parent
  Future<bool> confirmVerification(int verificationId, {String? parentNotes}) async {
    try {
      // Get verification details before updating
      final verificationResponse = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            students!pickup_dropoff_verifications_student_id_fkey (
              id, fname, lname
            ),
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (
              id, fname, lname
            ),
            parents!pickup_dropoff_verifications_parent_id_fkey (
              id, fname, lname
            )
          ''')
          .eq('id', verificationId)
          .single();

      // Update only the specific verification record
      await supabase
          .from('pickup_dropoff_verifications')
          .update({
            'status': 'confirmed',
            'parent_response_time': DateTime.now().toIso8601String(),
            'parent_notes': parentNotes,
          })
          .eq('id', verificationId);

      // Notify the driver about the confirmation
      final student = verificationResponse['students'];
      final driver = verificationResponse['drivers'];
      final parent = verificationResponse['parents'];
      
      print('DEBUG: Attempting to send driver approval notification');
      print('  - Student: ${student != null}');
      print('  - Driver: ${driver != null}');
      print('  - Parent: ${parent != null}');
      
      if (student != null && driver != null && parent != null) {
        final studentName = '${student['fname']} ${student['lname']}';
        final parentName = '${parent['fname']} ${parent['lname']}';
        final eventType = verificationResponse['event_type'] ?? 'pickup';
        final eventTime = DateTime.parse(verificationResponse['event_time']);

        print('DEBUG: Sending $eventType approval notification');
        print('  - Driver ID: ${driver['id']}');
        print('  - Student ID: ${student['id']}');
        print('  - Student Name: $studentName');
        print('  - Parent Name: $parentName');
        print('  - Event Time: $eventTime');
        print('  - Notes: $parentNotes');

        bool notificationSent = false;
        try {
          if (eventType == 'pickup') {
            notificationSent = await notificationService.sendPickupApprovalNotification(
              driverId: driver['id'],
              studentId: student['id'],
              studentName: studentName,
              parentName: parentName,
              approvalTime: eventTime,
              isApproved: true,
              notes: parentNotes,
            );
          } else {
            notificationSent = await notificationService.sendDropoffApprovalNotification(
              driverId: driver['id'],
              studentId: student['id'],
              studentName: studentName,
              parentName: parentName,
              approvalTime: eventTime,
              isApproved: true,
              notes: parentNotes,
            );
          }
          
          if (notificationSent) {
            print('✅ Driver approval notification sent successfully');
          } else {
            print('❌ Driver approval notification failed to send (returned false)');
          }
        } catch (notificationError) {
          print('❌ Error sending driver approval notification: $notificationError');
        }
      } else {
        print('❌ Missing required data for driver approval notification');
        if (student == null) print('  - Missing student data');
        if (driver == null) print('  - Missing driver data');
        if (parent == null) print('  - Missing parent data');
      }

      return true;
    } catch (e) {
      print('Error confirming verification: $e');
      return false;
    }
  }

  /// Deny a verification request (parent denies pickup/dropoff)
  /// This will only deny the specific verification for the logged-in parent
  Future<bool> denyVerification(int verificationId, {String? parentNotes}) async {
    try {
      // Get verification details before updating
      final verificationResponse = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            students!pickup_dropoff_verifications_student_id_fkey (
              id, fname, lname
            ),
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (
              id, fname, lname
            ),
            parents!pickup_dropoff_verifications_parent_id_fkey (
              id, fname, lname
            )
          ''')
          .eq('id', verificationId)
          .single();

      // Update only the specific verification record
      await supabase
          .from('pickup_dropoff_verifications')
          .update({
            'status': 'denied',
            'parent_response_time': DateTime.now().toIso8601String(),
            'parent_notes': parentNotes,
          })
          .eq('id', verificationId);

      // Notify the driver about the denial
      final student = verificationResponse['students'];
      final driver = verificationResponse['drivers'];
      final parent = verificationResponse['parents'];
      
      print('DEBUG: Attempting to send driver denial notification');
      print('  - Student: ${student != null}');
      print('  - Driver: ${driver != null}');
      print('  - Parent: ${parent != null}');
      
      if (student != null && driver != null && parent != null) {
        final studentName = '${student['fname']} ${student['lname']}';
        final parentName = '${parent['fname']} ${parent['lname']}';
        final eventType = verificationResponse['event_type'] ?? 'pickup';
        final eventTime = DateTime.parse(verificationResponse['event_time']);

        print('DEBUG: Sending $eventType denial notification');
        print('  - Driver ID: ${driver['id']}');
        print('  - Student ID: ${student['id']}');
        print('  - Student Name: $studentName');
        print('  - Parent Name: $parentName');
        print('  - Event Time: $eventTime');
        print('  - Notes: $parentNotes');

        bool notificationSent = false;
        try {
          if (eventType == 'pickup') {
            notificationSent = await notificationService.sendPickupApprovalNotification(
              driverId: driver['id'],
              studentId: student['id'],
              studentName: studentName,
              parentName: parentName,
              approvalTime: eventTime,
              isApproved: false,
              notes: parentNotes,
            );
          } else {
            notificationSent = await notificationService.sendDropoffApprovalNotification(
              driverId: driver['id'],
              studentId: student['id'],
              studentName: studentName,
              parentName: parentName,
              approvalTime: eventTime,
              isApproved: false,
              notes: parentNotes,
            );
          }
          
          if (notificationSent) {
            print('✅ Driver denial notification sent successfully');
          } else {
            print('❌ Driver denial notification failed to send (returned false)');
          }
        } catch (notificationError) {
          print('❌ Error sending driver denial notification: $notificationError');
        }
      } else {
        print('❌ Missing required data for driver denial notification');
        if (student == null) print('  - Missing student data');
        if (driver == null) print('  - Missing driver data');
        if (parent == null) print('  - Missing parent data');
      }

      return true;
    } catch (e) {
      print('Error denying verification: $e');
      return false;
    }
  }

  /// Send reminder notifications for pending verifications
  Future<void> sendReminders() async {
    try {
      // Get pending verifications older than 15 minutes
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 15));
      
      final pendingVerifications = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            students!pickup_dropoff_verifications_student_id_fkey (fname, lname),
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (fname, lname, plate_number),
            parents!pickup_dropoff_verifications_parent_id_fkey (user_id)
          ''')
          .eq('status', 'pending')
          .lt('created_at', cutoffTime.toIso8601String())
          .lt('reminder_count', 3); // Max 3 reminders

      for (final verification in pendingVerifications) {
        // Note: student and driver data would be used for actual notification sending
        // For now, just update the reminder count

        // Update reminder count
        await supabase
            .from('pickup_dropoff_verifications')
            .update({
              'reminder_count': verification['reminder_count'] + 1,
              'last_reminder_sent': DateTime.now().toIso8601String(),
            })
            .eq('id', verification['id']);
      }
    } catch (e) {
      print('Error sending reminders: $e');
    }
  }

  /// Get verification history for a student
  Future<List<Map<String, dynamic>>> getVerificationHistory(int studentId, {int limit = 20}) async {
    try {
      final response = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (fname, lname, plate_number),
            parents!pickup_dropoff_verifications_parent_id_fkey (fname, lname)
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting verification history: $e');
      return [];
    }
  }
}