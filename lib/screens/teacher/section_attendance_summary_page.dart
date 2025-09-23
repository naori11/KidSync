import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:html' as html;

import 'student_attendance_calendar_page.dart';
import '../../services/attendance_monitoring_service.dart';
import '../../services/teacher_audit_service.dart';
import '../../widgets/attendance_status_badge.dart';
import '../../widgets/attendance_insights_card.dart';

class TeacherSectionAttendanceSummaryPage extends StatefulWidget {
  final int sectionId;
  final String sectionName;
  final VoidCallback? onBack;
  final void Function(int studentId, String studentName)? onViewStudentCalendar;

  const TeacherSectionAttendanceSummaryPage({
    Key? key,
    required this.sectionId,
    required this.sectionName,
    this.onBack,
    this.onViewStudentCalendar,
  }) : super(key: key);

  @override
  State<TeacherSectionAttendanceSummaryPage> createState() =>
      _TeacherSectionAttendanceSummaryPageState();
}

class _TeacherSectionAttendanceSummaryPageState
    extends State<TeacherSectionAttendanceSummaryPage> {
  final supabase = Supabase.instance.client;
  final AttendanceMonitoringService _attendanceService = AttendanceMonitoringService();
  final TeacherAuditService _teacherAuditService = TeacherAuditService();
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> students = [];
  Map<int, Map<String, int>> studentAttendanceStats = {};
  Map<int, Map<String, dynamic>> studentUrgentStatus = {};
  Map<int, Map<String, dynamic>> studentBadgeStatus = {};
  Map<int, bool> studentNotificationStatus = {}; // Track notification status for each student

  int totalPresent = 0;
  int totalLate = 0;
  int totalAbsent = 0;
  int totalExcused = 0;

  int totalPresentToday = 0;
  int totalLateToday = 0;
  int totalAbsentToday = 0;
  int totalExcusedToday = 0;

  // Class schedule information
  List<String> classDays = [];
  String? classStartTime;
  String? classEndTime;

  // Shared styles to ensure consistent font family/weight across monthly/daily
  final TextStyle _statLabelStyle = const TextStyle(
    fontSize: 13,
    color: Color(0xFF8F9BB3),
    fontWeight: FontWeight.w600,
  );
  // Single base for numeric stat text so both monthly and daily use the same font family/weight
  final TextStyle _statNumberStyleBase = const TextStyle(
    fontWeight: FontWeight.bold,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      totalPresent = 0;
      totalLate = 0;
      totalAbsent = 0;
      totalExcused = 0;
      totalPresentToday = 0;
      totalLateToday = 0;
      totalAbsentToday = 0;
      totalExcusedToday = 0;
    });

    try {
      final studentRows = await supabase
          .from('students')
          .select('id, fname, lname, profile_image_url')
          .eq('section_id', widget.sectionId)
          .order('lname', ascending: true);

      students = List<Map<String, dynamic>>.from(studentRows);
      print('Loaded ${students.length} students for notification status tracking');
      print('Loaded ${students.length} students: ${students.map((s) => '${s['fname']} ${s['lname']} (ID: ${s['id']})').toList()}');

      // Load class schedule information from section_teachers table
      final assignmentRows = await supabase
          .from('section_teachers')
          .select('days, start_time, end_time, assigned_at, subject')
          .eq('section_id', widget.sectionId)
          .order('assigned_at', ascending: true);

      final List<Map<String, dynamic>> assignments =
          List<Map<String, dynamic>>.from(assignmentRows);

      // Reset schedule info
      classDays = [];
      classStartTime = null;
      classEndTime = null;

      if (assignments.isNotEmpty) {
        final Set<String> unionDays = {};
        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final now = DateTime.now();
        final todayAbbrev = weekDays[now.weekday - 1];

        // Collect union of days across all assignment rows
        for (final a in assignments) {
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
        final todays =
            assignments.where((a) {
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

        final rowsToConsider = todays.isNotEmpty ? todays : assignments;

        // Determine earliest start_time and latest end_time among considered rows
        DateTime? earliest;
        DateTime? latest;
        String? earliestStr;
        String? latestStr;
        for (final r in rowsToConsider) {
          final startStr = r['start_time']?.toString();
          final endStr = r['end_time']?.toString();
          if (startStr != null && startStr.isNotEmpty) {
            final parts = startStr.split(':');
            if (parts.length >= 2) {
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour != null && minute != null) {
                final time = DateTime(2000, 1, 1, hour, minute);
                if (earliest == null || time.isBefore(earliest)) {
                  earliest = time;
                  earliestStr = startStr;
                }
              }
            }
          }
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
        classStartTime = earliestStr;
        classEndTime = latestStr;
      }

      final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endOfMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        0,
      );

      final attendanceRows = await supabase
          .from('section_attendance')
          .select('student_id, status, date')
          .eq('section_id', widget.sectionId)
          .gte('date', DateFormat('yyyy-MM-dd').format(startOfMonth))
          .lte('date', DateFormat('yyyy-MM-dd').format(endOfMonth));

      studentAttendanceStats.clear();
      for (final s in students) {
        studentAttendanceStats[s['id'] as int] = {
          'present': 0,
          'absent': 0,
          'late': 0,
          'excused': 0,
          'total': 0,
        };
      }

      // Create a map of existing attendance records for quick lookup
      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (final row in attendanceRows) {
        final studentId = row['student_id'].toString();
        final date = row['date'] as String;
        final key = '${studentId}_$date';
        attendanceMap[key] = row;
      }

      // Process attendance for each student and each class day in the month
      final now = DateTime.now();
      for (final student in students) {
        final studentId = student['id'] as int;
        final stats = studentAttendanceStats[studentId]!;
        
        for (int day = 1; day <= endOfMonth.day; day++) {
          final date = DateTime(selectedMonth.year, selectedMonth.month, day);
          
          // Check if this is a class day
          if (_isClassDay(date)) {
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final key = '${studentId}_$dateStr';
            
            // Check if there's an attendance record for this day
            if (attendanceMap.containsKey(key)) {
              // Process existing attendance record
              final record = attendanceMap[key]!;
              final status = (record['status'] ?? '').toString().toLowerCase();
              stats['total'] = (stats['total'] ?? 0) + 1;
              
              if (status == 'present')
                stats['present'] = (stats['present'] ?? 0) + 1;
              else if (status == 'absent')
                stats['absent'] = (stats['absent'] ?? 0) + 1;
              else if (status == 'late')
                stats['late'] = (stats['late'] ?? 0) + 1;
              else if (status == 'excused' || status == 'emergency exit')
                stats['excused'] = (stats['excused'] ?? 0) + 1;
            } else {
              // No attendance record - check if this should count as absent
              final isToday = date.year == now.year && 
                            date.month == now.month && 
                            date.day == now.day;
              final isPastDate = date.isBefore(now);
              
              // Count as absent if it's a past date or today after class time
              bool shouldMarkAbsent = false;
              if (isPastDate) {
                shouldMarkAbsent = true;
              } else if (isToday && classEndTime != null) {
                // Check if current time is after class end time
                final parts = classEndTime!.split(':');
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
                stats['total'] = (stats['total'] ?? 0) + 1;
                stats['absent'] = (stats['absent'] ?? 0) + 1;
              }
            }
          }
        }
      }

      totalPresent = studentAttendanceStats.values.fold(
        0,
        (sum, stat) => sum + (stat['present'] ?? 0),
      );
      totalAbsent = studentAttendanceStats.values.fold(
        0,
        (sum, stat) => sum + (stat['absent'] ?? 0),
      );
      totalLate = studentAttendanceStats.values.fold(
        0,
        (sum, stat) => sum + (stat['late'] ?? 0),
      );
      totalExcused = studentAttendanceStats.values.fold(
        0,
        (sum, stat) => sum + (stat['excused'] ?? 0),
      );

      // Calculate urgent status for each student
      studentUrgentStatus.clear();
      print('Processing ${students.length} students for notification status...');
      for (final student in students) {
        final studentId = student['id'] as int;
        print('Processing student ${student['fname']} ${student['lname']} (ID: $studentId)');
        try {
          // Try to get attendance stats, but don't let errors block notification checking
          Map<String, dynamic> attendanceStats = {};
          try {
            attendanceStats = await _attendanceService.getStudentAttendanceStats(
              studentId: studentId,
              sectionId: widget.sectionId,
              startDate: selectedMonth,
              endDate: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
            );
          } catch (statsError) {
            print('Error getting student attendance stats for $studentId: $statsError');
            // Set default values if stats can't be retrieved
            attendanceStats = {
              'isUrgentIssue': false,
              'hasParentNotificationSent': false,
              'lastNotificationDate': null,
            };
          }
          
          studentUrgentStatus[studentId] = {
            'isUrgentIssue': attendanceStats['isUrgentIssue'] ?? false,
            'hasParentNotificationSent': attendanceStats['hasParentNotificationSent'] ?? false,
            'lastNotificationDate': attendanceStats['lastNotificationDate'],
          };

          // Get badge status for this student
          final badgeStatus = await _attendanceService.getStudentBadgeStatus(
            studentId: studentId,
            sectionId: widget.sectionId,
          );
          studentBadgeStatus[studentId] = badgeStatus;
          
          // Check notification status for this student - ALWAYS run this
          final hasUnresolved = await _hasUnresolvedNotification(studentId);
          studentNotificationStatus[studentId] = hasUnresolved;
          if (hasUnresolved) {
            print('✓ Student ${student['fname']} ${student['lname']} has unresolved notification');
          }
        } catch (e) {
          print('Error getting urgent status for student $studentId: $e');
          studentUrgentStatus[studentId] = {
            'isUrgentIssue': false,
            'hasParentNotificationSent': false,
            'lastNotificationDate': null,
          };
        }
      }

      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final todayRows = await supabase
          .from('section_attendance')
          .select('status')
          .eq('section_id', widget.sectionId)
          .eq('date', todayStr);

      for (final r in todayRows) {
        final status = (r['status'] ?? '').toString().toLowerCase();
        if (status == 'present')
          totalPresentToday++;
        else if (status == 'absent')
          totalAbsentToday++;
        else if (status == 'late')
          totalLateToday++;
        else if (status == 'excused' || status == 'emergency exit')
          totalExcusedToday++;
      }
    } catch (e) {
      errorMessage = "Error loading data: $e";
    }

    setState(() => isLoading = false);
  }

  void _prevMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
    _loadData();
  }

  Future<void> _exportAttendance() async {
    try {
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No students found to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Generate filename and log export action
      final monthLabel = DateFormat('yyyy-MM').format(selectedMonth);
      final fileName = '${widget.sectionName}_Attendance_${monthLabel}.xlsx';
      
      await _teacherAuditService.logTeacherAttendanceExport(
        sectionId: widget.sectionId.toString(),
        sectionName: widget.sectionName,
        exportType: 'monthly_attendance_report',
        fileName: fileName,
        recordCount: students.length,
        dateRange: monthLabel,
      );

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Generating attendance report...'),
                ],
              ),
            ),
          );
        },
      );

      // Fetch comprehensive attendance data
      final attendanceData = await _fetchDetailedAttendanceData();

      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();

      // Create Summary sheet
      var summarySheet = excel['Summary'];
      await _createAttendanceSummarySheet(summarySheet, attendanceData);

      // Create Monthly Calendar sheet
      var calendarSheet = excel['Monthly Calendar'];
      await _createMonthlyCalendarSheet(calendarSheet, attendanceData);

      // Create Detailed Attendance sheet
      var detailedSheet = excel['Detailed Attendance'];
      await _createDetailedAttendanceSheet(detailedSheet, attendanceData);

      // Create Students Information sheet
      var studentsSheet = excel['Students Information'];
      await _createStudentsInfoSheet(studentsSheet, attendanceData);

      // Clean up: Remove any default sheets
      final defaultSheetNames = ['Sheet1', 'Sheet', 'Worksheet'];
      for (String defaultName in defaultSheetNames) {
        if (excel.tables.containsKey(defaultName)) {
          excel.delete(defaultName);
        }
      }

      // Set Summary as the default sheet
      excel.setDefaultSheet('Summary');

      // Generate and download file
      List<int>? fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Download file
      final blob = html.Blob([
        fileBytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance report exported successfully: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildSummaryStats() {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);
    final todayLabel = DateFormat.yMMMd().format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        // Use available space: Monthly on left (primary), Daily on right (compact)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Monthly panel (uses most space)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range,
                        size: 16,
                        color: Color(0xFF2E3A59),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Monthly — $monthLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2E3A59),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statColumn(
                        "Present",
                        totalPresent,
                        const Color(0xFF19AE61),
                      ),
                      const SizedBox(width: 24),
                      _statColumn("Late", totalLate, const Color(0xFFFFA726)),
                      const SizedBox(width: 24),
                      _statColumn(
                        "Absent",
                        totalAbsent,
                        const Color(0xFFEB5757),
                      ),
                      const SizedBox(width: 24),
                      _statColumn(
                        "Excused",
                        totalExcused,
                        const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // small gap between panels
            const SizedBox(width: 24),

            // Daily panel (aligned to the right side)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.today,
                        size: 16,
                        color: Color(0xFF2E3A59),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Daily — $todayLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2E3A59),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _statColumnSmall(
                        "Present",
                        totalPresentToday,
                        const Color(0xFF19AE61),
                      ),
                      const SizedBox(width: 12),
                      _statColumnSmall(
                        "Late",
                        totalLateToday,
                        const Color(0xFFFFA726),
                      ),
                      const SizedBox(width: 12),
                      _statColumnSmall(
                        "Absent",
                        totalAbsentToday,
                        const Color(0xFFEB5757),
                      ),
                      const SizedBox(width: 12),
                      _statColumnSmall(
                        "Excused",
                        totalExcusedToday,
                        const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // show monthly total (large)
  Widget _statColumn(String label, int monthlyValue, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$monthlyValue",
          style: _statNumberStyleBase.copyWith(fontSize: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(label, style: _statLabelStyle),
      ],
    );
  }

  // smaller version of _statColumn used for the daily panel to match visual style
  Widget _statColumnSmall(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$value",
          style: _statNumberStyleBase.copyWith(fontSize: 18, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: _statLabelStyle.copyWith(fontSize: 12)),
      ],
    );
  }

  Widget _buildAttendanceQuickStats() {
    // Calculate attendance issue stats using precomputed data
    int studentsWithIssues = 0;
    int urgentCases = 0;
    int notificationsSent = 0;
    
    for (final student in students) {
      final studentId = student['id'] as int;
      final badgeStatus = studentBadgeStatus[studentId];
      final urgentStatus = studentUrgentStatus[studentId];
      final hasNotification = studentNotificationStatus[studentId] ?? false;
      
      if (badgeStatus != null) {
        final stats = badgeStatus['stats'] as Map<String, dynamic>? ?? {};
        final consecutiveAbsences = stats['consecutiveAbsences'] as int? ?? 0;
        
        // Count students with issues (3+ consecutive absences)
        if (consecutiveAbsences >= 3) {
          studentsWithIssues++;
          
          // Count urgent cases (5+ consecutive absences OR still urgent after notification)
          if (urgentStatus != null) {
            final isUrgentIssue = urgentStatus['isUrgentIssue'] as bool? ?? false;
            if (consecutiveAbsences >= 5 || isUrgentIssue) {
              urgentCases++;
            }
          } else if (consecutiveAbsences >= 5) {
            urgentCases++;
          }
        }
      }
      
      // Count students with unresolved notifications
      if (hasNotification) {
        notificationsSent++;
      }
    }
    
    print('Statistics - Notifications sent/pending: $notificationsSent out of ${students.length} students');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: AttendanceQuickStats(
        totalStudents: students.length,
        studentsWithIssues: studentsWithIssues,
        urgentCases: urgentCases,
        notificationsSent: notificationsSent,
      ),
    );
  }  void _showStudentAttendanceCalendar(int studentId, String studentName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TeacherStudentAttendanceCalendarPage(
              studentId: studentId,
              studentName: studentName,
              sectionId: widget.sectionId,
              sectionName: widget.sectionName,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
    );
  }

  // Fetch detailed attendance data for export
  Future<Map<String, dynamic>> _fetchDetailedAttendanceData() async {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    // Fetch detailed attendance records with student and user info
    final attendanceRows = await supabase
        .from('section_attendance')
        .select('''
          id, section_id, student_id, date, status, marked_at, notes,
          students!inner(id, fname, mname, lname, address, birthday, grade_level, gender, profile_image_url),
          users!section_attendance_marked_by_fkey(fname, mname, lname, role)
        ''')
        .eq('section_id', widget.sectionId)
        .gte('date', DateFormat('yyyy-MM-dd').format(startOfMonth))
        .lte('date', DateFormat('yyyy-MM-dd').format(endOfMonth))
        .order('date', ascending: true)
        .order('students(lname)', ascending: true);

    // Fetch section information
    final sectionInfo =
        await supabase
            .from('sections')
            .select('id, name, grade_level, schedule, created_at')
            .eq('id', widget.sectionId)
            .single();

    return {
      'attendanceRecords': attendanceRows,
      'sectionInfo': sectionInfo,
      'students': students,
      'monthlyStats': {
        'totalPresent': totalPresent,
        'totalLate': totalLate,
        'totalAbsent': totalAbsent,
        'totalExcused': totalExcused,
      },
      'studentAttendanceStats': studentAttendanceStats,
      'selectedMonth': selectedMonth,
    };
  }

  // Create the Summary sheet with overall statistics
  Future<void> _createAttendanceSummarySheet(
    excel_lib.Sheet sheet,
    Map<String, dynamic> attendanceData,
  ) async {
    int rowIndex = 0;
    final sectionInfo = attendanceData['sectionInfo'] as Map<String, dynamic>;
    final monthlyStats = attendanceData['monthlyStats'] as Map<String, dynamic>;
    final selectedMonth = attendanceData['selectedMonth'] as DateTime;

    // Get current user info
    final user = supabase.auth.currentUser;
    final userName =
        user?.userMetadata?['fname'] != null &&
                user?.userMetadata?['lname'] != null
            ? '${user?.userMetadata?['fname']} ${user?.userMetadata?['lname']}'
            : user?.email ?? 'Unknown User';

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'ATTENDANCE REPORT - ${sectionInfo['name']}',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Report info
    var reportInfos = [
      ['Section:', sectionInfo['name']],
      ['Grade Level:', sectionInfo['grade_level']],
      ['Report Period:', DateFormat.yMMMM().format(selectedMonth)],
      ['Generated On:', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())],
      ['Generated By:', userName],
    ];

    for (var info in reportInfos) {
      var labelCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      labelCell.value = excel_lib.TextCellValue(info[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      );
      valueCell.value = excel_lib.TextCellValue(info[1]);
      rowIndex++;
    }
    rowIndex++;

    // Monthly Statistics
    var monthlyStatsHeader = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    monthlyStatsHeader.value = excel_lib.TextCellValue(
      'MONTHLY ATTENDANCE SUMMARY',
    );
    monthlyStatsHeader.cellStyle = excel_lib.CellStyle(
      bold: true,
      fontSize: 16,
    );
    rowIndex += 2;

    var monthlyStatsData = [
      ['Present', monthlyStats['totalPresent']],
      ['Late', monthlyStats['totalLate']],
      ['Absent', monthlyStats['totalAbsent']],
      ['Excused', monthlyStats['totalExcused']],
      [
        'Total Records',
        monthlyStats['totalPresent'] +
            monthlyStats['totalLate'] +
            monthlyStats['totalAbsent'] +
            monthlyStats['totalExcused'],
      ],
    ];

    for (var stat in monthlyStatsData) {
      var labelCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      labelCell.value = excel_lib.TextCellValue(stat[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      );
      valueCell.value = excel_lib.IntCellValue(stat[1]);
      rowIndex++;
    }

    // Auto-resize columns based on content length
    for (int col = 0; col < 2; col++) {
      double maxWidth = 15.0; // Minimum width
      // Calculate based on content - this will be handled by Excel when opened
      sheet.setColumnWidth(col, maxWidth);
    }
  }

  // Create the Detailed Attendance sheet with all daily records
  Future<void> _createDetailedAttendanceSheet(
    excel_lib.Sheet sheet,
    Map<String, dynamic> attendanceData,
  ) async {
    int rowIndex = 0;
    final attendanceRecords =
        attendanceData['attendanceRecords'] as List<dynamic>;
    final sectionInfo = attendanceData['sectionInfo'] as Map<String, dynamic>;

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'DETAILED ATTENDANCE RECORDS - ${sectionInfo['name']}',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Headers
    final headers = [
      'Date',
      'Student ID',
      'Student Name',
      'Status',
      'Marked By',
      'Marked At',
      'Notes',
      'Grade Level',
      'Gender',
    ];

    for (int i = 0; i < headers.length; i++) {
      var headerCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: rowIndex,
        ),
      );
      headerCell.value = excel_lib.TextCellValue(headers[i]);
      headerCell.cellStyle = excel_lib.CellStyle(bold: true);
    }
    rowIndex++;

    // Data rows
    for (final record in attendanceRecords) {
      final student = record['students'] as Map<String, dynamic>;
      final markedBy = record['users'] as Map<String, dynamic>?;
      final fullName =
          '${student['fname']} ${student['mname'] ?? ''} ${student['lname']}'
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      final markedByName =
          markedBy != null
              ? '${markedBy['fname'] ?? ''} ${markedBy['mname'] ?? ''} ${markedBy['lname'] ?? ''}'
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
              : 'Unknown';

      final rowData = [
        record['date'] ?? '',
        student['id']?.toString() ?? '',
        fullName,
        (record['status'] ?? '').toString().toUpperCase(),
        markedByName,
        record['marked_at'] != null
            ? DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(DateTime.parse(record['marked_at']))
            : '',
        record['notes'] ?? '',
        student['grade_level'] ?? '',
        student['gender'] ?? '',
      ];

      for (int i = 0; i < rowData.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: rowIndex,
          ),
        );
        cell.value = excel_lib.TextCellValue(rowData[i]);
      }
      rowIndex++;
    }

    // Auto-resize columns based on content
    const double minWidth = 8.0;
    const double maxWidth = 40.0;

    // Auto-size based on approximate content width
    for (int col = 0; col < 9; col++) {
      double columnWidth = minWidth;
      switch (col) {
        case 0:
          columnWidth = 12.0;
          break; // Date
        case 1:
          columnWidth = 12.0;
          break; // Student ID
        case 2:
          columnWidth = 25.0;
          break; // Student Name
        case 3:
          columnWidth = 12.0;
          break; // Status
        case 4:
          columnWidth = 20.0;
          break; // Marked By
        case 5:
          columnWidth = 18.0;
          break; // Marked At
        case 6:
          columnWidth = 30.0;
          break; // Notes
        case 7:
          columnWidth = 15.0;
          break; // Grade Level
        case 8:
          columnWidth = 10.0;
          break; // Gender
      }
      sheet.setColumnWidth(
        col,
        columnWidth > maxWidth ? maxWidth : columnWidth,
      );
    }
  }

  // Create the Students Information sheet
  Future<void> _createStudentsInfoSheet(
    excel_lib.Sheet sheet,
    Map<String, dynamic> attendanceData,
  ) async {
    int rowIndex = 0;
    final studentsList =
        attendanceData['students'] as List<Map<String, dynamic>>;
    final studentAttendanceStats =
        attendanceData['studentAttendanceStats'] as Map<int, Map<String, int>>;
    final sectionInfo = attendanceData['sectionInfo'] as Map<String, dynamic>;

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'STUDENTS INFORMATION - ${sectionInfo['name']}',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Headers
    final headers = [
      'Student ID',
      'Full Name',
      'Grade Level',
      'Gender',
      'Birthday',
      'Address',
      'Present Days',
      'Late Days',
      'Absent Days',
      'Excused Days',
      'Total Days',
      'Attendance Rate',
    ];

    for (int i = 0; i < headers.length; i++) {
      var headerCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: rowIndex,
        ),
      );
      headerCell.value = excel_lib.TextCellValue(headers[i]);
      headerCell.cellStyle = excel_lib.CellStyle(bold: true);
    }
    rowIndex++;

    // Student data rows
    for (final student in studentsList) {
      final studentId = student['id'] as int;
      final stats = studentAttendanceStats[studentId] ?? {};
      final fullName =
          '${student['fname']} ${student['mname'] ?? ''} ${student['lname']}'
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      final present = stats['present'] ?? 0;
      final late = stats['late'] ?? 0;
      final absent = stats['absent'] ?? 0;
      final excused = stats['excused'] ?? 0;
      final total = present + late + absent + excused;
      final attendanceRate =
          total > 0
              ? ((present + late) / total * 100).toStringAsFixed(1) + '%'
              : 'N/A';

      final birthday =
          student['birthday'] != null
              ? DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.parse(student['birthday']))
              : '';

      final rowData = [
        student['id']?.toString() ?? '',
        fullName,
        student['grade_level'] ?? '',
        student['gender'] ?? '',
        birthday,
        student['address'] ?? '',
        present,
        late,
        absent,
        excused,
        total,
        attendanceRate,
      ];

      for (int i = 0; i < rowData.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: rowIndex,
          ),
        );
        if (i >= 6 && i <= 10) {
          // Numeric attendance data: Present(6), Late(7), Absent(8), Excused(9), Total(10)
          cell.value = excel_lib.IntCellValue(rowData[i] as int);
        } else {
          cell.value = excel_lib.TextCellValue(rowData[i].toString());
        }
      }
      rowIndex++;
    }

    // Auto-resize columns based on content
    const double minWidth = 8.0;
    const double maxWidth = 35.0;

    // Auto-size based on approximate content width
    for (int col = 0; col < 15; col++) {
      double columnWidth = minWidth;
      switch (col) {
        case 0:
          columnWidth = 12.0;
          break; // Student ID
        case 4:
          columnWidth = 25.0;
          break; // Full Name
        case 5:
          columnWidth = 12.0;
          break; // Grade Level
        case 6:
          columnWidth = 10.0;
          break; // Gender
        case 7:
          columnWidth = 12.0;
          break; // Birthday
        case 8:
          columnWidth = 30.0;
          break; // Address
        case 9:
          columnWidth = 12.0;
          break; // Present Days
        case 10:
          columnWidth = 12.0;
          break; // Late Days
        case 11:
          columnWidth = 12.0;
          break; // Absent Days
        case 12:
          columnWidth = 12.0;
          break; // Excused Days
        case 13:
          columnWidth = 12.0;
          break; // Total Days
        case 14:
          columnWidth = 15.0;
          break; // Attendance Rate
      }
      sheet.setColumnWidth(
        col,
        columnWidth > maxWidth ? maxWidth : columnWidth,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Container(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.onBack != null)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF8F9BB3),
                          size: 24,
                        ),
                        onPressed: widget.onBack,
                        tooltip: "Back",
                      ),
                    ),
                  Text(
                    widget.sectionName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Month navigation
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFEDF1F7),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF2563EB),
                          ),
                          splashRadius: 18,
                          tooltip: "Previous Month",
                          onPressed: _prevMonth,
                        ),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF2E3A59),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF2563EB),
                          ),
                          splashRadius: 18,
                          tooltip: "Next Month",
                          onPressed: _nextMonth,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  // Spacer to push controls to the right edge
                  const Spacer(),
                  const SizedBox(width: 8),
                  // Export button (consistent with attendance taking page)
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF2ECC71),
                        size: 18,
                      ),
                      label: const Text(
                        "Export",
                        style: TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: _exportAttendance,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF2ECC71),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                        shadowColor: Colors.black.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Attendance stats summary row
              _buildSummaryStats(),
              
              const SizedBox(height: 16),
              
              // Quick attendance insights
              _buildAttendanceQuickStats(),

              const SizedBox(height: 20),

              // Table Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  child:
                      isLoading
                          ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          )
                          : (errorMessage != null
                              ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Table Header
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFF2F6FF),
                                          const Color(0xFFE8F1FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 24,
                                    ),
                                    child: Row(
                                      children: [
                                        _th("Student", flex: 3),
                                        _th("Present"),
                                        _th("Late"),
                                        _th("Absent"),
                                        _th("Excused"),
                                        _th("% Present"),
                                      ],
                                    ),
                                  ),
                                  if (students.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 40,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "No students found in this section.",
                                          style: TextStyle(
                                            color: Color(0xFF8F9BB3),
                                            fontSize: 15,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ...students.map((s) {
                                    final stat =
                                        studentAttendanceStats[s['id']] ?? {};
                                    final total = stat['total'] ?? 0;
                                    final present = stat['present'] ?? 0;
                                    final pct =
                                        total > 0
                                            ? ((present / total) * 100).round()
                                            : 0;
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            () =>
                                                _showStudentAttendanceCalendar(
                                                  s['id'] as int,
                                                  "${s['fname']} ${s['lname']}",
                                                ),
                                        borderRadius: BorderRadius.circular(8),
                                        hoverColor: const Color(0xFFF8FAFF),
                                        splashColor: const Color(
                                          0xFFE3F2FD,
                                        ).withOpacity(0.3),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: const Color(0xFFF0F1F5),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 24,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE8F4FD,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        image:
                                                            s['profile_image_url'] !=
                                                                        null &&
                                                                    s['profile_image_url']
                                                                        .toString()
                                                                        .isNotEmpty
                                                                ? DecorationImage(
                                                                  image: NetworkImage(
                                                                    s['profile_image_url'],
                                                                  ),
                                                                  fit:
                                                                      BoxFit
                                                                          .cover,
                                                                  onError: (
                                                                    exception,
                                                                    stackTrace,
                                                                  ) {
                                                                    // Handle image loading error silently
                                                                    print(
                                                                      'Error loading profile image: $exception',
                                                                    );
                                                                  },
                                                                )
                                                                : null,
                                                      ),
                                                      child:
                                                          s['profile_image_url'] ==
                                                                      null ||
                                                                  s['profile_image_url']
                                                                      .toString()
                                                                      .isEmpty
                                                              ? Center(
                                                                child: Text(
                                                                  "${s['fname']?[0] ?? ''}${s['lname']?[0] ?? ''}"
                                                                      .toUpperCase(),
                                                                  style: const TextStyle(
                                                                    color: Color(
                                                                      0xFF2563EB,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              )
                                                              : null,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  "${s['fname']} ${s['lname']}",
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      const TextStyle(
                                                                        color: Color(
                                                                          0xFF222B45,
                                                                        ),
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        fontSize: 14,
                                                                      ),
                                                                ),
                                                              ),
                                                              // Attendance status badge
                                                              if (studentBadgeStatus.containsKey(s['id']))
                                                                Padding(
                                                                  padding: const EdgeInsets.only(left: 8),
                                                                  child: AttendanceStatusBadgeFromService(
                                                                    badgeStatus: studentBadgeStatus[s['id']]!,
                                                                    fontSize: 8,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                  ),
                                                                ),
                                                              // Notification pending indicator
                                                              if (studentNotificationStatus[s['id']] == true)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(left: 4),
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(6),
                                                                      border: Border.all(
                                                                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                                                                        width: 1,
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        Icon(
                                                                          Icons.notifications_active,
                                                                          size: 8,
                                                                          color: const Color(0xFF3B82F6),
                                                                        ),
                                                                        const SizedBox(width: 2),
                                                                        Text(
                                                                          'Notified',
                                                                          style: TextStyle(
                                                                            fontSize: 8,
                                                                            color: const Color(0xFF3B82F6),
                                                                            fontWeight: FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .calendar_today,
                                                                size: 12,
                                                                color:
                                                                    const Color(
                                                                      0xFF8F9BB3,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                "View calendar",
                                                                style: const TextStyle(
                                                                  color: Color(
                                                                    0xFF8F9BB3,
                                                                  ),
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _td("${stat['present'] ?? 0}"),
                                              _td("${stat['late'] ?? 0}"),
                                              _td("${stat['absent'] ?? 0}"),
                                              _td("${stat['excused'] ?? 0}"),
                                              _td("$pct%"),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              )),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  "Tap a student's name to view detailed calendar.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to check if a date is a class day
  bool _isClassDay(DateTime date) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final abbrev = weekDays[date.weekday - 1];
    return classDays.contains(abbrev);
  }

  // Helper method to check if a student has unresolved notifications
  // Public method to refresh data - can be called after notification operations
  Future<void> refreshData() async {
    await _loadData();
  }

  Future<bool> _hasUnresolvedNotification(int studentId) async {
    print('=== _hasUnresolvedNotification called for student $studentId ===');
    try {
      // Get ALL notifications for this student (not filtered by date)
      final notifications = await supabase
          .from('notifications')
          .select('type, created_at, title, message')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
          
      print('Found ${notifications.length} notifications for student $studentId');
      if (notifications.isNotEmpty) {
        print('All notifications for student $studentId:');
        for (int i = 0; i < notifications.length && i < 10; i++) {
          final notif = notifications[i];
          print('  ${i + 1}. Type: ${notif['type']}, Date: ${notif['created_at']}, Title: ${notif['title']}');
        }
      }
      
      // Filter to only the types we care about
      final relevantNotifications = notifications.where((n) => [
        'attendance_alert',
        'attendance_ticket', 
        'system_log_attendance_alert',
        'system_log_ticket_ticket_created',  // This is the actual type being created!
        'attendance_resolved',
        'system_log_ticket_ticket_resolved'
      ].contains(n['type'])).toList();
      
      print('Found ${relevantNotifications.length} relevant notifications for student $studentId');
      if (relevantNotifications.isNotEmpty) {
        print('Relevant notification types: ${relevantNotifications.map((n) => n['type']).toList()}');
        // Look for the most recent notification that's not a resolution
        Map<String, dynamic>? latestAlert;
        Map<String, dynamic>? latestResolution;
        
        for (final notification in notifications) {
          final type = notification['type'] as String;
          if (['attendance_alert', 'attendance_ticket', 'system_log_attendance_alert', 'system_log_ticket_ticket_created'].contains(type)) {
            latestAlert ??= notification;
          } else if (['attendance_resolved', 'system_log_ticket_ticket_resolved'].contains(type)) {
            latestResolution ??= notification;
          }
        }
        
        // If no alert found, no unresolved notifications
        if (latestAlert == null) {
          return false;
        }
        
        // If no resolution found, alert is unresolved
        if (latestResolution == null) {
          return true;
        }
        
        // Compare dates to see if resolution is after the latest alert
        final alertDate = DateTime.parse(latestAlert['created_at']);
        final resolutionDate = DateTime.parse(latestResolution['created_at']);
        
        final isUnresolved = alertDate.isAfter(resolutionDate);
        return isUnresolved;
      }
      
      return false;
    } catch (e) {
      print('Error checking unresolved notifications for student $studentId: $e');
      return false;
    }
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );

  Widget _td(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF222B45),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    ),
  );

  // Create the Monthly Calendar sheet with students as rows and days as columns
  Future<void> _createMonthlyCalendarSheet(
    excel_lib.Sheet sheet,
    Map<String, dynamic> attendanceData,
  ) async {
    int rowIndex = 0;
    final attendanceRecords =
        attendanceData['attendanceRecords'] as List<dynamic>;
    final studentsList =
        attendanceData['students'] as List<Map<String, dynamic>>;
    final sectionInfo = attendanceData['sectionInfo'] as Map<String, dynamic>;
    final selectedMonth = attendanceData['selectedMonth'] as DateTime;

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'MONTHLY ATTENDANCE CALENDAR - ${sectionInfo['name']} (${DateFormat.yMMMM().format(selectedMonth)})',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
    rowIndex += 2;

    // Create attendance lookup map for quick access
    Map<String, String> attendanceLookup = {};
    for (final record in attendanceRecords) {
      final studentId = record['student_id'].toString();
      final date = record['date'];
      final status = record['status'] ?? 'Unknown';
      attendanceLookup['${studentId}_${date}'] = status;
    }

    // Get all days in the month and filter out Saturdays and non-class days
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    List<DateTime> monthDays = [];

    // Parse section schedule to determine class days
    final sectionSchedule = sectionInfo['schedule'] as String?;
    Set<int> classDays = _parseScheduleDays(sectionSchedule);

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(selectedMonth.year, selectedMonth.month, day);
      final dayOfWeek = date.weekday; // Monday = 1, Sunday = 7

      // Skip Saturdays (6) and days not in class schedule
      if (dayOfWeek != 6 && classDays.contains(dayOfWeek)) {
        monthDays.add(date);
      }
    }

    // Create headers - Student Name + Day columns
    var studentHeaderCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    studentHeaderCell.value = excel_lib.TextCellValue('Student Name');
    studentHeaderCell.cellStyle = excel_lib.CellStyle(bold: true);

    // Day headers
    for (int i = 0; i < monthDays.length; i++) {
      final day = monthDays[i];
      var dayHeaderCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: i + 1,
          rowIndex: rowIndex,
        ),
      );
      dayHeaderCell.value = excel_lib.TextCellValue('${day.month}/${day.day}');
      dayHeaderCell.cellStyle = excel_lib.CellStyle(bold: true);
    }
    rowIndex++;

    // Add legend row
    var legendCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    legendCell.value = excel_lib.TextCellValue('Legend:');
    legendCell.cellStyle = excel_lib.CellStyle(bold: true);

    var legendValueCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
    );
    legendValueCell.value = excel_lib.TextCellValue(
      'P=Present, L=Late, A=Absent, E=Excused, X=Emergency Exit, -=No Record (Future)',
    );
    rowIndex += 2;

    // Student rows
    for (final student in studentsList) {
      final studentId = student['id'].toString();
      final fullName =
          '${student['fname']} ${student['mname'] ?? ''} ${student['lname']}'
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      // Student name cell
      var nameCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      nameCell.value = excel_lib.TextCellValue(fullName);

      // Attendance status for each class day
      for (int i = 0; i < monthDays.length; i++) {
        final day = monthDays[i];
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final lookupKey = '${studentId}_${dateStr}';
        final status = attendanceLookup[lookupKey];

        var dayCell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(
            columnIndex: i + 1,
            rowIndex: rowIndex,
          ),
        );

        // Check if the day is in the future (greater than current date)
        final today = DateTime.now();
        final currentDate = DateTime(today.year, today.month, today.day);
        final checkDate = DateTime(day.year, day.month, day.day);

        String indicator;
        String cellStatus;

        if (checkDate.isAfter(currentDate)) {
          // Future date - no record
          indicator = _getStatusIndicator(status, defaultToAbsent: false);
          cellStatus = status ?? 'no_record';
        } else {
          // Past or current date - default to absent if no record
          indicator = _getStatusIndicator(status, defaultToAbsent: true);
          cellStatus = status ?? 'absent';
        }

        dayCell.value = excel_lib.TextCellValue(indicator);
        dayCell.cellStyle = _getStatusCellStyle(cellStatus);
      }
      rowIndex++;
    }

    // Auto-resize columns based on content
    // Student name column - wider
    sheet.setColumnWidth(0, 25.0);

    // Day columns - auto-size based on Month/Day format (e.g., "9/15")
    for (int i = 1; i <= monthDays.length; i++) {
      sheet.setColumnWidth(i, 6.0); // Optimized for M/D format
    }
  }

  // Helper method to parse section schedule and return class days
  Set<int> _parseScheduleDays(String? schedule) {
    Set<int> classDays = {};

    if (schedule == null || schedule.isEmpty) {
      // Default to Monday-Friday if no schedule specified
      return {1, 2, 3, 4, 5}; // Monday to Friday
    }

    // Convert schedule string to day numbers
    // Expected format: "Monday, Tuesday, Wednesday, Thursday, Friday" or similar
    final scheduleUpper = schedule.toUpperCase();

    if (scheduleUpper.contains('MONDAY') || scheduleUpper.contains('MON'))
      classDays.add(1);
    if (scheduleUpper.contains('TUESDAY') || scheduleUpper.contains('TUE'))
      classDays.add(2);
    if (scheduleUpper.contains('WEDNESDAY') || scheduleUpper.contains('WED'))
      classDays.add(3);
    if (scheduleUpper.contains('THURSDAY') || scheduleUpper.contains('THU'))
      classDays.add(4);
    if (scheduleUpper.contains('FRIDAY') || scheduleUpper.contains('FRI'))
      classDays.add(5);
    if (scheduleUpper.contains('SUNDAY') || scheduleUpper.contains('SUN'))
      classDays.add(7);

    // If no days were parsed, default to Monday-Friday
    if (classDays.isEmpty) {
      classDays = {1, 2, 3, 4, 5};
    }

    return classDays;
  }

  // Helper method to get status indicator
  String _getStatusIndicator(String? status, {bool defaultToAbsent = false}) {
    if (status == null) {
      return defaultToAbsent ? 'A' : '-';
    }

    switch (status.toLowerCase()) {
      case 'present':
        return 'P';
      case 'late':
        return 'L';
      case 'absent':
        return 'A';
      case 'excused':
        return 'E';
      case 'emergency exit':
        return 'X';
      default:
        return '?';
    }
  }

  // Helper method to get cell style based on status
  excel_lib.CellStyle _getStatusCellStyle(String status) {
    // Use bold styling for different statuses
    // Colors will be represented by the indicator letters themselves
    // Special handling for no_record (future dates) - use normal styling
    if (status == 'no_record') {
      return excel_lib.CellStyle(bold: false);
    }
    return excel_lib.CellStyle(bold: true);
  }
}
