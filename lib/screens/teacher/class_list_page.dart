import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your summary page (make sure to adjust the import path as needed)
import 'section_attendance_summary_page.dart';
import 'student_attendance_calendar_page.dart'; // for drilldown, if you want to navigate to student calendar

class TeacherClassListPage extends StatefulWidget {
  final void Function(int sectionId, String sectionName)? onViewAttendance;
  final void Function(int sectionId, String sectionName)? onViewSummary;
  const TeacherClassListPage({
    super.key,
    this.onViewAttendance,
    this.onViewSummary,
  });

  @override
  State<TeacherClassListPage> createState() => _TeacherClassListPageState();
}

class _TeacherClassListPageState extends State<TeacherClassListPage> {
  final supabase = Supabase.instance.client;
  String? teacherId;
  // assignedSections now holds one entry per section (aggregated)
  List<Map<String, dynamic>> assignedSections = [];
  Map<int, List<Map<String, dynamic>>> sectionStudents = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassList();
  }

  // Utility to format schedule (handles multiple schedule rows)
  String formatSchedule(Map<String, dynamic> assignment) {
    final schedules =
        assignment['schedules'] as List<Map<String, dynamic>>? ?? [];
    if (schedules.isEmpty) return "--";

    // Each schedule map: {days: List<String>, start_time: String, end_time: String}
    final pieces =
        schedules.map((s) {
          final daysList =
              s['days'] is List
                  ? (s['days'] as List).cast<String>()
                  : (s['days']?.toString() ?? '')
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
          final start = s['start_time'] ?? '';
          final end = s['end_time'] ?? '';
          final daysStr = daysList.isEmpty ? '' : daysList.join(',');
          return daysStr.isNotEmpty
              ? "$daysStr | ${_shortTime(start)} - ${_shortTime(end)}"
              : "${_shortTime(start)} - ${_shortTime(end)}";
        }).toList();

    // If multiple schedules, join with " / "
    return pieces.join("  /  ");
  }

  String _shortTime(String t) {
    if (t == null || t.isEmpty) return "";
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return "$h:$m";
    }
    return t;
  }

  // Compute status string using the aggregated schedules
  String computeSectionStatus(Map<String, dynamic> assignment) {
    final schedules =
        assignment['schedules'] as List<Map<String, dynamic>>? ?? [];
    if (schedules.isEmpty) return "No Schedule";

    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];

    // Check schedules that include today
    final todaysSchedules =
        schedules.where((s) {
          final days =
              s['days'] is List
                  ? (s['days'] as List).cast<String>()
                  : (s['days']?.toString() ?? '')
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
          return days.contains(todayAbbrev);
        }).toList();

    // If there are no schedules that include today, explicitly return "No Class Today"
    if (todaysSchedules.isEmpty) {
      return "No Class Today";
    }

    // Otherwise consider only today's schedules for status computations
    List<Map<String, dynamic>> checkList = todaysSchedules;

    bool anyActive = false;
    bool anyUpcoming = false;
    bool anyCompleted = false;

    for (final s in checkList) {
      final st = s['start_time'] ?? '';
      final et = s['end_time'] ?? '';
      final startParts = st.split(':');
      final endParts = et.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );
      if (now.isBefore(start))
        anyUpcoming = true;
      else if (now.isAfter(end))
        anyCompleted = true;
      else
        anyActive = true;
    }

    if (anyActive) return "Ongoing";
    if (anyUpcoming) return "Upcoming";
    if (anyCompleted) return "Completed";
    return "No Schedule";
  }

  Future<void> _loadClassList() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    teacherId = user?.id;

    if (teacherId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Fetch all assignments (may contain multiple rows per section)
      final sectionAssignments = await supabase
          .from('section_teachers')
          .select(
            'id, section_id, subject, days, start_time, end_time, assigned_at, sections(id, name, grade_level)',
          )
          .eq('teacher_id', teacherId!);

      final rows = List<Map<String, dynamic>>.from(sectionAssignments ?? []);

      // Aggregate by section_id to avoid duplicate section cards
      final Map<int, Map<String, dynamic>> bySection = {};
      for (final assignment in rows) {
        final section = assignment['sections'] as Map<String, dynamic>?;
        if (section == null) continue;
        final sid = section['id'] as int;
        final subj = assignment['subject']?.toString() ?? '';
        final sched = <String, dynamic>{
          'days': assignment['days'],
          'start_time': assignment['start_time'],
          'end_time': assignment['end_time'],
          'subject': subj,
          'assigned_at': assignment['assigned_at'],
        };

        if (!bySection.containsKey(sid)) {
          bySection[sid] = {
            'sections': section,
            'subjects': <String>{if (subj.isNotEmpty) subj},
            'schedules': <Map<String, dynamic>>[],
            'assigned_rows': [assignment],
          };
        }
        final entry = bySection[sid]!;
        if (subj.isNotEmpty) (entry['subjects'] as Set<String>).add(subj);
        (entry['schedules'] as List).add(sched);
        (entry['assigned_rows'] as List).add(assignment);
      }

      // Convert to list-friendly structure
      assignedSections =
          bySection.values.map((v) {
            final subjSet = v['subjects'] as Set<String>;
            final subjStr = subjSet.isEmpty ? '' : subjSet.join(', ');
            return {
              'sections': v['sections'],
              'subjects': subjStr,
              'schedules': List<Map<String, dynamic>>.from(
                v['schedules'] as List,
              ),
              // keep assigned_rows if you need later
            };
          }).toList();

      // Load students for each section
      sectionStudents.clear();
      for (final assignment in assignedSections) {
        final section = assignment['sections'];
        if (section == null) continue;
        final students = await supabase
            .from('students')
            .select('id, fname, lname, rfid_uid')
            .eq('section_id', section['id']);
        if (students == null) {
          sectionStudents[section['id']] = [];
          continue;
        }
        sectionStudents[section['id']] = List<Map<String, dynamic>>.from(
          students,
        );
      }
    } catch (e) {
      print("Supabase error: $e");
    }

    setState(() => isLoading = false);
  }

  void _openSummary(int sectionId, String sectionName) {
    if (widget.onViewSummary != null) {
      widget.onViewSummary!(sectionId, sectionName);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TeacherSectionAttendanceSummaryPage(
              sectionId: sectionId,
              sectionName: sectionName,
              onViewStudentCalendar: (studentId, studentName) {
                // Drilldown: Open student attendance calendar page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => TeacherStudentAttendanceCalendarPage(
                          studentId: studentId,
                          studentName: studentName,
                          sectionId: sectionId,
                          sectionName: sectionName,
                        ),
                  ),
                );
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                        child: Text(
                          "My Classes",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222B45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            for (final assignment in assignedSections)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18.0),
                                child: _SectionListCard(
                                  title: assignment['sections']['name'],
                                  subject: assignment['subjects'] ?? '',
                                  time: formatSchedule(assignment),
                                  students:
                                      sectionStudents[assignment['sections']['id']]
                                          ?.length ??
                                      0,
                                  gradeLevel:
                                      assignment['sections']['grade_level']
                                          ?.toString() ??
                                      '',
                                  status: computeSectionStatus(assignment),
                                  onViewAttendance: () {
                                    widget.onViewAttendance?.call(
                                      assignment['sections']['id'],
                                      assignment['sections']['name'],
                                    );
                                  },
                                  onViewSummary: () {
                                    _openSummary(
                                      assignment['sections']['id'],
                                      assignment['sections']['name'],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _SectionListCard extends StatelessWidget {
  final String title;
  final String subject;
  final String time;
  final int students;
  final String status;
  final String gradeLevel;
  final VoidCallback onViewAttendance;
  final VoidCallback onViewSummary;
  const _SectionListCard({
    required this.title,
    required this.subject,
    required this.time,
    required this.students,
    required this.gradeLevel,
    required this.status,
    required this.onViewAttendance,
    required this.onViewSummary,
  });

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFF19AE61); // green
      case "ongoing":
        return const Color(0xFF2563EB); // blue
      case "upcoming":
        return const Color(0xFF8F9BB3); // gray
      case "no class today":
        return const Color(0xFFFF8C00); // orange
      case "no schedule":
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color getStatusBgColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFFD9FBE8); // light green
      case "ongoing":
        return const Color(0xFFE8F1FF); // light blue
      case "upcoming":
        return const Color(0xFFF2F3F5); // light gray
      case "no class today":
        return const Color(0xFFFFF3E0); // light orange
      case "no schedule":
        return const Color(0xFFFFEBEE); // light red
      default:
        return const Color(0xFFE8F1FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      width: double.infinity,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Class info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF222B45),
                      ),
                    ),
                    if (subject.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (gradeLevel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F1FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          gradeLevel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8F9BB3),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Total Students: $students",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Status badge and button right-aligned
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: getStatusBgColor(),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    color: getStatusColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: onViewAttendance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 1,
                          shadowColor: Colors.black.withOpacity(0.05),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text("Attendance"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: onViewSummary,
                        icon: const Icon(
                          Icons.bar_chart,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          "Summary",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF2563EB),
                          side: const BorderSide(
                            color: Color(0xFF2563EB),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
