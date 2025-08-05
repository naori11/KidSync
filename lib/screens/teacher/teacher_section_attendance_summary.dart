import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> students = [];
  Map<int, Map<String, int>> studentAttendanceStats =
      {}; // studentId -> {present, absent, late, excused, total}

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Fetch all students in the section
      final studentRows = await supabase
          .from('students')
          .select('id, fname, lname')
          .eq('section_id', widget.sectionId)
          .order('lname', ascending: true);

      students = List<Map<String, dynamic>>.from(studentRows ?? []);

      // 2. Fetch all attendance records for these students for the selected month
      final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final endOfMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        0,
      );

      final attendanceRows = await supabase
          .from('section_attendance')
          .select('student_id, status')
          .eq('section_id', widget.sectionId)
          .gte('date', DateFormat('yyyy-MM-dd').format(startOfMonth))
          .lte('date', DateFormat('yyyy-MM-dd').format(endOfMonth));

      // 3. Aggregate per student
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
      for (final row in attendanceRows) {
        final int sid = row['student_id'];
        final String status = (row['status'] ?? '').toString().toLowerCase();
        final stats = studentAttendanceStats[sid];
        if (stats == null) continue;
        stats['total'] = (stats['total'] ?? 0) + 1;
        if (status == 'present')
          stats['present'] = (stats['present'] ?? 0) + 1;
        else if (status == 'absent')
          stats['absent'] = (stats['absent'] ?? 0) + 1;
        else if (status == 'late')
          stats['late'] = (stats['late'] ?? 0) + 1;
        else if (status == 'excused')
          stats['excused'] = (stats['excused'] ?? 0) + 1;
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

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);

    return Container(
      color: const Color(0xF7F9FCFF),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFF222B45),
                      ),
                      label: const Text(
                        "Back",
                        style: TextStyle(
                          color: Color(0xFF222B45),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF2F3F5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                Text(
                  "Attendance Summary",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.sectionName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const Spacer(),
                // Month navigation
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Color(0xFF2563EB),
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
              ],
            ),
            const SizedBox(height: 26),
            // Main Card/Table
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child:
                    isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
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
                                    color: const Color(0xFFF2F6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      _th("Name", flex: 3),
                                      _th("Present"),
                                      _th("Late"),
                                      _th("Absent"),
                                      _th("Excused"),
                                      _th("% Present"),
                                    ],
                                  ),
                                ),
                                for (final s in students)
                                  InkWell(
                                    onTap:
                                        widget.onViewStudentCalendar != null
                                            ? () =>
                                                widget.onViewStudentCalendar!(
                                                  s['id'] as int,
                                                  "${s['fname']} ${s['lname']}",
                                                )
                                            : null,
                                    borderRadius: BorderRadius.circular(8),
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
                                        vertical: 11,
                                      ),
                                      child: Row(
                                        children: [
                                          _td(
                                            "${s['fname']} ${s['lname']}",
                                            flex: 3,
                                            link: true,
                                          ),
                                          _td(
                                            "${studentAttendanceStats[s['id']]?['present'] ?? 0}",
                                          ),
                                          _td(
                                            "${studentAttendanceStats[s['id']]?['late'] ?? 0}",
                                          ),
                                          _td(
                                            "${studentAttendanceStats[s['id']]?['absent'] ?? 0}",
                                          ),
                                          _td(
                                            "${studentAttendanceStats[s['id']]?['excused'] ?? 0}",
                                          ),
                                          _td(() {
                                            final stats =
                                                studentAttendanceStats[s['id']] ??
                                                {};
                                            final total = stats['total'] ?? 0;
                                            final present =
                                                stats['present'] ?? 0;
                                            final pct =
                                                total > 0
                                                    ? ((present / total) * 100)
                                                        .round()
                                                    : 0;
                                            return "$pct%";
                                          }()),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (students.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 32,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "No students found in this section.",
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 15,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Tap a student's name to view detailed calendar.",
              style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    ),
  );

  Widget _td(String label, {int flex = 1, bool link = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: link ? const Color(0xFF2563EB) : const Color(0xFF222B45),
          fontWeight: link ? FontWeight.w600 : FontWeight.normal,
          decoration: link ? TextDecoration.underline : TextDecoration.none,
          fontSize: 14.5,
        ),
      ),
    ),
  );
}
