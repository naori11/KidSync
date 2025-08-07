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
      final teacherAssignment =
          await supabase
              .from('section_teachers')
              .select('days, start_time, end_time')
              .eq('section_id', widget.sectionId)
              .maybeSingle();

      if (teacherAssignment != null) {
        classDays =
            teacherAssignment['days'] is List
                ? (teacherAssignment['days'] as List).cast<String>()
                : (teacherAssignment['days']?.toString() ?? '')
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
        classStartTime = teacherAssignment['start_time'];
        classEndTime = teacherAssignment['end_time'];
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

      for (int i = 1; i <= lastDay.day; i++) {
        final date = DateTime(selectedMonth.year, selectedMonth.month, i);

        // Only count class days for statistics
        if (isClassDay(date)) {
          final records = scanRecordsByDate[date];
          String? dayStatus;
          if (records != null && records.isNotEmpty) {
            dayStatus = records.first['status'];
          }

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
            default:
              // Only count as absent if it's a past class day
              if (date.isBefore(DateTime.now())) {
                totalAbsent++;
              }
              break;
          }
          totalDays++;
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

    final status = scan['status'];
    if (status == "Excused") return const Color(0xFF2563EB);
    if (status == "Absent") return const Color(0xFFEB5757);

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
    return Row(
      children: [
        _legendItem(const Color(0xFF19AE61), "Present"),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFFEB5757), "Absent"),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFFFFA726), "Late"),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFF2563EB), "Excused"),
        const SizedBox(width: 16),
        _legendItem(const Color(0xFFBDBDBD), "No Data"),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8F9BB3),
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
    List<Widget> rows = [];

    // Header row with weekday labels
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
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
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    int numWeeks = ((leadingEmptyDays + daysInMonth) / 7).ceil();

    for (int week = 0; week < numWeeks; week++) {
      List<Widget> dayCells = [];
      for (int d = 0; d < 7; d++) {
        int cellIndex = week * 7 + d;
        int cellDay = cellIndex - leadingEmptyDays + 1;
        bool inMonth = cellDay >= 1 && cellDay <= daysInMonth;
        DateTime cellDate =
            inMonth
                ? DateTime(selectedMonth.year, selectedMonth.month, cellDay)
                : DateTime(2000);

        final records = inMonth ? scanRecordsByDate[cellDate] : null;

        dayCells.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(2.0), // Reduced padding
              child:
                  inMonth
                      ? _buildDayCell(cellDate, cellDay, records)
                      : const SizedBox(),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4), // Reduced spacing
          child: Row(children: dayCells),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ), // Reduced padding
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
      child: Column(children: rows),
    );
  }

  Widget _buildDayCell(
    DateTime cellDate,
    int cellDay,
    List<Map<String, dynamic>>? records,
  ) {
    final bool isClassDay = this.isClassDay(cellDate);
    final Color borderColor =
        isClassDay ? const Color(0xFFEDF1F7) : const Color(0xFFF3F6FA);
    final Color dayNumberColor =
        isClassDay ? const Color(0xFF2E3A59) : const Color(0xFFBDBDBD);

    // Determine the primary status for this day
    String dayStatus = "No Data";
    Color statusColor = const Color(0xFFBDBDBD);

    if (records != null && records.isNotEmpty) {
      final primaryRecord = records.first;
      dayStatus = primaryRecord['status'] ?? "No Data";

      switch (dayStatus) {
        case "Present":
          statusColor = const Color(0xFF19AE61);
          break;
        case "Late":
          statusColor = const Color(0xFFFFA726);
          break;
        case "Absent":
          statusColor = const Color(0xFFEB5757);
          break;
        case "Excused":
          statusColor = const Color(0xFF2563EB);
          break;
        default:
          statusColor = const Color(0xFFBDBDBD);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Make the cell responsive to available space
        final cellHeight =
            constraints.maxWidth * 0.9; // Aspect ratio based approach

        return Container(
          height: cellHeight.clamp(60.0, 75.0), // Min 60px, max 75px
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Day number and status indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$cellDay",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: dayNumberColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Status text or time (only for class days with data)
              if (isClassDay)
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 16),
                    child:
                        records != null && records.isNotEmpty
                            ? _buildTimeDisplay(records.first)
                            : Text(
                              "No Data",
                              style: TextStyle(
                                color: const Color(0xFFBDBDBD),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                  ),
                )
              else
                const SizedBox(
                  height: 16,
                ), // Maintain spacing for non-class days
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay(Map<String, dynamic> scan) {
    String scanTimeStr = scan['scan_time'] ?? "";
    DateTime? scanTime = DateTime.tryParse(scanTimeStr);
    String timeDisplay =
        scanTime != null ? DateFormat.jm().format(scanTime) : "";

    if (timeDisplay.isEmpty) {
      return Text(
        scan['status'] ?? "Unknown",
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF8F9BB3),
          fontWeight: FontWeight.w500,
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
        backgroundColor: const Color(0xFFF7F9FC),
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
                        CircleAvatar(
                          backgroundColor: const Color(0xFFEDF1F7),
                          radius: 24,
                          child: const Icon(
                            Icons.person,
                            size: 28,
                            color: Color(0xFF8F9BB3),
                          ),
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
                                "Grade 8-A • Student ID: #ST2024001",
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
                  padding: const EdgeInsets.symmetric(horizontal: 32),
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
