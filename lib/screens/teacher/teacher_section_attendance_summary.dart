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

  int totalPresent = 0;
  int totalLate = 0;
  int totalAbsent = 0;
  int totalExcused = 0;

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

      // 4. Compute totals for summary row
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

  Widget _buildSummaryStats() {
    TextStyle labelStyle = const TextStyle(
      fontSize: 14,
      color: Color(0xFF8F9BB3),
    );
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _statColumn("Present", totalPresent, const Color(0xFF19AE61)),
            const SizedBox(width: 28),
            _statColumn("Late", totalLate, const Color(0xFFF59E42)),
            const SizedBox(width: 28),
            _statColumn("Absent", totalAbsent, const Color(0xFFE14D4D)),
            const SizedBox(width: 28),
            _statColumn("Excused", totalExcused, const Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$value",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3)),
        ),
      ],
    );
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
            // Header Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF222B45),
                      ),
                      onPressed: widget.onBack,
                      tooltip: "Back",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                Text(
                  widget.sectionName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(width: 24),
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
            const SizedBox(height: 6),
            // Attendance stats summary row
            _buildSummaryStats(),

            // Table Card
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                                    color: const Color(0xFFF2F6FF),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 36,
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
                                      vertical: 38,
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
                                ...students.map((s) {
                                  final stat =
                                      studentAttendanceStats[s['id']] ?? {};
                                  final total = stat['total'] ?? 0;
                                  final present = stat['present'] ?? 0;
                                  final pct =
                                      total > 0
                                          ? ((present / total) * 100).round()
                                          : 0;
                                  return InkWell(
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
                                        vertical: 13,
                                        horizontal: 36,
                                      ),
                                      child: Row(
                                        children: [
                                          _td(
                                            "${s['fname']} ${s['lname']}",
                                            flex: 3,
                                            link: true,
                                          ),
                                          _td("${stat['present'] ?? 0}"),
                                          _td("${stat['late'] ?? 0}"),
                                          _td("${stat['absent'] ?? 0}"),
                                          _td("${stat['excused'] ?? 0}"),
                                          _td("$pct%"),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            )),
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                "Tap a student's name to view detailed calendar.",
                style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
              ),
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
