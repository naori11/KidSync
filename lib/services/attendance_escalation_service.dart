import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attendance_monitoring_service.dart';

class AttendanceEscalationService {
  final supabase = Supabase.instance.client;
  final AttendanceMonitoringService _attendanceService = AttendanceMonitoringService();
  
  static final AttendanceEscalationService _instance = AttendanceEscalationService._internal();
  factory AttendanceEscalationService() => _instance;
  AttendanceEscalationService._internal();

  Timer? _escalationTimer;
  bool _isRunning = false;

  /// Start the escalation monitoring service
  void startEscalationMonitoring() {
    if (_isRunning) return;
    
    _isRunning = true;
    print('Starting attendance escalation monitoring...');
    
    // Run escalation checks every 4 hours during school hours
    _escalationTimer = Timer.periodic(const Duration(hours: 4), (timer) {
      _processEscalations();
    });
    
    // Also run an initial check
    _processEscalations();
  }

  /// Stop the escalation monitoring service
  void stopEscalationMonitoring() {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    _isRunning = false;
    print('Stopped attendance escalation monitoring');
  }

  /// Process escalations (main logic)
  Future<void> _processEscalations() async {
    try {
      print('Processing attendance escalations...');
      
      // Only run during school hours (8 AM to 5 PM, Monday to Friday)
      final now = DateTime.now();
      if (now.weekday > 5 || now.hour < 8 || now.hour > 17) {
        print('Outside school hours, skipping escalation check');
        return;
      }

      // Check for students needing immediate escalation (8+ absences)
      await _checkImmediateEscalations();
      
      // Check for overdue parent notifications (3+ school days)
      await _checkOverdueNotifications();
      
      // Send follow-up notifications
      await _sendFollowUpNotifications();
      
      print('Escalation processing completed');
    } catch (e) {
      print('Error in escalation processing: $e');
    }
  }

