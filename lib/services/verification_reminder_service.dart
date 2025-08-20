import 'dart:async';
import 'verification_service.dart';

class VerificationReminderService {
  static final VerificationReminderService _instance = VerificationReminderService._internal();
  factory VerificationReminderService() => _instance;
  VerificationReminderService._internal();

  final VerificationService _verificationService = VerificationService();
  Timer? _reminderTimer;
  bool _isRunning = false;

  /// Start the reminder service
  /// This will check for pending verifications every 15 minutes and send reminders
  void startReminderService() {
    if (_isRunning) return;
    
    _isRunning = true;
    print('Starting verification reminder service...');
    
    // Send reminders every 15 minutes
    _reminderTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _sendReminders();
    });
    
    // Send initial reminders immediately
    _sendReminders();
  }

  /// Stop the reminder service
  void stopReminderService() {
    if (!_isRunning) return;
    
    _isRunning = false;
    _reminderTimer?.cancel();
    _reminderTimer = null;
    print('Stopped verification reminder service');
  }

  /// Send reminders for pending verifications
  Future<void> _sendReminders() async {
    try {
      print('Checking for pending verifications to send reminders...');
      await _verificationService.sendReminders();
    } catch (e) {
      print('Error sending verification reminders: $e');
    }
  }

  /// Check if the service is running
  bool get isRunning => _isRunning;

  /// Dispose of the service
  void dispose() {
    stopReminderService();
  }
}