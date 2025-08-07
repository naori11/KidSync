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

      final records = await supabase
          .from('scan_records')
          .select('scan_time, status, action, notes')
          .eq('student_id', widget.studentId)
          .gte('scan_time', startOfMonth.toIso8601String())
          .lte('scan_time', endOfMonth.toIso8601String())
          .order('scan_time', ascending: true);

      scanRecordsByDate.clear();
      for (final rec in records) {
        final dt = DateTime.tryParse(rec['scan_time'] ?? "");
        if (dt != null) {
          final date = DateTime(dt.year, dt.month, dt.day);
          scanRecordsByDate.putIfAbsent(date, () => []).add(rec);
        }
      }

      totalPresent = totalAbsent = totalLate = totalExcused = totalDays = 0;
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      for (int i = 1; i <= lastDay.day; i++) {
        final date = DateTime(selectedMonth.year, selectedMonth.month, i);
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
        }
        totalDays++;
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
    rows.add(
      Row(
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
              padding: const EdgeInsets.all(4.0),
              child:
                  inMonth
                      ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isClassDay(cellDate)
                                    ? const Color(0xFFEDF1F7)
                                    : const Color(0xFFF3F6FA),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 0,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "$cellDay",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color:
                                        isClassDay(cellDate)
                                            ? const Color(0xFF2E3A59)
                                            : const Color(0xFFBDBDBD),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (records != null && records.isNotEmpty)
                                  ...records
                                      .take(2)
                                      .map(
                                        (scan) => Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(
                                            left: 1.5,
                                            right: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: scanDotColor(cellDate, scan),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (records != null && records.isNotEmpty)
                              ...records.take(2).map((scan) {
                                String scanTimeStr = scan['scan_time'] ?? "";
                                DateTime? scanTime = DateTime.tryParse(
                                  scanTimeStr,
                                );
                                String timeDisplay =
                                    scanTime != null
                                        ? DateFormat.jm().format(scanTime)
                                        : "";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeDisplay,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8F9BB3),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else if (isClassDay(cellDate))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  "No Data",
                                  style: TextStyle(
                                    color: const Color(0xFFBDBDBD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                      : const SizedBox(),
            ),
          ),
        );
      }
      rows.add(Row(children: dayCells));
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
