import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceMonitoringService {
  final supabase = Supabase.instance.client;
  
  static final AttendanceMonitoringService _instance = AttendanceMonitoringService._internal();
  factory AttendanceMonitoringService() => _instance;
  AttendanceMonitoringService._internal();

  // Absence thresholds
  static const int TEACHER_ALERT_THRESHOLD = 5; // Teacher notified after 5 absences
  static const int PARENT_NOTIFICATION_THRESHOLD = 5; // Parent notified after 5 absences
  static const int ESCALATION_DAYS = 3; // Escalate if no response after 3 school days
  static const int ADMIN_ESCALATION_THRESHOLD = 8; // Admin notified after 8 absences

  /// Get attendance statistics for a student in a specific date range
  Future<Map<String, dynamic>> getStudentAttendanceStats({
    required int studentId,
    required int sectionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final defaultStartDate = startDate ?? DateTime(now.year, now.month - 1, now.day); // Last month
      final defaultEndDate = endDate ?? now;

      final startDateStr = "${defaultStartDate.year.toString().padLeft(4, '0')}-${defaultStartDate.month.toString().padLeft(2, '0')}-${defaultStartDate.day.toString().padLeft(2, '0')}";
      final endDateStr = "${defaultEndDate.year.toString().padLeft(4, '0')}-${defaultEndDate.month.toString().padLeft(2, '0')}-${defaultEndDate.day.toString().padLeft(2, '0')}";

      // Check if parent notification has been sent for this student
      final notificationHistory = await getAttendanceNotificationHistory(studentId);
      bool hasParentNotificationSent = notificationHistory.any((notification) => 
        notification['type'] == 'attendance_alert' || 
        notification['type'] == 'system_log_attendance_alert'
      );
      
      // Get the most recent notification date
      DateTime? lastNotificationDate;
      if (hasParentNotificationSent) {
        final recentNotification = notificationHistory.firstWhere(
          (notification) => notification['type'] == 'attendance_alert' || 
                          notification['type'] == 'system_log_attendance_alert',
          orElse: () => <String, dynamic>{},
        );
        if (recentNotification.isNotEmpty) {
          lastNotificationDate = DateTime.tryParse(recentNotification['created_at'] ?? '');
        }
      }

      // Load class schedule information from section_teachers table
      final assignmentRows = await supabase
          .from('section_teachers')
          .select('days, start_time, end_time, assigned_at, subject')
          .eq('section_id', sectionId)
          .order('assigned_at', ascending: true);

      // Parse class schedule
      List<String> classDays = [];
      String? classEndTime;
      
      if (assignmentRows.isNotEmpty) {
        final Set<String> unionDays = {};
        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final todayAbbrev = weekDays[now.weekday - 1];

        // Collect union of days across all assignment rows
        for (final a in assignmentRows) {
          final daysList =
              a['days'] is List
                  ? (a['days'] as List).cast<String>()
                  : (a['days']?.toString() ?? '')
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
          unionDays.addAll(daysList);
        }
        classDays = unionDays.toList();

        // Prefer rows that include today; if none, consider all rows
        final todays = assignmentRows.where((a) {
          final daysList =
              a['days'] is List
                  ? (a['days'] as List).cast<String>()
                  : (a['days']?.toString() ?? '')
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
          return daysList.contains(todayAbbrev);
        }).toList();

        final rowsToConsider = todays.isNotEmpty ? todays : assignmentRows;

        // Determine latest end_time among considered rows
        DateTime? latest;
        String? latestStr;
        for (final r in rowsToConsider) {
          final endStr = r['end_time']?.toString();
          if (endStr != null && endStr.isNotEmpty) {
            final parts = endStr.split(':');
            if (parts.length >= 2) {
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour != null && minute != null) {
                final time = DateTime(2000, 1, 1, hour, minute);
                if (latest == null || time.isAfter(latest)) {
                  latest = time;
                  latestStr = endStr;
                }
              }
            }
          }
        }
        classEndTime = latestStr;
      }

      final records = await supabase
          .from('section_attendance')
          .select('date, status, notes, marked_at')
          .eq('student_id', studentId)
          .eq('section_id', sectionId)
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date', ascending: false);

      // Create a map of existing attendance records for quick lookup
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (final record in records) {
        final date = record['date'] as String;
        attendanceMap[date] = record;
      }

      int totalDays = 0;
      int presentDays = 0;
      int absentDays = 0;
      int lateDays = 0;
      int excusedDays = 0;
      List<Map<String, dynamic>> recentAbsences = [];

      // Helper function to check if a date is a class day
      bool isClassDay(DateTime date) {
        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final abbrev = weekDays[date.weekday - 1];
        return classDays.contains(abbrev);
      }

      // Process each day in the date range
      DateTime currentDate = defaultStartDate;
      while (currentDate.isBefore(defaultEndDate.add(const Duration(days: 1)))) {
        if (isClassDay(currentDate)) {
          final dateStr = "${currentDate.year.toString().padLeft(4, '0')}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
          
          if (attendanceMap.containsKey(dateStr)) {
            // Process existing attendance record
            final record = attendanceMap[dateStr]!;
            totalDays++;
            final status = record['status'] ?? 'Absent';
            
            switch (status) {
              case 'Present':
                presentDays++;
                break;
              case 'Late':
                lateDays++;
                break;
              case 'Absent':
                absentDays++;
                recentAbsences.add(record);
                break;
              case 'Excused':
              case 'Emergency Exit':
                excusedDays++;
                break;
            }
          } else {
            // No attendance record - check if this should count as absent
            final isToday = currentDate.year == now.year && 
                          currentDate.month == now.month && 
                          currentDate.day == now.day;
            final isPastDate = currentDate.isBefore(now);
            
            // Count as absent if it's a past date or today after class time
            bool shouldMarkAbsent = false;
            if (isPastDate) {
              shouldMarkAbsent = true;
            } else if (isToday && classEndTime != null) {
              // Check if current time is after class end time
              final parts = classEndTime.split(':');
              if (parts.length >= 2) {
                final hour = int.tryParse(parts[0]);
                final minute = int.tryParse(parts[1]);
                if (hour != null && minute != null) {
                  final classEnd = DateTime(now.year, now.month, now.day, hour, minute);
                  shouldMarkAbsent = now.isAfter(classEnd);
                }
              }
            }
            
            if (shouldMarkAbsent) {
              totalDays++;
              absentDays++;
              // Create a mock record for recent absences tracking
              recentAbsences.add({
                'date': dateStr,
                'status': 'Absent',
                'notes': 'Auto-marked absent (no attendance record)',
                'marked_at': dateStr,
              });
            }
          }
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Count consecutive absences (from most recent date)
      int consecutiveAbsences = 0;
      DateTime checkDate = now;
      while (checkDate.isAfter(defaultStartDate.subtract(const Duration(days: 1)))) {
        if (isClassDay(checkDate)) {
          final dateStr = "${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
          
          // Check if there's a resolution marker on this date
          final resolutionMarker = await supabase
              .from('scan_records')
              .select('id')
              .eq('student_id', studentId)
              .eq('action', 'attendance_resolution')
              .gte('scan_time', '${dateStr}T00:00:00')
              .lt('scan_time', '${dateStr}T23:59:59')
              .maybeSingle();
          
          if (resolutionMarker != null) {
            // Found a resolution marker - this breaks the consecutive absence chain
            break;
          }
          
          bool isAbsent = false;
          if (attendanceMap.containsKey(dateStr)) {
            final status = attendanceMap[dateStr]!['status'] ?? 'Absent';
            isAbsent = (status == 'Absent');
          } else {
            // Check if this missing record should count as absent
            final isToday = checkDate.year == now.year && 
                          checkDate.month == now.month && 
                          checkDate.day == now.day;
            final isPastDate = checkDate.isBefore(now);
            
            if (isPastDate) {
              isAbsent = true;
            } else if (isToday && classEndTime != null) {
              final parts = classEndTime.split(':');
              if (parts.length >= 2) {
                final hour = int.tryParse(parts[0]);
                final minute = int.tryParse(parts[1]);
                if (hour != null && minute != null) {
                  final classEnd = DateTime(now.year, now.month, now.day, hour, minute);
                  isAbsent = now.isAfter(classEnd);
                }
              }
            }
          }
          
          if (isAbsent) {
            consecutiveAbsences++;
          } else {
            // If there's a present/late/excused record, check if it was after a notification was sent
            if (hasParentNotificationSent && lastNotificationDate != null) {
              final recordDate = checkDate;
              if (recordDate.isAfter(lastNotificationDate)) {
                // Student attended after notification was sent, stop counting consecutive absences
                break;
              }
            } else {
              // No notification sent yet, or attendance record without notification context
              break; // Stop counting when we find a non-absent day
            }
          }
        }
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      // Determine if this is still an urgent issue considering notification status
      bool isUrgentIssue = false;
      if (!hasParentNotificationSent) {
        // No notification sent yet - use original logic
        isUrgentIssue = absentDays >= PARENT_NOTIFICATION_THRESHOLD || consecutiveAbsences >= 3;
      } else {
        // Notification was sent - check if there have been new absences since then
        if (lastNotificationDate != null) {
          int absencesAfterNotification = 0;
          int consecutiveAbsencesAfterNotification = 0;
          
          // Count absences that occurred after the notification was sent
          for (final absence in recentAbsences) {
            final absenceDate = DateTime.tryParse(absence['date'] ?? '');
            if (absenceDate != null && absenceDate.isAfter(lastNotificationDate)) {
              absencesAfterNotification++;
            }
          }
          
          // Check for consecutive absences after notification
          DateTime checkDateAfterNotification = now;
          while (checkDateAfterNotification.isAfter(lastNotificationDate)) {
            if (isClassDay(checkDateAfterNotification)) {
              final dateStr = "${checkDateAfterNotification.year.toString().padLeft(4, '0')}-${checkDateAfterNotification.month.toString().padLeft(2, '0')}-${checkDateAfterNotification.day.toString().padLeft(2, '0')}";
              
              bool isAbsentAfter = false;
              if (attendanceMap.containsKey(dateStr)) {
                final status = attendanceMap[dateStr]!['status'] ?? 'Absent';
                isAbsentAfter = (status == 'Absent');
              } else {
                // Check if this missing record should count as absent
                final isPastDate = checkDateAfterNotification.isBefore(now);
                if (isPastDate) {
                  isAbsentAfter = true;
                }
              }
              
              if (isAbsentAfter) {
                consecutiveAbsencesAfterNotification++;
              } else {
                break; // Attended, so no consecutive absences
              }
            }
            checkDateAfterNotification = checkDateAfterNotification.subtract(const Duration(days: 1));
          }
          
          // Still urgent if there are new significant absences after notification
          isUrgentIssue = absencesAfterNotification >= 3 || consecutiveAbsencesAfterNotification >= 2;
        }
      }

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'lateDays': lateDays,
        'excusedDays': excusedDays,
        'consecutiveAbsences': consecutiveAbsences,
        'attendanceRate': totalDays > 0 ? (presentDays / totalDays * 100).round() : 0,
        'recentAbsences': recentAbsences.take(10).toList(), // Last 10 absences
        'needsTeacherAlert': absentDays >= TEACHER_ALERT_THRESHOLD,
        'needsParentNotification': absentDays >= PARENT_NOTIFICATION_THRESHOLD,
        'needsAdminEscalation': absentDays >= ADMIN_ESCALATION_THRESHOLD,
        'hasParentNotificationSent': hasParentNotificationSent,
        'lastNotificationDate': lastNotificationDate?.toIso8601String(),
        'isUrgentIssue': isUrgentIssue,
      };
    } catch (e) {
      print('Error getting student attendance stats: $e');
      return {
        'totalDays': 0,
        'presentDays': 0,
        'absentDays': 0,
        'lateDays': 0,
        'excusedDays': 0,
        'consecutiveAbsences': 0,
        'attendanceRate': 0,
        'recentAbsences': [],
        'needsTeacherAlert': false,
        'needsParentNotification': false,
        'needsAdminEscalation': false,
        'hasParentNotificationSent': false,
        'lastNotificationDate': null,
        'isUrgentIssue': false,
      };
    }
  }

  /// Get all students with attendance issues for a teacher
  Future<List<Map<String, dynamic>>> getStudentsWithAttendanceIssues({
    required String teacherId,
    int? sectionId,
  }) async {
    try {
      // Get teacher's sections
      var sectionsQuery = supabase
          .from('section_teachers')
          .select('''
            section_id,
            sections!inner(
              id, name, grade_level,
              students!inner(
                id, fname, lname, profile_image_url
              )
            )
          ''')
          .eq('teacher_id', teacherId);

      if (sectionId != null) {
        sectionsQuery = sectionsQuery.eq('section_id', sectionId);
      }

      final sections = await sectionsQuery;
      
      List<Map<String, dynamic>> studentsWithIssues = [];

      for (final section in sections) {
        final sectionData = section['sections'];
        final students = sectionData['students'] as List;

        for (final student in students) {
          final stats = await getStudentAttendanceStats(
            studentId: student['id'],
            sectionId: sectionData['id'],
          );

          // Include students with urgent issues or those needing alerts
          if (stats['isUrgentIssue'] || stats['needsTeacherAlert'] || stats['needsParentNotification'] || stats['needsAdminEscalation']) {
            studentsWithIssues.add({
              'student': student,
              'section': {
                'id': sectionData['id'],
                'name': sectionData['name'],
                'grade_level': sectionData['grade_level'],
              },
              'stats': stats,
            });
          }
        }
      }

      // Sort by most concerning issues first
      studentsWithIssues.sort((a, b) {
        final aStats = a['stats'] as Map<String, dynamic>;
        final bStats = b['stats'] as Map<String, dynamic>;
        
        // Prioritize urgent issues first
        if (aStats['isUrgentIssue'] && !bStats['isUrgentIssue']) return -1;
        if (!aStats['isUrgentIssue'] && bStats['isUrgentIssue']) return 1;
        
        // Then prioritize admin escalation
        if (aStats['needsAdminEscalation'] && !bStats['needsAdminEscalation']) return -1;
        if (!aStats['needsAdminEscalation'] && bStats['needsAdminEscalation']) return 1;
        
        // Then parent notification
        if (aStats['needsParentNotification'] && !bStats['needsParentNotification']) return -1;
        if (!aStats['needsParentNotification'] && bStats['needsParentNotification']) return 1;
        
        // If same priority, sort by absence count
        return (bStats['absentDays'] as int).compareTo(aStats['absentDays'] as int);
      });

      return studentsWithIssues;
    } catch (e) {
      print('Error getting students with attendance issues: $e');
      return [];
    }
  }

  /// Send notification to parents about student absences
  Future<bool> sendParentAbsenceNotification({
    required int studentId,
    required String studentName,
    required int absentCount,
    required int consecutiveAbsences,
    required String teacherName,
    required String sectionName,
    String? teacherId,
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
        print('No parents found for student $studentId');
        return false;
      }

      // Prepare notification message
      String title = 'Attendance Concern - $studentName';
      String message = 'We need to discuss $studentName\'s attendance. ';
      
      if (consecutiveAbsences > 0) {
        message += '$studentName has been absent for $consecutiveAbsences consecutive school days. ';
      }
      
      message += 'Total absences: $absentCount. ';
      message += 'Please contact $teacherName ($sectionName) to discuss this matter. ';
      message += 'Regular attendance is important for academic success.';

      // Send notification to each parent
      final List<Map<String, dynamic>> notifications = [];
      for (final parentData in parentStudentResponse) {
        final userId = parentData['parents']['user_id'];
        if (userId != null) {
          notifications.add({
            'recipient_id': userId,
            'title': title,
            'message': message,
            'type': 'attendance_alert',
            'student_id': studentId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (notifications.isNotEmpty) {
        await supabase.from('notifications').insert(notifications);
        
        // Log the notification using existing notifications table
        await _logNotificationInDatabase(
          studentId: studentId,
          notificationType: 'attendance_alert',
          details: {
            'action': 'parent_notification_sent',
            'absent_count': absentCount,
            'consecutive_absences': consecutiveAbsences,
            'teacher_name': teacherName,
            'section_name': sectionName,
            'sent_to_count': notifications.length,
          },
          sentBy: teacherId,
        );
        
        print('Parent absence notification sent for student $studentId');
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending parent absence notification: $e');
      return false;
    }
  }

  /// Send escalation notification to administrators
  Future<bool> sendAdminEscalationNotification({
    required int studentId,
    required String studentName,
    required int absentCount,
    required int consecutiveAbsences,
    required String teacherName,
    required String sectionName,
    required String escalationReason,
    String? teacherId,
  }) async {
    try {
      // Get all admin users
      final adminUsers = await supabase
          .from('users')
          .select('id, fname, lname, email')
          .eq('role', 'Admin');

      if (adminUsers.isEmpty) {
        print('No admin users found for escalation');
        return false;
      }

      // Prepare notification message
      String title = '🚨 Attendance Escalation - $studentName';
      String message = 'ATTENTION: $studentName ($sectionName) requires immediate attention. ';
      message += 'Total absences: $absentCount. ';
      
      if (consecutiveAbsences > 0) {
        message += 'Consecutive absences: $consecutiveAbsences days. ';
      }
      
      message += 'Teacher: $teacherName. ';
      message += 'Escalation reason: $escalationReason ';
      message += 'Please coordinate with the teacher and contact the family immediately.';

      // Send notification to each admin
      final List<Map<String, dynamic>> notifications = [];
      for (final admin in adminUsers) {
        notifications.add({
          'recipient_id': admin['id'],
          'title': title,
          'message': message,
          'type': 'attendance_escalation',
          'student_id': studentId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (notifications.isNotEmpty) {
        await supabase.from('notifications').insert(notifications);
        
        // Log the escalation
        await _logNotificationInDatabase(
          studentId: studentId,
          notificationType: 'attendance_escalation',
          details: {
            'action': 'admin_escalation_sent',
            'absent_count': absentCount,
            'consecutive_absences': consecutiveAbsences,
            'teacher_name': teacherName,
            'section_name': sectionName,
            'escalation_reason': escalationReason,
            'sent_to_count': notifications.length,
          },
          sentBy: teacherId,
        );
        
        print('Admin escalation notification sent for student $studentId');
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending admin escalation notification: $e');
      return false;
    }
  }

  /// Check if we need to send follow-up notifications
  Future<List<Map<String, dynamic>>> checkForFollowUps() async {
    try {
      // Look for parent notifications that are older than ESCALATION_DAYS and haven't been acknowledged
      final cutoffDate = DateTime.now().subtract(Duration(days: ESCALATION_DAYS));
      
      final overdueNotifications = await supabase
          .from('notifications')
          .select('''
            student_id,
            type,
            created_at,
            is_read,
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

      List<Map<String, dynamic>> followUpsNeeded = [];
      
      for (final notification in overdueNotifications) {
        final student = notification['students'];
        final studentId = notification['student_id'];
        
        // Get current attendance stats
        final stats = await getStudentAttendanceStats(
          studentId: studentId,
          sectionId: student['section_id'],
        );

        followUpsNeeded.add({
          'student_id': studentId,
          'student_name': '${student['fname']} ${student['lname']}',
          'section_name': student['sections']['name'],
          'original_notification_date': notification['created_at'],
          'days_overdue': DateTime.now().difference(DateTime.parse(notification['created_at'])).inDays,
          'current_stats': stats,
        });
      }

      return followUpsNeeded;
    } catch (e) {
      print('Error checking for follow-ups: $e');
      return [];
    }
  }

  /// Mark a notification as acknowledged
  Future<bool> acknowledgeNotification({
    required int studentId,
    required String notificationType,
    String? acknowledgedBy,
  }) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('type', notificationType)
          .eq('is_read', false);

      // Log the acknowledgment
      await _logNotificationInDatabase(
        studentId: studentId,
        notificationType: 'acknowledgment',
        details: {
          'action': 'notification_acknowledged',
          'original_type': notificationType,
          'acknowledged_by': acknowledgedBy,
        },
      );

      return true;
    } catch (e) {
      print('Error acknowledging notification: $e');
      return false;
    }
  }

  /// Get attendance monitoring history for a student
  Future<List<Map<String, dynamic>>> getAttendanceNotificationHistory(int studentId) async {
    try {
      final history = await supabase
          .from('notifications')
          .select('*')
          .eq('student_id', studentId)
          .inFilter('type', ['attendance_alert', 'attendance_escalation', 'attendance_followup', 'system_log_attendance_alert', 'system_log_attendance_escalation'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(history);
    } catch (e) {
      print('Error getting attendance notification history: $e');
      return [];
    }
  }

  /// Get notification effectiveness metrics for a student
  Future<Map<String, dynamic>> getNotificationEffectiveness({
    required int studentId,
    required int sectionId,
  }) async {
    try {
      // Get last notification date
      final notification = await supabase
          .from('notifications')
          .select('created_at')
          .eq('student_id', studentId)
          .eq('type', 'attendance_alert')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (notification == null) return {'hasImproved': false, 'daysTracked': 0};

      final notificationDate = DateTime.parse(notification['created_at']);
      final daysSinceNotification = DateTime.now().difference(notificationDate).inDays;

      // Check attendance improvement after notification
      final attendanceAfter = await supabase
          .from('section_attendance')
          .select('status')
          .eq('student_id', studentId)
          .eq('section_id', sectionId)
          .gte('date', "${notificationDate.year.toString().padLeft(4, '0')}-${notificationDate.month.toString().padLeft(2, '0')}-${notificationDate.day.toString().padLeft(2, '0')}")
          .order('date', ascending: false);

      final presentDays = attendanceAfter.where((a) => a['status'] == 'Present' || a['status'] == 'Late').length;
      final totalDays = attendanceAfter.length;
      final improvementRate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

      return {
        'hasImproved': improvementRate >= 75, // 75% or better attendance
        'improvementRate': improvementRate,
        'daysTracked': daysSinceNotification,
        'totalDaysAfter': totalDays,
        'presentDaysAfter': presentDays,
        'notificationDate': notificationDate.toIso8601String(),
      };
    } catch (e) {
      print('Error getting notification effectiveness: $e');
      return {'hasImproved': false, 'daysTracked': 0};
    }
  }

  /// Check if parent has responded to notification
  Future<bool> hasParentResponded(int studentId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('read_at, is_read')
          .eq('student_id', studentId)
          .eq('type', 'attendance_alert')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null && (response['read_at'] != null || response['is_read'] == true);
    } catch (e) {
      print('Error checking parent response: $e');
      return false;
    }
  }

  /// Get student status badge information
  Future<Map<String, dynamic>> getStudentBadgeStatus({
    required int studentId,
    required int sectionId,
  }) async {
    try {
      final stats = await getStudentAttendanceStats(
        studentId: studentId,
        sectionId: sectionId,
      );

      final consecutiveAbsences = stats['consecutiveAbsences'] ?? 0;

      // Check if there are ANY unresolved notifications
      final hasUnresolvedNotifs = await hasUnresolvedNotifications(studentId);

      // Determine badge state based purely on consecutive absences (automatic indicators)
      String badgeType = 'none';
      String badgeText = '';
      String badgeColor = '';
      String badgeIcon = '';

      // Show badges based on actual attendance issues, regardless of notification status
      if (consecutiveAbsences >= 5) {
        badgeType = 'critical';
        badgeText = 'CRITICAL';
        badgeColor = '0xFF8B0000'; // Dark red
        badgeIcon = 'priority_high';
      } else if (consecutiveAbsences >= 4) {
        badgeType = 'urgent';
        badgeText = 'URGENT';
        badgeColor = '0xFFDC2626'; // Red
        badgeIcon = 'priority_high';
      } else if (consecutiveAbsences >= 3) {
        badgeType = 'escalate';
        badgeText = 'ESCALATE';
        badgeColor = '0xFFF59E0B'; // Orange
        badgeIcon = 'warning';
      } else if (consecutiveAbsences >= 2 || stats['absentDaysThisMonth'] >= 3) {
        badgeType = 'attention';
        badgeText = 'ATTENTION';
        badgeColor = '0xFFF59E0B'; // Orange
        badgeIcon = 'info';
      }

      // Override with monitoring state only if there are unresolved notifications
      if (hasUnresolvedNotifs && badgeType != 'none') {
        String originalBadgeType = badgeType;
        badgeType = 'monitoring';
        badgeText = 'MONITORING';
        badgeColor = '0xFF3B82F6'; // Blue
        badgeIcon = 'visibility';
        
        // Store the original badge type for reference
        return {
          'badgeType': badgeType,
          'badgeText': badgeText,
          'badgeColor': badgeColor,
          'badgeIcon': badgeIcon,
          'originalBadgeType': originalBadgeType,
          'stats': stats,
        };
      }

      return {
        'badgeType': badgeType,
        'badgeText': badgeText,
        'badgeColor': badgeColor,
        'badgeIcon': badgeIcon,
        'stats': stats,
      };
    } catch (e) {
      print('Error getting student badge status: $e');
      return {
        'badgeType': 'none',
        'badgeText': '',
        'badgeColor': '',
        'badgeIcon': '',
        'stats': {},
      };
    }
  }

  /// Check if student has unresolved attendance notifications
  Future<bool> hasUnresolvedNotifications(int studentId) async {
    try {
      // Get latest notification for this student
      final notifications = await supabase
          .from('notifications')
          .select('type, created_at')
          .eq('student_id', studentId)
          .inFilter('type', ['attendance_alert', 'attendance_escalation', 'attendance_resolved'])
          .order('created_at', ascending: false)
          .limit(1);

      if (notifications.isEmpty) return false;

      final lastNotification = notifications.first;
      
      // If last notification was a resolution, then it's resolved
      if (lastNotification['type'] == 'attendance_resolved') {
        return false;
      }

      // If last notification was an alert or escalation, it's unresolved
      return ['attendance_alert', 'attendance_escalation'].contains(lastNotification['type']);
    } catch (e) {
      print('Error checking unresolved notifications: $e');
      return false;
    }
  }

  /// Process follow-up notifications for unresponsive cases
  Future<void> processFollowUpNotifications() async {
    try {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      
      // Find notifications sent 3 days ago without parent response
      final unresponded = await supabase
          .from('notifications')
          .select('''
            id, student_id, created_at,
            students!inner(fname, lname, id, section_id),
            students.sections!inner(id, name)
          ''')
          .eq('type', 'attendance_alert')
          .lt('created_at', threeDaysAgo.toIso8601String())
          .eq('is_read', false);

      for (final notification in unresponded) {
        // Check if attendance has improved
        final improvement = await getNotificationEffectiveness(
          studentId: notification['students']['id'],
          sectionId: notification['students']['section_id'],
        );

        if (!improvement['hasImproved']) {
          // Send follow-up notification
          await _sendFollowUpNotification(notification);
        }
      }
    } catch (e) {
      print('Error processing follow-up notifications: $e');
    }
  }

  /// Send follow-up notification for unresponsive parents
  Future<bool> _sendFollowUpNotification(Map<String, dynamic> originalNotification) async {
    try {
      final studentId = originalNotification['student_id'];
      final studentData = originalNotification['students'];
      final studentName = '${studentData['fname']} ${studentData['lname']}';
      
      // Get current stats
      final stats = await getStudentAttendanceStats(
        studentId: studentId,
        sectionId: studentData['section_id'],
      );

      // Get parents for this student
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

      if (parentStudentResponse.isEmpty) return false;

      // Prepare follow-up message
      String title = 'URGENT: Follow-up on $studentName\'s Attendance';
      String message = 'This is a follow-up regarding $studentName\'s attendance concerns. ';
      message += 'We previously notified you about attendance issues, but have not received a response. ';
      message += 'Current status: ${stats['absentDays']} total absences. ';
      message += 'Please contact the school immediately to discuss this matter. ';
      message += 'If this issue is not addressed promptly, it will be escalated to administration.';

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
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending follow-up notification: $e');
      return false;
    }
  }

  /// Get attendance insights for dashboard analytics
  Future<Map<String, dynamic>> getAttendanceInsights({
    required String teacherId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final defaultStartDate = startDate ?? DateTime(now.year, now.month, 1); // This month
      final defaultEndDate = endDate ?? now;

      // Get teacher's sections and students
      final sections = await supabase
          .from('section_teachers')
          .select('''
            section_id,
            sections!inner(
              id, name,
              students(id, fname, lname)
            )
          ''')
          .eq('teacher_id', teacherId);

      int totalNotificationsSent = 0;
      int issuesResolved = 0;
      int escalatedCases = 0;
      List<Map<String, dynamic>> recentNotifications = [];

      for (final section in sections) {
        final sectionData = section['sections'];
        final students = sectionData['students'] as List;

        for (final student in students) {
          // Get notification history for this period - include both regular and system log types
          final notifications = await supabase
              .from('notifications')
              .select('*')
              .eq('student_id', student['id'])
              .inFilter('type', [
                'attendance_alert', 
                'attendance_escalation',
                'system_log_attendance_alert',
                'system_log_attendance_escalation'
              ])
              .gte('created_at', defaultStartDate.toIso8601String())
              .lte('created_at', defaultEndDate.toIso8601String())
              .order('created_at', ascending: false);

          totalNotificationsSent += notifications.length;

          // Count resolved issues
          final resolvedNotifications = await supabase
              .from('notifications')
              .select('*')
              .eq('student_id', student['id'])
              .inFilter('type', ['attendance_resolved'])
              .gte('created_at', defaultStartDate.toIso8601String())
              .lte('created_at', defaultEndDate.toIso8601String());

          issuesResolved += resolvedNotifications.length;

          for (final notification in notifications) {
            if (notification['type'] == 'attendance_escalation' || 
                notification['type'] == 'system_log_attendance_escalation') {
              escalatedCases++;
            }

            recentNotifications.add({
              'student_name': '${student['fname']} ${student['lname']}',
              'section_name': sectionData['name'],
              'type': notification['type'],
              'created_at': notification['created_at'],
              'is_read': notification['is_read'],
            });
          }
        }
      }

      // Calculate resolution rate
      final resolutionRate = totalNotificationsSent > 0 
          ? (issuesResolved / totalNotificationsSent * 100).round()
          : 0;

      return {
        'totalNotificationsSent': totalNotificationsSent,
        'issuesResolved': issuesResolved,
        'escalatedCases': escalatedCases,
        'resolutionRate': resolutionRate,
        'recentNotifications': recentNotifications.take(10).toList(),
      };
    } catch (e) {
      print('Error getting attendance insights: $e');
      return {
        'totalNotificationsSent': 0,
        'issuesResolved': 0,
        'escalatedCases': 0,
        'resolutionRate': 0,
        'recentNotifications': [],
      };
    }
  }

  /// Mark attendance issue as manually resolved by teacher
  Future<bool> markAttendanceIssueResolved({
    required int studentId,
    required int sectionId,
    required String resolvedBy,
    String? resolutionNotes,
  }) async {
    try {
      // Create a resolution record
      await supabase.from('notifications').insert({
        'recipient_id': resolvedBy,
        'title': 'Attendance Issue Resolved',
        'message': 'Attendance concern manually resolved for student ID $studentId. Notes: ${resolutionNotes ?? "Teacher spoke with parent at school"}',
        'type': 'attendance_resolved',
        'student_id': studentId,
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create a virtual "resolution marker" scan record to break consecutive absences
      // This acts as an attendance intervention that resets the consecutive count
      final now = DateTime.now();
      await supabase.from('scan_records').insert({
        'student_id': studentId,
        'guard_id': supabase.auth.currentUser?.id,
        'rfid_uid': 'teacher_resolution_${studentId}_${now.millisecondsSinceEpoch}',
        'scan_time': now.toIso8601String(),
        'action': 'attendance_resolution',
        'notes': 'Attendance issue manually resolved by teacher - resets consecutive absence count',
      });

      // Log the manual resolution
      await _logNotificationInDatabase(
        studentId: studentId,
        notificationType: 'attendance_manual_resolution',
        details: {
          'action': 'manually_marked_resolved',
          'resolved_by': resolvedBy,
          'resolution_notes': resolutionNotes ?? 'Teacher spoke with parent at school',
          'resolved_at': DateTime.now().toIso8601String(),
          'consecutive_absences_reset': true,
        },
        sentBy: resolvedBy,
      );

      print('Attendance issue manually resolved for student $studentId - consecutive absences reset');
      return true;
    } catch (e) {
      print('Error marking attendance issue as resolved: $e');
      return false;
    }
  }

  /// Send notification to parents with custom reason
  Future<bool> sendCustomParentNotification({
    required int studentId,
    required String studentName,
    required String customReason,
    required String teacherName,
    required String sectionName,
    String? teacherId,
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
        print('No parents found for student $studentId');
        return false;
      }

      // Prepare notification message
      String title = 'Attendance Concern - $studentName';
      String message = 'Hello! $teacherName from $sectionName would like to discuss $studentName\'s attendance with you. ';
      message += '\n\nReason: $customReason ';
      message += '\n\nPlease contact the school at your earliest convenience to discuss this matter. ';
      message += 'Your child\'s regular attendance is important for their academic success.';

      // Send notification to each parent
      final List<Map<String, dynamic>> notifications = [];
      for (final parentData in parentStudentResponse) {
        final userId = parentData['parents']['user_id'];
        if (userId != null) {
          notifications.add({
            'recipient_id': userId,
            'title': title,
            'message': message,
            'type': 'attendance_alert',
            'student_id': studentId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (notifications.isNotEmpty) {
        await supabase.from('notifications').insert(notifications);
        
        // Log the notification using existing notifications table
        await _logNotificationInDatabase(
          studentId: studentId,
          notificationType: 'attendance_alert',
          details: {
            'action': 'custom_parent_notification_sent',
            'custom_reason': customReason,
            'teacher_name': teacherName,
            'section_name': sectionName,
            'sent_to_count': notifications.length,
          },
          sentBy: teacherId,
        );
        
        print('Custom parent notification sent for student $studentId');
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending custom parent notification: $e');
      return false;
    }
  }

  /// Private method to log attendance notifications in the database
  Future<void> _logNotificationInDatabase({
    required int studentId,
    required String notificationType,
    required Map<String, dynamic> details,
    String? sentBy,
  }) async {
    try {
      // Log as a notification with special type for tracking
      await supabase.from('notifications').insert({
        'recipient_id': sentBy ?? supabase.auth.currentUser?.id,
        'title': 'Attendance System Log',
        'message': 'System log: $notificationType for student ID $studentId. Details: ${details.toString()}',
        'type': 'system_log_$notificationType',
        'student_id': studentId,
        'is_read': true, // Mark as read since it's a log entry
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging attendance notification: $e');
    }
  }

  /// Create the attendance monitoring logs table if it doesn't exist
  Future<void> ensureAttendanceMonitoringTable() async {
    try {
      // This would typically be handled by database migrations
      // For now, we'll store logs in the existing notifications table
      // and add a custom log using a simple insert approach
      print('Attendance monitoring service initialized');
    } catch (e) {
      print('Error ensuring attendance monitoring table: $e');
    }
  }

  /// Process automatic monitoring (called periodically)
  Future<void> processAutomaticMonitoring() async {
    try {
      // Get all teachers and check their students
      final teachers = await supabase
          .from('users')
          .select('id, fname, lname')
          .eq('role', 'Teacher');

      for (final teacher in teachers) {
        final studentsWithIssues = await getStudentsWithAttendanceIssues(
          teacherId: teacher['id'],
        );

        for (final studentData in studentsWithIssues) {
          final student = studentData['student'];
          final section = studentData['section'];
          final stats = studentData['stats'] as Map<String, dynamic>;

          // Check if we haven't already sent notifications
          final existingNotifications = await supabase
              .from('notifications')
              .select('id, type, created_at')
              .eq('student_id', student['id'])
              .eq('type', 'attendance_alert')
              .order('created_at', ascending: false)
              .limit(1);

          final shouldSendParentNotification = stats['needsParentNotification'] as bool;
          final shouldEscalateToAdmin = stats['needsAdminEscalation'] as bool;

          // Send parent notification if needed and not recently sent
          if (shouldSendParentNotification && 
              (existingNotifications.isEmpty || 
               DateTime.now().difference(DateTime.parse(existingNotifications.first['created_at'])).inDays >= 2)) {
            
            await sendParentAbsenceNotification(
              studentId: student['id'],
              studentName: '${student['fname']} ${student['lname']}',
              absentCount: stats['absentDays'],
              consecutiveAbsences: stats['consecutiveAbsences'],
              teacherName: '${teacher['fname']} ${teacher['lname']}',
              sectionName: section['name'],
              teacherId: teacher['id'],
            );
          }

          // Escalate to admin if needed
          if (shouldEscalateToAdmin) {
            await sendAdminEscalationNotification(
              studentId: student['id'],
              studentName: '${student['fname']} ${student['lname']}',
              absentCount: stats['absentDays'],
              consecutiveAbsences: stats['consecutiveAbsences'],
              teacherName: '${teacher['fname']} ${teacher['lname']}',
              sectionName: section['name'],
              escalationReason: 'High absence count (${stats['absentDays']} days) requires administrative intervention',
              teacherId: teacher['id'],
            );
          }
        }
      }
    } catch (e) {
      print('Error in automatic monitoring process: $e');
    }
  }
}