  /// Check for students who need immediate admin escalation
  Future<void> _checkImmediateEscalations() async {
    try {
      // Get all teachers
      final teachers = await supabase
          .from('users')
          .select('id, fname, lname')
          .eq('role', 'Teacher');

      for (final teacher in teachers) {
        final studentsWithIssues = await _attendanceService.getStudentsWithAttendanceIssues(
          teacherId: teacher['id'],
        );

        for (final studentData in studentsWithIssues) {
          final student = studentData['student'];
          final section = studentData['section'];
          final stats = studentData['stats'] as Map<String, dynamic>;

          if (stats['needsAdminEscalation'] as bool) {
            // Check if we haven't already escalated recently
            final recentEscalations = await supabase
                .from('notifications')
                .select('id, created_at')
                .eq('student_id', student['id'])
                .eq('type', 'attendance_escalation')
                .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
                .order('created_at', ascending: false)
                .limit(1);

            if (recentEscalations.isEmpty) {
              await _attendanceService.sendAdminEscalationNotification(
                studentId: student['id'],
                studentName: '${student['fname']} ${student['lname']}',
                absentCount: stats['absentDays'],
                consecutiveAbsences: stats['consecutiveAbsences'],
                teacherName: '${teacher['fname']} ${teacher['lname']}',
                sectionName: section['name'],
                escalationReason: 'Automatic escalation - High absence count (${stats['absentDays']} days)',
                teacherId: teacher['id'],
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error checking immediate escalations: $e');
    }
  }

  /// Check for overdue parent notifications and escalate
  Future<void> _checkOverdueNotifications() async {
    try {
      // Find parent notifications that are 3+ school days old and unacknowledged
      final cutoffDate = _getSchoolDaysAgo(3);
      
      final overdueNotifications = await supabase
          .from('notifications')
          .select('''
            id, student_id, created_at, title, message,
            students!inner(
              fname, lname, section_id,
              sections!inner(
                name, grade_level
              )
            )
          ''')
          .eq('type', 'attendance_alert')
          .eq('is_read', false)
          .lt('created_at', cutoffDate.toIso8601String());

      for (final notification in overdueNotifications) {
        final student = notification['students'];
        final studentId = notification['student_id'];
        final studentName = '${student['fname']} ${student['lname']}';
        final sectionName = student['sections']['name'];

        // Get current attendance stats
        final stats = await _attendanceService.getStudentAttendanceStats(
          studentId: studentId,
          sectionId: student['section_id'],
        );

        // Find the student's teacher
        final teacherAssignment = await supabase
            .from('section_teachers')
            .select('''
              teacher_id,
              users!inner(fname, lname)
            ''')
            .eq('section_id', student['section_id'])
            .limit(1)
            .maybeSingle();

        if (teacherAssignment != null) {
          final teacher = teacherAssignment['users'];
          final teacherName = '${teacher['fname']} ${teacher['lname']}';

          // Send escalation to admin
          await _attendanceService.sendAdminEscalationNotification(
            studentId: studentId,
            studentName: studentName,
            absentCount: stats['absentDays'],
            consecutiveAbsences: stats['consecutiveAbsences'],
            teacherName: teacherName,
            sectionName: sectionName,
            escalationReason: 'Parent notification overdue - No response for 3+ school days',
            teacherId: teacherAssignment['teacher_id'],
          );

          // Mark the original notification as escalated
          await supabase
              .from('notifications')
              .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
              .eq('id', notification['id']);
        }
      }
    } catch (e) {
      print('Error checking overdue notifications: $e');
    }
  }

  /// Send follow-up notifications to parents
  Future<void> _sendFollowUpNotifications() async {
    try {
      // Find notifications that are 2 school days old but not yet escalated
      final followUpDate = _getSchoolDaysAgo(2);
      
      final notificationsForFollowUp = await supabase
          .from('notifications')
          .select('''
            id, student_id, created_at,
            students!inner(
              fname, lname, section_id,
              sections!inner(
                name, grade_level
              )
            )
          ''')
          .eq('type', 'attendance_alert')
          .eq('is_read', false)
          .gte('created_at', followUpDate.toIso8601String())
          .lt('created_at', _getSchoolDaysAgo(1).toIso8601String());

      for (final notification in notificationsForFollowUp) {
        final student = notification['students'];
        final studentId = notification['student_id'];
        final studentName = '${student['fname']} ${student['lname']}';

        // Check if we haven't already sent a follow-up
        final existingFollowUp = await supabase
            .from('notifications')
            .select('id')
            .eq('student_id', studentId)
            .eq('type', 'attendance_followup')
            .gte('created_at', followUpDate.toIso8601String())
            .limit(1);

        if (existingFollowUp.isEmpty) {
          // Get current attendance stats
          final stats = await _attendanceService.getStudentAttendanceStats(
            studentId: studentId,
            sectionId: student['section_id'],
          );

          // Find the student's teacher
          final teacherAssignment = await supabase
              .from('section_teachers')
              .select('''
                teacher_id,
                users!inner(fname, lname)
              ''')
              .eq('section_id', student['section_id'])
              .limit(1)
              .maybeSingle();

          if (teacherAssignment != null) {
            final teacher = teacherAssignment['users'];
            final teacherName = '${teacher['fname']} ${teacher['lname']}';

            // Send follow-up notification
            await _sendFollowUpNotification(
              studentId: studentId,
              studentName: studentName,
              absentCount: stats['absentDays'],
              teacherName: teacherName,
              sectionName: student['sections']['name'],
            );
          }
        }
      }
    } catch (e) {
      print('Error sending follow-up notifications: $e');
    }
  }

  /// Send a follow-up notification to parents
  Future<bool> _sendFollowUpNotification({
    required int studentId,
    required String studentName,
    required int absentCount,
    required String teacherName,
    required String sectionName,
  }) async {
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
        return false;
      }

      // Prepare follow-up notification message
      String title = '⚠️ URGENT: Follow-up on $studentName\'s Attendance';
      String message = 'This is a follow-up regarding $studentName\'s attendance concerns. ';
      message += 'We have not received a response to our previous notification. ';
      message += 'Current absences: $absentCount. ';
      message += 'Please contact $teacherName ($sectionName) immediately to discuss this matter. ';
      message += 'Continued absences may result in administrative intervention.';

      // Send notification to each parent
      final List<Map<String, dynamic>> notifications = [];
      for (final parentData in parentStudentResponse) {
        final userId = parentData['parents']['user_id'];
        if (userId != null) {
          notifications.add({
            'recipient_id': userId,
            'title': title,
            'message': message,
            'type': 'attendance_followup',
            'student_id': studentId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (notifications.isNotEmpty) {
        await supabase.from('notifications').insert(notifications);
        print('Follow-up notification sent for student $studentId');
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending follow-up notification: $e');
      return false;
    }
  }

  /// Calculate a date that is N school days ago (excluding weekends)
  DateTime _getSchoolDaysAgo(int schoolDays) {
    DateTime date = DateTime.now();
    int daysToSubtract = 0;
    int schoolDaysSubtracted = 0;

    while (schoolDaysSubtracted < schoolDays) {
      daysToSubtract++;
      final checkDate = date.subtract(Duration(days: daysToSubtract));
      
      // Count only weekdays (Monday = 1, Friday = 5)
      if (checkDate.weekday <= 5) {
        schoolDaysSubtracted++;
      }
    }

    return date.subtract(Duration(days: daysToSubtract));
  }

  /// Manual trigger for testing purposes
  Future<void> triggerEscalationCheck() async {
    print('Manually triggering escalation check...');
    await _processEscalations();
  }

  /// Get escalation status for a student
  Future<Map<String, dynamic>> getEscalationStatus(int studentId) async {
    try {
      // Check recent notifications
      final recentNotifications = await supabase
          .from('notifications')
          .select('type, created_at, is_read')
          .eq('student_id', studentId)
          .inFilter('type', ['attendance_alert', 'attendance_followup', 'attendance_escalation'])
          .gte('created_at', DateTime.now().subtract(const Duration(days: 14)).toIso8601String())
          .order('created_at', ascending: false);

      bool hasUnreadAlert = false;
      bool hasFollowUp = false;
      bool hasEscalation = false;
      DateTime? lastNotificationDate;

      for (final notification in recentNotifications) {
        final type = notification['type'];
        final isRead = notification['is_read'] as bool;
        final createdAt = DateTime.parse(notification['created_at']);

        if (lastNotificationDate == null || createdAt.isAfter(lastNotificationDate)) {
          lastNotificationDate = createdAt;
        }

        switch (type) {
          case 'attendance_alert':
            if (!isRead) hasUnreadAlert = true;
            break;
          case 'attendance_followup':
            hasFollowUp = true;
            break;
          case 'attendance_escalation':
            hasEscalation = true;
            break;
        }
      }

      return {
        'hasUnreadAlert': hasUnreadAlert,
        'hasFollowUp': hasFollowUp,
        'hasEscalation': hasEscalation,
        'lastNotificationDate': lastNotificationDate?.toIso8601String(),
        'daysSinceLastNotification': lastNotificationDate != null 
            ? DateTime.now().difference(lastNotificationDate).inDays 
            : null,
      };
    } catch (e) {
      print('Error getting escalation status: $e');
      return {
        'hasUnreadAlert': false,
        'hasFollowUp': false,
        'hasEscalation': false,
        'lastNotificationDate': null,
        'daysSinceLastNotification': null,
      };
    }
  }

  bool get isRunning => _isRunning;
}