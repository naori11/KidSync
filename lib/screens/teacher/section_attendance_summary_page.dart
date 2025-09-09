import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_attendance_calendar_page.dart';

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
  Map<int, Map<String, int>> studentAttendanceStats = {};

  int totalPresent = 0;
  int totalLate = 0;
  int totalAbsent = 0;
  int totalExcused = 0;

  int totalPresentToday = 0;
  int totalLateToday = 0;
  int totalAbsentToday = 0;
  int totalExcusedToday = 0;

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

      students = List<Map<String, dynamic>>.from(studentRows ?? []);

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
        else if (status == 'excused')
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
    // Placeholder: replace with real export logic (CSV generation / file save / share)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export attendance not implemented yet')),
    );
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

  // compact row used in the right-side Daily panel (still available if needed elsewhere)
  Widget _dailyStatRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF222B45)),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A59),
          ),
        ),
      ],
    );
  }

  void _showStudentAttendanceCalendar(int studentId, String studentName) {
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
                  // Export button (consistent system design)
                  ElevatedButton.icon(
                    onPressed: _exportAttendance,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Export',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Attendance stats summary row
              _buildSummaryStats(),

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
                                                          Text(
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
}
