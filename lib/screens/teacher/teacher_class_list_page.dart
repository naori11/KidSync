import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherClassListPage extends StatefulWidget {
  final void Function(int sectionId, String sectionName)? onViewAttendance;
  const TeacherClassListPage({super.key, this.onViewAttendance});

  @override
  State<TeacherClassListPage> createState() => _TeacherClassListPageState();
}

class _TeacherClassListPageState extends State<TeacherClassListPage> {
  final supabase = Supabase.instance.client;
  String? teacherId;
  List<Map<String, dynamic>> assignedSections = [];
  Map<int, List<Map<String, dynamic>>> sectionStudents = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassList();
  }

  // Utility to format schedule
  String formatSchedule(Map<String, dynamic> assignment) {
    final days =
        assignment['days'] is List
            ? (assignment['days'] as List).join(', ')
            : (assignment['days']?.toString() ?? '');
    final startTime = assignment['start_time'] ?? '';
    final endTime = assignment['end_time'] ?? '';
    if (days.isEmpty || startTime.isEmpty || endTime.isEmpty) {
      return "--";
    }
    return "$days | $startTime - $endTime";
  }

  // Compute status string: Upcoming, Ongoing, Completed
  String computeSectionStatus(Map<String, dynamic> assignment) {
    final days =
        assignment['days'] is List
            ? (assignment['days'] as List).cast<String>()
            : (assignment['days']?.toString() ?? '')
                .split(',')
                .map((e) => e.trim())
                .toList();
    final startTimeStr = assignment['start_time'] ?? '';
    final endTimeStr = assignment['end_time'] ?? '';
    if (days.isEmpty || startTimeStr.isEmpty || endTimeStr.isEmpty)
      return "Upcoming";

    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];

    if (!days.contains(todayAbbrev)) return "Upcoming";

    final startTimeParts = startTimeStr.split(':');
    final endTimeParts = endTimeStr.split(':');
    if (startTimeParts.length < 2 || endTimeParts.length < 2) return "Upcoming";

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(startTimeParts[0]),
      int.parse(startTimeParts[1]),
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(endTimeParts[0]),
      int.parse(endTimeParts[1]),
    );

    if (now.isBefore(start)) return "Upcoming";
    if (now.isAfter(end)) return "Completed";
    return "Ongoing";
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
      // Fetch schedule fields from section_teachers
      final sectionAssignments = await supabase
          .from('section_teachers')
          .select(
            'id, section_id, subject, days, start_time, end_time, assigned_at, sections(id, name, grade_level)',
          )
          .eq('teacher_id', teacherId!);

      assignedSections = List<Map<String, dynamic>>.from(
        sectionAssignments ?? [],
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF7F9FCFF),
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
                                  subject: assignment['subject'] ?? '',
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
                                  onPressed: () {
                                    widget.onViewAttendance?.call(
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
  final VoidCallback onPressed;
  const _SectionListCard({
    required this.title,
    required this.subject,
    required this.time,
    required this.students,
    required this.gradeLevel,
    required this.status,
    required this.onPressed,
  });

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFF19AE61); // green
      case "ongoing":
        return const Color(0xFF2563EB); // blue
      case "upcoming":
        return const Color(0xFF8F9BB3); // gray
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
      default:
        return const Color(0xFFE8F1FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        width: double.infinity,
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
                        Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
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
                            "Grade $gradeLevel",
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
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 0,
                      ),
                    ),
                    child: const Text("View Details"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
