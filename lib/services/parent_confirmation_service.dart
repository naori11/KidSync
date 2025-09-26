import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

/// Service to handle parent confirmations and ensure driver notifications are sent
class ParentConfirmationService {
  final supabase = Supabase.instance.client;
  final notificationService = NotificationService();
  
  static final ParentConfirmationService _instance = ParentConfirmationService._internal();
  factory ParentConfirmationService() => _instance;
  ParentConfirmationService._internal();

  /// Handle parent confirmation of pickup/dropoff
  /// This ensures driver notifications are always sent
  Future<bool> confirmPickupDropoff({
    required int logId,
    required int parentId,
    required String status, // 'confirmed' or 'denied'
    String? notes,
  }) async {
    try {
      print('Processing parent confirmation for log $logId, parent $parentId, status: $status');

      // Get the pickup/dropoff log details
      final logResponse = await supabase
          .from('pickup_dropoff_logs')
          .select('''
            *,
            students!pickup_dropoff_logs_student_id_fkey (id, fname, lname),
            drivers:users!pickup_dropoff_logs_driver_id_fkey (id, fname, lname)
          ''')
          .eq('id', logId)
          .maybeSingle();

      if (logResponse == null) {
        print('Pickup/dropoff log not found: $logId');
        return false;
      }

      // Get parent details
      final parentResponse = await supabase
          .from('parents')
          .select('fname, lname')
          .eq('id', parentId)
          .maybeSingle();

      if (parentResponse == null) {
        print('Parent not found: $parentId');
        return false;
      }

      final student = logResponse['students'];
      final driver = logResponse['drivers'];
      final parent = parentResponse;

      if (student != null && driver != null && parent != null) {
        final studentName = '${student['fname']} ${student['lname']}';
        final parentName = '${parent['fname']} ${parent['lname']}';
        final eventType = logResponse['event_type'] ?? 'pickup';
        final eventTime = logResponse['pickup_time'] != null 
            ? DateTime.parse(logResponse['pickup_time'])
            : (logResponse['dropoff_time'] != null 
                ? DateTime.parse(logResponse['dropoff_time'])
                : DateTime.now());
        final driverId = driver['id'];
        final studentId = student['id'];

        print('Sending driver notification:');
        print('  Driver: $driverId');
        print('  Student: $studentName ($studentId)');
        print('  Parent: $parentName');
        print('  Event: $eventType at $eventTime');
        print('  Status: $status');

        // Send notification to driver
        bool notificationSent = false;
        if (eventType == 'pickup') {
          notificationSent = await notificationService.sendPickupApprovalNotification(
            driverId: driverId,
            studentId: studentId,
            studentName: studentName,
            parentName: parentName,
            approvalTime: eventTime,
            isApproved: status == 'confirmed',
            notes: notes,
          );
        } else if (eventType == 'dropoff') {
          notificationSent = await notificationService.sendDropoffApprovalNotification(
            driverId: driverId,
            studentId: studentId,
            studentName: studentName,
            parentName: parentName,
            approvalTime: eventTime,
            isApproved: status == 'confirmed',
            notes: notes,
          );
        }

        if (notificationSent) {
          print('✅ Driver notification sent successfully');
        } else {
          print('❌ Failed to send driver notification');
        }

        // Also update or create the verification record
        await _updateVerificationRecord(
          logId: logId,
          studentId: studentId,
          parentId: parentId,
          status: status,
          notes: notes,
          eventType: eventType,
          eventTime: eventTime,
        );

        return notificationSent;
      } else {
        print('Missing required data - Student: $student, Driver: $driver, Parent: $parent');
        return false;
      }
    } catch (e) {
      print('Error in confirmPickupDropoff: $e');
      return false;
    }
  }

  /// Update or create verification record
  Future<void> _updateVerificationRecord({
    required int logId,
    required int studentId,
    required int parentId,
    required String status,
    required String eventType,
    required DateTime eventTime,
    String? notes,
  }) async {
    try {
      // Try to find existing verification record
      final existingVerification = await supabase
          .from('pickup_dropoff_verifications')
          .select('id')
          .eq('pickup_dropoff_log_id', logId)
          .eq('parent_id', parentId)
          .maybeSingle();

      if (existingVerification != null) {
        // Update existing record
        await supabase
            .from('pickup_dropoff_verifications')
            .update({
              'status': status,
              'parent_response_time': DateTime.now().toIso8601String(),
              'parent_notes': notes,
            })
            .eq('id', existingVerification['id']);
        print('Updated existing verification record ${existingVerification['id']}');
      } else {
        // Create new verification record
        await supabase
            .from('pickup_dropoff_verifications')
            .insert({
              'pickup_dropoff_log_id': logId,
              'student_id': studentId,
              'parent_id': parentId,
              'event_type': eventType,
              'event_time': eventTime.toIso8601String(),
              'status': status,
              'parent_response_time': DateTime.now().toIso8601String(),
              'parent_notes': notes,
            });
        print('Created new verification record');
      }
    } catch (e) {
      print('Error updating verification record: $e');
    }
  }

  /// Process all pending parent confirmations that might have been missed
  /// This can be run periodically to catch any confirmations that didn't trigger notifications
  Future<void> processPendingConfirmations() async {
    try {
      print('=== PROCESSING PENDING CONFIRMATIONS ===');

      // Find pickup_dropoff_logs that have been confirmed but may not have sent notifications
      // This is a fallback for cases where the parent confirmed through an older system
      
      // Look for recent confirmations (last 24 hours) that might not have notifications
      final oneDayAgo = DateTime.now().subtract(Duration(days: 1));
      
      // Get verified records from verification table that are confirmed
      final confirmedVerifications = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            *,
            students!pickup_dropoff_verifications_student_id_fkey (id, fname, lname),
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (id, fname, lname),
            parents!pickup_dropoff_verifications_parent_id_fkey (id, fname, lname)
          ''')
          .eq('status', 'confirmed')
          .gte('parent_response_time', oneDayAgo.toIso8601String());

      print('Found ${confirmedVerifications.length} confirmed verifications from last 24 hours');

      for (final verification in confirmedVerifications) {
        final driverId = verification['driver_id'];
        
        // Check if driver notification was already sent
        final existingNotifications = await supabase
            .from('notifications')
            .select('id')
            .eq('recipient_id', driverId)
            .eq('student_id', verification['student_id'])
            .gte('created_at', verification['parent_response_time'])
            .limit(1);

        if (existingNotifications.isEmpty) {
          print('Missing notification for verification ${verification['id']}, sending now...');
          
          final student = verification['students'];
          final driver = verification['drivers'];
          final parent = verification['parents'];
          
          if (student != null && driver != null && parent != null) {
            await confirmPickupDropoff(
              logId: verification['pickup_dropoff_log_id'],
              parentId: verification['parent_id'],
              status: verification['status'],
              notes: verification['parent_notes'],
            );
          }
        }
      }

      print('=== PROCESSING COMPLETED ===');
    } catch (e) {
      print('Error processing pending confirmations: $e');
    }
  }
}