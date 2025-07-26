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
  State<TeacherStudentAttendanceCalendarPage> createState() => _TeacherStudentAttendanceCalendarPageState();
}

class _TeacherStudentAttendanceCalendarPageState extends State<TeacherStudentAttendanceCalendarPage> {
  final supabase = Supabase.instance.client;
  Map<DateTime, Map<String, dynamic>> scanRecordsByDate = {};
  bool isLoading = true;
  String? errorMessage;
  DateTime selectedMonth = DateTime.now();

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
      final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

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

  Color statusColor(String? status) {
    switch (status) {
      case "Present":
        return const Color(0xFF2ECC71);
      case "Absent":
        return Colors.red;
      case "Late":
        return Colors.orange;
      case "Excused":
        return Colors.blue;
      default:
        return Colors.grey[300]!;
    }
  }

  IconData statusIcon(String? status) {
    switch (status) {
      case "Present":
        return Icons.check_circle_outline;
      case "Absent":
        return Icons.cancel_outlined;
      case "Late":
        return Icons.access_time;
      case "Excused":
        return Icons.info_outline;
      default:
        return Icons.remove_circle_outline;
    }
  }

  Widget _attendanceLegend() {
    return Row(
      children: [
        _legendItem(statusColor("Present"), "Present"),
        const SizedBox(width: 16),
        _legendItem(statusColor("Late"), "Late"),
        const SizedBox(width: 16),
        _legendItem(statusColor("Absent"), "Absent"),
        const SizedBox(width: 16),
        _legendItem(statusColor("Excused"), "Excused"),
        const SizedBox(width: 16),
        _legendItem(Colors.grey[300]!, "No Data"),
        const SizedBox(width: 16),
        _legendItem(Colors.grey[200]!, "Weekend"),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _attendanceCalendar() {
    // compute start and end dates
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    int daysInMonth = lastDayOfMonth.day;

    // Compute how many days to fill before the 1st of the month
    // For Sunday-first: DateTime.weekday: 1=Mon,...7=Sun, so for Sun=0
    int firstWeekday = firstDayOfMonth.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    int leadingEmptyDays = firstWeekday; // 0 if Sunday, 1 if Monday, ..., 6 if Saturday

    // Weekday header (Sunday first)
    final weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    List<Widget> rows = [];
    rows.add(Row(
      children: List.generate(7, (i) => Expanded(
        child: Center(
          child: Text(
            weekdayLabels[i],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (i == 0 || i == 6) ? Colors.grey[600] : Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      )),
    ));

    int dayCounter = 1;
    int numWeeks = ((leadingEmptyDays + daysInMonth) / 7).ceil();

    for (int week = 0; week < numWeeks; week++) {
      List<Widget> dayCells = [];
      for (int d = 0; d < 7; d++) {
        int cellIndex = week * 7 + d;
        int cellDay = cellIndex - leadingEmptyDays + 1;
        bool inMonth = cellDay >= 1 && cellDay <= daysInMonth;
        DateTime cellDate = inMonth
            ? DateTime(selectedMonth.year, selectedMonth.month, cellDay)
            : DateTime(2000); // dummy

        bool isWeekend = (d == 0 || d == 6); // Sunday/Saturday
        final rec = inMonth ? scanRecordsByDate[cellDate] : null;
        final status = rec != null ? (rec['status'] ?? "No Data") : (inMonth ? "No Data" : "");
        final scanTime = rec != null ? DateFormat('hh:mm a').format(DateTime.parse(rec['scan_time'])) : "";

        dayCells.add(
          Expanded(
            child: inMonth
                ? Tooltip(
                    message: isWeekend
                        ? "Weekend"
                        : rec != null
                            ? "${status}${scanTime.isNotEmpty ? "\n$scanTime" : ""}"
                            : "No data",
                    child: AbsorbPointer(
                      absorbing: true, // disable tap
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        decoration: BoxDecoration(
                          color: isWeekend
                              ? Colors.grey[200]
                              : status == "No Data"
                                  ? Colors.white
                                  : statusColor(status).withOpacity(0.08),
                          border: Border.all(
                            color: isWeekend
                                ? Colors.grey[300]!
                                : status == "No Data"
                                    ? Colors.grey[300]!
                                    : statusColor(status).withOpacity(0.9),
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$cellDay",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isWeekend ? Colors.grey[500] : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Icon(
                              statusIcon(status),
                              color: isWeekend
                                  ? Colors.grey[400]
                                  : status == "No Data"
                                      ? Colors.grey[400]
                                      : statusColor(status),
                              size: 20,
                            ),
                            if (status != "No Data" && !isWeekend)
                              Padding(
                                padding: const EdgeInsets.only(top: 1.5),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (scanTime.isNotEmpty && !isWeekend)
                              Text(
                                scanTime,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        );
      }
      rows.add(Row(children: dayCells));
    }

    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.onBack != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("Back"),
                          onPressed: widget.onBack,
                        ),
                      Text(
                        "${widget.sectionName} / Attendance",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Student Info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        radius: 28,
                        child: const Icon(Icons.person, size: 34, color: Colors.white),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.studentName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Student ID: ${widget.studentId}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Calendar controls
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                      const SizedBox(width: 10),
                      Text(monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                      const Spacer(),
                      _attendanceLegend(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                            ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
                            : _attendanceCalendar(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}