import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherStudentAttendanceCalendarPage extends StatefulWidget {
  final int studentId;
  final String studentName;
  final int sectionId;
  final String sectionName;
  final VoidCallback? onBack;

  const TeacherStudentAttendanceCalendarPage({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.sectionId,
    required this.sectionName,
    this.onBack,
  }) : super(key: key);

  @override
  State<TeacherStudentAttendanceCalendarPage> createState() =>
      _TeacherStudentAttendanceCalendarPageState();
}

class _TeacherStudentAttendanceCalendarPageState
    extends State<TeacherStudentAttendanceCalendarPage> {
  final supabase = Supabase.instance.client;
  Map<DateTime, List<Map<String, dynamic>>> scanRecordsByDate = {};
  bool isLoading = true;
  String? errorMessage;
  DateTime selectedMonth = DateTime.now();

  List<String> classDays = [];
  String? classStartTime;
  String? classEndTime;

  int totalPresent = 0;
  int totalAbsent = 0;
  int totalLate = 0;
  int totalExcused = 0;
  int totalDays = 0;

  // Student information
  String? studentGradeLevel;
  String? studentSectionName;
  String? studentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadScheduleAndCalendar();
  }

  Future<void> _loadScheduleAndCalendar() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Load student information
      final studentInfo =
          await supabase
              .from('students')
              .select('''
            grade_level,
            profile_image_url,
            sections!inner(name)
          ''')
              .eq('id', widget.studentId)
              .maybeSingle();

      if (studentInfo != null) {
        studentGradeLevel = studentInfo['grade_level'];
        studentProfileImageUrl = studentInfo['profile_image_url'];
        studentSectionName = studentInfo['sections']?['name'];
      }

      // Load all section_teachers rows for this section (supports multiple schedule rows)
      final assignmentRows = await supabase
          .from('section_teachers')
          .select('days, start_time, end_time, assigned_at, subject')
          .eq('section_id', widget.sectionId)
          .order('assigned_at', ascending: true);

      final List<Map<String, dynamic>> assignments =
          List<Map<String, dynamic>>.from(assignmentRows ?? []);

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
        for (final a in rowsToConsider) {
          final st = a['start_time']?.toString() ?? '';
          final et = a['end_time']?.toString() ?? '';
          final sp = st.split(':');
          final ep = et.split(':');
          if (sp.length >= 2 && ep.length >= 2) {
            final sDt = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(sp[0]),
              int.parse(sp[1]),
            );
            final eDt = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(ep[0]),
              int.parse(ep[1]),
            );
            if (earliest == null || sDt.isBefore(earliest)) {
              earliest = sDt;
              earliestStr = st;
            }
            if (latest == null || eDt.isAfter(latest)) {
              latest = eDt;
              latestStr = et;
            }
          }
        }

        if (earliestStr != null && latestStr != null) {
          classStartTime = earliestStr;
          classEndTime = latestStr;
        }
      }

      final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endOfMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      // Load from section_attendance table instead of scan_records
      final startDateStr =
          "${startOfMonth.year.toString().padLeft(4, '0')}-${startOfMonth.month.toString().padLeft(2, '0')}-${startOfMonth.day.toString().padLeft(2, '0')}";
      final endDateStr =
          "${endOfMonth.year.toString().padLeft(4, '0')}-${endOfMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}";

      final records = await supabase
          .from('section_attendance')
          .select('date, status, notes, marked_at')
          .eq('student_id', widget.studentId)
          .eq('section_id', widget.sectionId)
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date', ascending: true);

      scanRecordsByDate.clear();
      for (final rec in records) {
        final dateStr = rec['date'] ?? "";
        final dt = DateTime.tryParse(dateStr);
        if (dt != null) {
          final date = DateTime(dt.year, dt.month, dt.day);
          // Convert the attendance record to match the expected format
          final attendanceRecord = {
            'scan_time':
                rec['marked_at'] ?? dateStr, // Use marked_at time or date
            'status': rec['status'],
            'notes': rec['notes'],
            'action': 'attendance', // Add a default action
          };
          scanRecordsByDate.putIfAbsent(date, () => []).add(attendanceRecord);
        }
      }

      // Calculate statistics based on attendance records
      totalPresent = totalAbsent = totalLate = totalExcused = totalDays = 0;
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      final now = DateTime.now();

      for (int i = 1; i <= lastDay.day; i++) {
        final date = DateTime(selectedMonth.year, selectedMonth.month, i);

        // Only count class days for statistics
        if (isClassDay(date)) {
          final records = scanRecordsByDate[date];
          String? dayStatus;

          if (records != null && records.isNotEmpty) {
            dayStatus = records.first['status'];
          } else {
            // No attendance record for this class day
            // Mark as absent if it's a past date or today
            if (date.isBefore(now.subtract(const Duration(days: 1))) ||
                (date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day)) {
              dayStatus = "Absent";
            }
            // Future dates are not counted in statistics
          }

          // Only count days that have a determined status (past dates + today)
          if (dayStatus != null) {
            switch (dayStatus) {
              case "Present":
                totalPresent++;
                break;
              case "Absent":
                totalAbsent++;
                break;
              case "Late":
                totalLate++;
                break;
              case "Excused":
                totalExcused++;
                break;
            }
            totalDays++;
          }
        }
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
    _loadScheduleAndCalendar();
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
    _loadScheduleAndCalendar();
  }

  bool isClassDay(DateTime date) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final abbrev = weekDays[date.weekday - 1];
    return classDays.contains(abbrev);
  }

  DateTime? classStartDateTime(DateTime date) {
    if (classStartTime == null) return null;
    final parts = classStartTime!.split(':');
    if (parts.length < 2) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime? classEndDateTime(DateTime date) {
    if (classEndTime == null) return null;
    final parts = classEndTime!.split(':');
    if (parts.length < 2) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Color scanDotColor(DateTime date, Map<String, dynamic> scan) {
    if (!isClassDay(date)) return const Color(0xFFBDBDBD);

    final status = scan['status'] ?? "Absent";
    if (status == "Excused") return const Color(0xFF2563EB);
    if (status == "Absent" || status == "No Data")
      return const Color(0xFFEB5757);

    final scanTime = DateTime.tryParse(scan['scan_time'] ?? "");
    final start = classStartDateTime(date);
    if (scanTime != null && start != null) {
      if (scanTime.isBefore(start.add(const Duration(minutes: 1)))) {
        return const Color(0xFF19AE61);
      } else {
        return const Color(0xFFFFA726);
      }
    }
    return const Color(0xFF19AE61);
  }

  Widget _attendanceLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(const Color(0xFF19AE61), "Present"),
        _legendItem(const Color(0xFFEB5757), "Absent"),
        _legendItem(const Color(0xFFFFA726), "Late"),
        _legendItem(const Color(0xFF2563EB), "Excused"),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _attendanceCalendar() {
    final firstDayOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    );
    int daysInMonth = lastDayOfMonth.day;

    int firstWeekday = firstDayOfMonth.weekday % 7;
    int leadingEmptyDays = firstWeekday;

    final weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    int numWeeks = ((leadingEmptyDays + daysInMonth) / 7).ceil();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with weekday labels
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            (i == 0 || i == 6)
                                ? Color(0xFF8F9BB3)
                                : Color(0xFF2E3A59),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Calendar grid with flexible sizing
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate available height for calendar rows
                final availableHeight = constraints.maxHeight;
                final rowHeight = availableHeight / numWeeks;

                return Column(
                  children: List.generate(numWeeks, (week) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: List.generate(7, (d) {
                            int cellIndex = week * 7 + d;
                            int cellDay = cellIndex - leadingEmptyDays + 1;
                            bool inMonth =
                                cellDay >= 1 && cellDay <= daysInMonth;
                            DateTime cellDate =
                                inMonth
                                    ? DateTime(
                                      selectedMonth.year,
                                      selectedMonth.month,
                                      cellDay,
                                    )
                                    : DateTime(2000);

                            final records =
                                inMonth ? scanRecordsByDate[cellDate] : null;

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(1.5),
                                child:
                                    inMonth
                                        ? _buildDayCell(
                                          cellDate,
                                          cellDay,
                                          records,
                                        )
                                        : const SizedBox(),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime cellDate,
    int cellDay,
    List<Map<String, dynamic>>? records,
  ) {
    final bool isClassDay = this.isClassDay(cellDate);
    final bool isToday =
        cellDate.year == DateTime.now().year &&
        cellDate.month == DateTime.now().month &&
        cellDate.day == DateTime.now().day;
    final bool isPastDate = cellDate.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final bool isFutureDate = cellDate.isAfter(DateTime.now());

    // Determine the primary status for this day
    String dayStatus = "";
    Color statusColor = const Color(0xFFBDBDBD);
    Color backgroundColor = Colors.white;
    Color borderColor = const Color(0xFFF3F6FA);

    if (records != null && records.isNotEmpty) {
      final primaryRecord = records.first;
      dayStatus = primaryRecord['status'] ?? "";

      switch (dayStatus) {
        case "Present":
          statusColor = const Color(0xFF19AE61);
          backgroundColor = const Color(0xFFF0F9F4);
          borderColor = const Color(0xFF19AE61);
          break;
        case "Late":
          statusColor = const Color(0xFFFFA726);
          backgroundColor = const Color(0xFFFFF8E1);
          borderColor = const Color(0xFFFFA726);
          break;
        case "Absent":
          statusColor = const Color(0xFFEB5757);
          backgroundColor = const Color(0xFFFEF2F2);
          borderColor = const Color(0xFFEB5757);
          break;
        case "Excused":
          statusColor = const Color(0xFF2563EB);
          backgroundColor = const Color(0xFFF0F4FF);
          borderColor = const Color(0xFF2563EB);
          break;
        default:
          // If we have a record but no valid status, treat as absent for class days
          if (isClassDay) {
            dayStatus = "Absent";
            statusColor = const Color(0xFFEB5757);
            backgroundColor = const Color(0xFFFEF2F2);
            borderColor = const Color(0xFFEB5757);
          }
      }
    } else if (isClassDay) {
      // Class day with no attendance record
      if (isPastDate || isToday) {
        // Past class days or today without records = Absent
        dayStatus = "Absent";
        statusColor = const Color(0xFFEB5757);
        backgroundColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEB5757);
      } else {
        // Future class days = neutral styling (no status yet)
        backgroundColor = const Color(0xFFF8F9FA);
        borderColor = const Color(0xFFEDF1F7);
        dayStatus = ""; // Empty status for future dates
      }
    }

    // Special styling for today
    if (isToday) {
      borderColor = const Color(0xFF2563EB);
    }

    final Color dayNumberColor =
        isClassDay
            ? (dayStatus.isEmpty && isFutureDate
                ? const Color(0xFF2E3A59)
                : statusColor)
            : const Color(0xFFBDBDBD);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width:
              isToday ? 2.0 : (dayStatus.isNotEmpty && isClassDay ? 1.5 : 1.0),
        ),
        boxShadow:
            dayStatus.isNotEmpty && isClassDay
                ? [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day number with enhanced visibility
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration:
                isToday
                    ? BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    )
                    : null,
            child: Text(
              "$cellDay",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isToday ? Colors.white : dayNumberColor,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Enhanced status indicator
          if (isClassDay)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  // Status indicator bar for days with status
                  if (dayStatus.isNotEmpty)
                    Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    // Future class days without status - show a subtle indicator
                    Container(
                      width: 12,
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),

                  const SizedBox(height: 3),

                  // Status text or time
                  if (records != null && records.isNotEmpty)
                    _buildCompactTimeDisplay(records.first)
                  else if (dayStatus.isNotEmpty)
                    Text(
                      dayStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    // Future class days - show dash
                    Text(
                      "—",
                      style: TextStyle(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            )
          else
            // Non-class day indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3F4F6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactTimeDisplay(Map<String, dynamic> scan) {
    String scanTimeStr = scan['scan_time'] ?? "";
    DateTime? scanTime = DateTime.tryParse(scanTimeStr);
    String timeDisplay =
        scanTime != null ? DateFormat.jm().format(scanTime) : "";

    if (timeDisplay.isEmpty) {
      String status = scan['status'] ?? "Absent";
      // Don't show "No Data" - default to status or "Absent"
      if (status == "No Data") status = "Absent";

      return Text(
        status.length > 6 ? status.substring(0, 6) : status,
        style: TextStyle(
          fontSize: 9,
          color:
              status == "Absent"
                  ? const Color(0xFFEB5757)
                  : const Color(0xFF8F9BB3),
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      timeDisplay,
      style: const TextStyle(
        fontSize: 9,
        color: Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTimeDisplay(Map<String, dynamic> scan) {
    String scanTimeStr = scan['scan_time'] ?? "";
    DateTime? scanTime = DateTime.tryParse(scanTimeStr);
    String timeDisplay =
        scanTime != null ? DateFormat.jm().format(scanTime) : "";

    if (timeDisplay.isEmpty) {
      String status = scan['status'] ?? "Absent";
      // Don't show "No Data" - default to status or "Absent"
      if (status == "No Data") status = "Absent";

      return Text(
        status,
        style: TextStyle(
          fontSize: 10,
          color:
              status == "Absent"
                  ? const Color(0xFFEB5757)
                  : const Color(0xFF8F9BB3),
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time, size: 10, color: Color(0xFF8F9BB3)),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            timeDisplay,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Scaffold(
        backgroundColor: const Color.fromARGB(10, 78, 241, 157),
        resizeToAvoidBottomInset: false,
        body: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with close button
              Container(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "${widget.sectionName}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF8F9BB3),
                          ),
                          Text(
                            "Student Calendar",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222B45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 24,
                          color: Color(0xFF8F9BB3),
                        ),
                        tooltip: "Close",
                        onPressed:
                            widget.onBack ?? () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Student info card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FD),
                            borderRadius: BorderRadius.circular(24),
                            image:
                                studentProfileImageUrl != null &&
                                        studentProfileImageUrl!.isNotEmpty
                                    ? DecorationImage(
                                      image: NetworkImage(
                                        studentProfileImageUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                      onError: (exception, stackTrace) {
                                        print(
                                          'Error loading profile image: $exception',
                                        );
                                      },
                                    )
                                    : null,
                          ),
                          child:
                              studentProfileImageUrl == null ||
                                      studentProfileImageUrl!.isEmpty
                                  ? Center(
                                    child: Text(
                                      widget.studentName
                                          .split(' ')
                                          .map(
                                            (name) =>
                                                name.isNotEmpty ? name[0] : '',
                                          )
                                          .take(2)
                                          .join('')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.studentName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222B45),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _buildStudentInfo(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8F9BB3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _compactAttendanceStats(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Calendar controls row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF1F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0xFF2563EB),
                            ),
                            onPressed: _prevMonth,
                          ),
                          Text(
                            monthLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E3A59),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF2563EB),
                            ),
                            onPressed: _nextMonth,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _attendanceLegend(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Attendance calendar
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                  child:
                      isLoading
                          ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          )
                          : errorMessage != null
                          ? Center(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                          : _attendanceCalendar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildStudentInfo() {
    List<String> infoParts = [];

    if (studentGradeLevel != null && studentGradeLevel!.isNotEmpty) {
      if (studentSectionName != null && studentSectionName!.isNotEmpty) {
        infoParts.add("$studentGradeLevel - $studentSectionName");
      } else {
        infoParts.add("Grade $studentGradeLevel");
      }
    } else if (studentSectionName != null && studentSectionName!.isNotEmpty) {
      infoParts.add("Section $studentSectionName");
    }

    return infoParts.isNotEmpty ? infoParts.join(" • ") : "Student Information";
  }

  Widget _compactAttendanceStats() {
    int present = totalPresent;
    int absent = totalAbsent;
    int late = totalLate;
    int total = totalDays > 0 ? totalDays : 1;
    double presentPct = (present / total) * 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            "${presentPct.round()}%",
            style: const TextStyle(
              color: Color(0xFF19AE61),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Text(
            "Present",
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF8F9BB3),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
