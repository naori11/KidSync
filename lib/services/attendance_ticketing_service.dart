import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_audit_service.dart';

class AttendanceTicketingService {
  final supabase = Supabase.instance.client;
  final teacherAuditService = TeacherAuditService();
  
  static final AttendanceTicketingService _instance = AttendanceTicketingService._internal();
  factory AttendanceTicketingService() => _instance;
  AttendanceTicketingService._internal();

  /// Get notification ticket status for a specific student
  Future<Map<String, dynamic>> getTicketStatus({
    required int studentId,
    required int sectionId,
  }) async {
    try {
      // Use RPC function to bypass RLS and get ticket status
      final rpcResult = await supabase.rpc('get_attendance_ticket_status', params: {
        'p_student_id': studentId,
      });
      
      if (rpcResult != null) {
        // Convert the JSON result to a Map
        final Map<String, dynamic> status = Map<String, dynamic>.from(rpcResult);
        return status;
      } else {
        return _getFallbackTicketStatus(studentId);
      }
    } catch (e) {
      print('Error getting ticket status via RPC: $e');
      return _getFallbackTicketStatus(studentId);
    }
  }

  /// Fallback method for getting ticket status (direct query)
  Future<Map<String, dynamic>> _getFallbackTicketStatus(int studentId) async {
    try {
      // Query for attendance notifications for this student
      final tickets = await supabase
          .from('notifications')
          .select('id, type, created_at, is_read, title, message, student_id, recipient_id')
          .eq('student_id', studentId)
          .or('type.eq.attendance_ticket,type.eq.attendance_resolved')
          .order('created_at', ascending: false)
          .limit(1);

      if (tickets.isEmpty) {
        return {
          'hasTicket': false,
          'isResolved': false,
          'canSendNotification': true,
          'canMarkResolved': false,
          'ticketData': null,
        };
      }

      final latestTicket = tickets.first;
      final isResolved = latestTicket['type'] == 'attendance_resolved';

      return {
        'hasTicket': true,
        'isResolved': isResolved,
        'canSendNotification': isResolved, // Can send new notification only if current is resolved
        'canMarkResolved': !isResolved, // Can resolve only if not already resolved
        'ticketData': latestTicket,
      };
    } catch (e) {
      print('Error getting ticket status: $e');
      return {
        'hasTicket': false,
        'isResolved': false,
        'canSendNotification': true,
        'canMarkResolved': false,
        'ticketData': null,
      };
    }
  }

