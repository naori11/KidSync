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
    try {
      // Get all parents for this student
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
          .eq('student_id', studentId);

      if (parentResponse.isEmpty) {
        print('No parents found for student $studentId');
        return false;
      }

      // Get student information
      final studentResponse = await supabase
          .from('students')
          .select('fname, lname')
          .eq('id', studentId)
          .single();

      final studentName = '${studentResponse['fname']} ${studentResponse['lname']}';

      // Get driver information
      final driverResponse = await supabase
          .from('users')
          .select('fname, lname')
          .eq('id', driverId)
          .single();

      final driverName = '${driverResponse['fname']} ${driverResponse['lname']}';

      // Create verification requests for each parent
      for (final parentData in parentResponse) {
        final parent = parentData['parents'];
        if (parent != null) {
          final parentId = parent['id'];
          final parentUserId = parent['user_id'];

          // Check if a verification request already exists for this parent, student, event type, and time
          final existingVerification = await supabase
              .from('pickup_dropoff_verifications')
              .select('id')
              .eq('student_id', studentId)
              .eq('parent_id', parentId)
              .eq('event_type', eventType)
              .eq('event_time', eventTime.toIso8601String())
              .maybeSingle();

          // Only create if it doesn't already exist
          if (existingVerification == null) {
            // Create verification request
            await supabase.from('pickup_dropoff_verifications').insert({
              'student_id': studentId,
              'driver_id': driverId,
              'parent_id': parentId,
              'event_type': eventType,
              'event_time': eventTime.toIso8601String(),
              'pickup_dropoff_log_id': pickupDropoffLogId,
              'status': 'pending',
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // Note: Notifications are handled by the driver service
          // Parents will see verification requests in their dashboard
        }
      }

      return true;
    } catch (e) {
      print('Error creating verification request: $e');
      return false;
    }
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
              id, fname, lname, profile_image_url
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
      // Update only the specific verification record
      await supabase
          .from('pickup_dropoff_verifications')
          .update({
            'status': 'confirmed',
            'parent_response_time': DateTime.now().toIso8601String(),
            'parent_notes': parentNotes,
          })
          .eq('id', verificationId);

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
      // Update only the specific verification record
      await supabase
          .from('pickup_dropoff_verifications')
          .update({
            'status': 'denied',
            'parent_response_time': DateTime.now().toIso8601String(),
            'parent_notes': parentNotes,
          })
          .eq('id', verificationId);

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
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (fname, lname),
            parents!pickup_dropoff_verifications_parent_id_fkey (user_id)
          ''')
          .eq('status', 'pending')
          .lt('created_at', cutoffTime.toIso8601String())
          .lt('reminder_count', 3); // Max 3 reminders

      for (final verification in pendingVerifications) {
        final student = verification['students'];
        final driver = verification['drivers'];
        final parent = verification['parents'];
        final eventType = verification['event_type'];
        final studentName = '${student['fname']} ${student['lname']}';
        final driverName = '${driver['fname']} ${driver['lname']}';
        final eventTime = DateTime.parse(verification['event_time']);

        // Note: Reminder notifications would be handled by a separate notification system
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
            drivers:users!pickup_dropoff_verifications_driver_id_fkey (fname, lname),
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

  /// Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}