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

  // Schedule info
  List<String> classDays = [];
  String? classStartTime;
  String? classEndTime;

  // For statistics
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
      // 1. Fetch schedule info from section_teachers for this section & student
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

      // 2. Fetch all scan_records for the student for the month
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

      // Group all scan records by date (multiple entries per day possible)
      scanRecordsByDate.clear();
      for (final rec in records) {
        final dt = DateTime.tryParse(rec['scan_time'] ?? "");
        if (dt != null) {
          final date = DateTime(dt.year, dt.month, dt.day);
          scanRecordsByDate.putIfAbsent(date, () => []).add(rec);
        }
      }

      // Compute stats
      totalPresent = totalAbsent = totalLate = totalExcused = totalDays = 0;
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      for (int i = 1; i <= lastDay.day; i++) {
        final date = DateTime(selectedMonth.year, selectedMonth.month, i);
        final records = scanRecordsByDate[date];
        String? dayStatus;
        if (records != null && records.isNotEmpty) {
          // Use the first record's status for summary (customize as needed)
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

  // Helper: returns true if class is scheduled on this date
  bool isClassDay(DateTime date) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final abbrev = weekDays[date.weekday - 1];
    return classDays.contains(abbrev);
  }

  // Helper: returns class start/end as DateTime for a day
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

  // Dot color based on actual scan and class sched
  Color scanDotColor(DateTime date, Map<String, dynamic> scan) {
    // If not a class day, show gray
    if (!isClassDay(date)) return const Color(0xFFBDBDBD);

    final status = scan['status'];
    if (status == "Excused") return const Color(0xFF2563EB);
    if (status == "Absent") return const Color(0xFFEB5757);

    // Check time for Present/Late
    final scanTime = DateTime.tryParse(scan['scan_time'] ?? "");
    final start = classStartDateTime(date);
    if (scanTime != null && start != null) {
      if (scanTime.isBefore(start.add(const Duration(minutes: 1)))) {
        return const Color(0xFF19AE61); // Present (on time)
      } else {
        return const Color(0xFFFFA726); // Late
      }
    }
    return const Color(0xFF19AE61); // Default: Present
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
          width: 13,
          height: 13,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
        ),
      ],
    );
  }

  Widget _attendanceStats() {
    int present = totalPresent;
    int absent = totalAbsent;
    int late = totalLate;
    int total = totalDays > 0 ? totalDays : 1;
    double presentPct = (present / total) * 100;
    double absentPct = (absent / total) * 100;
    double latePct = (late / total) * 100;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          "${presentPct.round()}%",
          style: const TextStyle(
            color: Color(0xFF19AE61),
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          "Present",
          style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
        ),
        const SizedBox(width: 20),
        Text(
          "${absentPct.round()}%",
          style: const TextStyle(
            color: Color(0xFFEB5757),
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          "Absent",
          style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
        ),
        const SizedBox(width: 20),
        Text(
          "${latePct.round()}%",
          style: const TextStyle(
            color: Color(0xFFFFA726),
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          "Late",
          style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
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

    int firstWeekday = firstDayOfMonth.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
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
                  fontWeight: FontWeight.w700,
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
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color:
                                isClassDay(cellDate)
                                    ? const Color(0xFFEDF1F7)
                                    : const Color(0xFFF3F6FA),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
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
                            const SizedBox(height: 7),
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
                                  padding: const EdgeInsets.only(bottom: 2.5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        timeDisplay,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8F9BB3),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            else if (isClassDay(cellDate))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2.5),
                                child: Text(
                                  "No Data",
                                  style: TextStyle(
                                    color: const Color(0xFFBDBDBD),
                                    fontSize: 13,
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
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);
    return Scaffold(
      backgroundColor: const Color(0xF7F9FCFF),
      resizeToAvoidBottomInset:
          false, // Prevents resizing on keyboard open (optional)
      body: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with X button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${widget.sectionName} / ",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                  const Text(
                    "Attendance",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 28,
                      color: Color(0xFF8F9BB3),
                    ),
                    tooltip: "Close",
                    splashRadius: 22,
                    onPressed:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Student info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEDF1F7),
                        radius: 32,
                        child: const Icon(
                          Icons.person,
                          size: 38,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                      const SizedBox(width: 22),
                      // Name, grade and id
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222B45),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Grade 8-A", // Static for now; replace with dynamic if available
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF8F9BB3),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Student ID: #ST2024001", // Static for now; replace with actual if available
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8F9BB3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Attendance stats
                      _attendanceStats(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
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
                            fontWeight: FontWeight.w500,
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
            const SizedBox(height: 12),
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
    );
  }
}