  /// Send a notification ticket to parents
  Future<bool> sendNotificationTicket({
    required int studentId,
    required String studentName,
    required String customReason,
    required String teacherName,
    required String sectionName,
    String? teacherId,
  }) async {
    try {
      // First check if there's already an unresolved ticket
      final ticketStatus = await getTicketStatus(
        studentId: studentId,
        sectionId: 0, // Not using sectionId for tickets
      );

      if (ticketStatus['hasTicket'] && !ticketStatus['isResolved']) {
        throw Exception('There is already an unresolved notification for this student');
      }

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
        throw Exception('No parents found for student $studentId');
      }

      // Prepare notification message
      String title = 'Attendance Concern - $studentName';
      String message = 'Hello! $teacherName from $sectionName would like to discuss $studentName\'s attendance with you.\n\n';
      message += 'Reason: $customReason\n\n';
      message += 'Please contact the school at your earliest convenience to discuss this matter. ';
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
            'type': 'attendance_ticket',
            'student_id': studentId,
            'is_read': false,
            // Remove created_at - let the database set it automatically
          });
        }
      }

      if (notifications.isNotEmpty) {
        try {
          // Use RPC function instead of direct insert to bypass RLS issues
          List<Map<String, dynamic>> insertResults = [];
          
          for (var notification in notifications) {
            final rpcResult = await supabase.rpc('create_teacher_notification', params: {
              'p_recipient_id': notification['recipient_id'],
              'p_title': notification['title'],
              'p_message': notification['message'],
              'p_type': notification['type'],
              'p_student_id': notification['student_id'],
            });
            
            if (rpcResult != null) {
              insertResults.add(rpcResult);
            }
          }
          
          if (insertResults.isEmpty) {
            throw Exception('No notifications were created');
          }
        } catch (insertError) {
          
          if (insertError.toString().contains('Only teachers can create')) {
            throw Exception('Permission denied: Only teachers can send attendance notifications.');
          }
          
          throw Exception('Failed to send notification: ${insertError.toString()}');
        }
        
        // Log the ticket creation with proper audit logging
        await teacherAuditService.logParentNotificationTrigger(
          studentId: studentId.toString(),
          studentName: studentName,
          notificationType: 'attendance_ticket',
          parentName: 'Parent(s) of $studentName',
          parentContact: 'Multiple parents notified',
          notificationContent: message,
          triggerReason: customReason,
          attendanceData: {
            'teacher_name': teacherName,
            'section_name': sectionName,
            'notification_count': notifications.length,
          },
        );
        
        // Keep existing ticket activity logging for compatibility
        await _logTicketActivity(
          studentId: studentId,
          action: 'ticket_created',
          details: {
            'reason': customReason,
            'teacher_name': teacherName,
            'section_name': sectionName,
            'sent_to_count': notifications.length,
          },
          performedBy: teacherId,
        );
        
        return true;
      }

      return false;
    } catch (e) {
      print('Error sending notification ticket: $e');
      rethrow;
    }
  }

  /// Mark a notification ticket as resolved
  Future<bool> markTicketResolved({
    required int studentId,
    required String resolvedBy,
    String? resolutionNotes,
  }) async {
    try {
      // Check if there's an unresolved ticket
      final ticketStatus = await getTicketStatus(
        studentId: studentId,
        sectionId: 0,
      );

      if (!ticketStatus['hasTicket'] || ticketStatus['isResolved']) {
        throw Exception('No unresolved ticket found for this student');
      }

      // Create a resolution record
      final resolutionTicket = {
        'recipient_id': resolvedBy,
        'title': 'Attendance Issue Resolved',
        'message': 'Attendance concern resolved for student ID $studentId. Notes: ${resolutionNotes ?? "Issue resolved by teacher"}',
        'type': 'attendance_resolved',
        'student_id': studentId,
        'is_read': true,
        // Remove created_at - let the database set it automatically
      };

      await supabase.from('notifications').insert(resolutionTicket);

      // Create a resolution marker to reset consecutive absences
      final now = DateTime.now();
      await supabase.from('scan_records').insert({
        'student_id': studentId,
        'guard_id': supabase.auth.currentUser?.id ?? resolvedBy,
        'rfid_uid': 'ticket_resolution_${studentId}_${now.millisecondsSinceEpoch}',
        'scan_time': now.toIso8601String(),
        'action': 'attendance_resolution',
        'notes': 'Attendance ticket resolved - resets consecutive absence tracking',
      });

      // Log the ticket resolution with proper audit logging (fetches student name automatically)
      await teacherAuditService.logIssueResolutionWithLookup(
        issueId: 'attendance_ticket_${studentId}_${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId.toString(),
        issueType: 'attendance_ticket',
        resolution: 'resolved_by_teacher',
        resolutionNotes: resolutionNotes ?? 'Issue resolved by teacher',
        followUpActions: {
          'resolved_by': resolvedBy,
          'resolved_at': DateTime.now().toIso8601String(),
        },
      );
      
      // Keep existing ticket activity logging for compatibility
      await _logTicketActivity(
        studentId: studentId,
        action: 'ticket_resolved',
        details: {
          'resolved_by': resolvedBy,
          'resolution_notes': resolutionNotes ?? 'Issue resolved by teacher',
          'resolved_at': DateTime.now().toIso8601String(),
        },
        performedBy: resolvedBy,
      );

      print('Attendance ticket resolved for student $studentId');
      return true;
    } catch (e) {
      print('Error marking ticket as resolved: $e');
      rethrow;
    }
  }

  /// Get students who need attention based on consecutive absences
  Future<List<Map<String, dynamic>>> getStudentsRequiringAttention({
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
      
      List<Map<String, dynamic>> studentsRequiringAttention = [];

      for (final section in sections) {
        final sectionData = section['sections'];
        final students = sectionData['students'] as List;

        for (final student in students) {
          // Get attendance stats for this student
          final consecutiveAbsences = await _getConsecutiveAbsences(
            studentId: student['id'],
            sectionId: sectionData['id'],
          );

          // Check ticket status
          final ticketStatus = await getTicketStatus(
            studentId: student['id'],
            sectionId: sectionData['id'],
          );

          // Show students with 3+ consecutive absences who either:
          // 1. Don't have a ticket yet, OR
          // 2. Have an unresolved ticket (to show current status)
          bool shouldShow = consecutiveAbsences >= 3;
          
          // Hide students whose tickets are resolved (issue is considered closed)
          if (ticketStatus['hasTicket'] && ticketStatus['isResolved']) {
            shouldShow = false;
          }

          if (shouldShow) {
            studentsRequiringAttention.add({
              'student': student,
              'section': {
                'id': sectionData['id'],
                'name': sectionData['name'],
                'grade_level': sectionData['grade_level'],
              },
              'consecutiveAbsences': consecutiveAbsences,
              'ticketStatus': ticketStatus,
            });
          }
        }
      }

      // Sort by consecutive absences (most concerning first)
      studentsRequiringAttention.sort((a, b) {
        return (b['consecutiveAbsences'] as int).compareTo(a['consecutiveAbsences'] as int);
      });

      return studentsRequiringAttention;
    } catch (e) {
      print('Error getting students requiring attention: $e');
      return [];
    }
  }

  /// Get consecutive absences for a student (public method)
  Future<int> getConsecutiveAbsences({
    required int studentId,
    required int sectionId,
  }) async {
    return await _getConsecutiveAbsences(
      studentId: studentId,
      sectionId: sectionId,
    );
  }

  /// Get consecutive absences for a student
  Future<int> _getConsecutiveAbsences({
    required int studentId,
    required int sectionId,
  }) async {
    try {
      final now = DateTime.now();
      
      // Load class schedule to determine class days
      final assignmentRows = await supabase
          .from('section_teachers')
          .select('days, start_time, end_time')
          .eq('section_id', sectionId)
          .order('assigned_at', ascending: true);

      // Parse class schedule
      List<String> classDays = [];
      String? classEndTime;
      
      if (assignmentRows.isNotEmpty) {
        final Set<String> unionDays = {};

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

        // Get the latest end time
        DateTime? latest;
        String? latestStr;
        for (final r in assignmentRows) {
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

      // Helper function to check if a date is a class day
      bool isClassDay(DateTime date) {
        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final abbrev = weekDays[date.weekday - 1];
        return classDays.contains(abbrev);
      }

      // Get attendance records for the last 30 days
      final startDate = now.subtract(const Duration(days: 30));
      final startDateStr = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endDateStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final records = await supabase
          .from('section_attendance')
          .select('date, status')
          .eq('student_id', studentId)
          .eq('section_id', sectionId)
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date', ascending: false);

      // Create a map of existing attendance records for quick lookup
      Map<String, String> attendanceMap = {};
      for (final record in records) {
        final date = record['date'] as String;
        final status = record['status'] as String;
        attendanceMap[date] = status;
      }

      // Count consecutive absences from most recent date
      int consecutiveAbsences = 0;
      DateTime checkDate = now;
      
      // Check if there's a resolution marker that breaks the consecutive chain
      final resolutionMarkers = await supabase
          .from('scan_records')
          .select('scan_time')
          .eq('student_id', studentId)
          .eq('action', 'attendance_resolution')
          .order('scan_time', ascending: false)
          .limit(1);

      DateTime? lastResolutionDate;
      if (resolutionMarkers.isNotEmpty) {
        lastResolutionDate = DateTime.parse(resolutionMarkers.first['scan_time']);
      }

      while (checkDate.isAfter(startDate)) {
        if (isClassDay(checkDate)) {
          final dateStr = "${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
          
          // If we have a resolution marker and this date is before it, stop counting
          if (lastResolutionDate != null && checkDate.isBefore(lastResolutionDate)) {
            break;
          }
          
          bool isAbsent = false;
          if (attendanceMap.containsKey(dateStr)) {
            final status = attendanceMap[dateStr]!;
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
            break; // Stop counting when we find a non-absent day
          }
        }
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      return consecutiveAbsences;
    } catch (e) {
      print('Error getting consecutive absences: $e');
      return 0;
    }
  }

  /// Get all open tickets for a teacher's students
  Future<List<Map<String, dynamic>>> getOpenTickets({
    required String teacherId,
  }) async {
    try {
      // Get all students for this teacher's sections
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

      List<Map<String, dynamic>> openTickets = [];

      for (final section in sections) {
        final sectionData = section['sections'];
        final students = sectionData['students'] as List;

        for (final student in students) {
          final ticketStatus = await getTicketStatus(
            studentId: student['id'],
            sectionId: sectionData['id'],
          );

          if (ticketStatus['hasTicket'] && !ticketStatus['isResolved']) {
            openTickets.add({
              'student': student,
              'section': sectionData,
              'ticketData': ticketStatus['ticketData'],
            });
          }
        }
      }

      // Sort by creation date (oldest first)
      openTickets.sort((a, b) {
        final aDate = DateTime.parse(a['ticketData']['created_at']);
        final bDate = DateTime.parse(b['ticketData']['created_at']);
        return aDate.compareTo(bDate);
      });

      return openTickets;
    } catch (e) {
      print('Error getting open tickets: $e');
      return [];
    }
  }

  /// Log ticket activity for tracking
  Future<void> _logTicketActivity({
    required int studentId,
    required String action,
    required Map<String, dynamic> details,
    String? performedBy,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'recipient_id': performedBy ?? supabase.auth.currentUser?.id,
        'title': 'Attendance Ticket Log',
        'message': 'Ticket $action for student ID $studentId. Details: ${details.toString()}',
        'type': 'system_log_ticket_$action',
        'student_id': studentId,
        'is_read': true, // Mark as read since it's a log entry
        // Remove created_at - let the database set it automatically
      });
    } catch (e) {
      print('Error logging ticket activity: $e');
    }
  }

  /// Get ticket history for a student
  Future<List<Map<String, dynamic>>> getTicketHistory({
    required int studentId,
  }) async {
    try {
      final history = await supabase
          .from('notifications')
          .select('*')
          .eq('student_id', studentId)
          .inFilter('type', [
            'attendance_ticket',
            'attendance_resolved',
            'system_log_ticket_created',
            'system_log_ticket_resolved'
          ])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(history);
    } catch (e) {
      print('Error getting ticket history: $e');
      return [];
    }
  }
}