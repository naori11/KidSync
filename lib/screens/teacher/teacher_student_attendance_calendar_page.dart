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
  Map<DateTime, Map<String, dynamic>> scanRecordsByDate = {};
  bool isLoading = true;
  String? errorMessage;
  DateTime selectedMonth = DateTime.now();

  // For statistics
  int totalPresent = 0;
  int totalAbsent = 0;
  int totalLate = 0;
  int totalExcused = 0;
  int totalDays = 0;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch all records for the month
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
          scanRecordsByDate[date] = rec;
        }
      }

      // Compute stats
      totalPresent = totalAbsent = totalLate = totalExcused = totalDays = 0;
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      for (int i = 1; i <= lastDay.day; i++) {
        final date = DateTime(selectedMonth.year, selectedMonth.month, i);
        final rec = scanRecordsByDate[date];
        if (rec != null && rec['status'] != null) {
          switch (rec['status']) {
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
    _loadCalendar();
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
    _loadCalendar();
  }

  Color statusDotColor(String? status) {
    switch (status) {
      case "Present":
        return const Color(0xFF19AE61);
      case "Absent":
        return const Color(0xFFEB5757);
      case "Late":
        return const Color(0xFFFFA726);
      case "Excused":
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFBDBDBD);
    }
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

        final rec = inMonth ? scanRecordsByDate[cellDate] : null;
        final status =
            rec != null
                ? (rec['status'] ?? "No Data")
                : (inMonth ? "No Data" : "");

        // Demo: Show two static times as in your screenshot
        final times = [
          "08:30 AM",
          "03:30 PM",
        ]; // static for now; can be dynamic if your database supports multiple scan times/day

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
                                status == "No Data"
                                    ? const Color(0xFFEDF1F7)
                                    : statusDotColor(status).withOpacity(0.8),
                            width: status == "No Data" ? 1.0 : 1.5,
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
                                        status == "No Data"
                                            ? Color(0xFF8F9BB3)
                                            : Color(0xFF2E3A59),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (status != "No Data")
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusDotColor(status),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ...times.map(
                              (t) => Padding(
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
                                      t,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8F9BB3),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                child: Row(
                  children: [
                    if (widget.onBack != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                        tooltip: "Back",
                      ),
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
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 19),
                        label: const Text("Mark  Excuse"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 0,
                          ),
                        ),
                        onPressed: () {}, // Static for now
                      ),
                    ),
                    const Spacer(),
                    _attendanceLegend(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Attendance calendar
              Padding(
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
