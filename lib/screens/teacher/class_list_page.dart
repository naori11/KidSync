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
    final daysList = assignment['days'] is List
        ? (assignment['days'] as List).cast<String>()
        : (assignment['days']?.toString() ?? '')
            .split(',')
            .map((e) => e.trim())
            .toList();
    final startTime = assignment['start_time'] ?? '';
    final endTime = assignment['end_time'] ?? '';
    
    if (daysList.isEmpty || startTime.isEmpty || endTime.isEmpty) {
      return "--";
    }
    
    final formattedDays = _formatDaysRange(daysList);
    return "$formattedDays | $startTime - $endTime";
  }

  // Helper method to format days in a compact range format
  String _formatDaysRange(List<String> days) {
    if (days.isEmpty) return '';
    
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayIndices = days
        .map((day) => weekDays.indexOf(day))
        .where((index) => index != -1)
        .toList()
      ..sort();
    
    if (dayIndices.isEmpty) return days.join(', ');
    
    List<String> ranges = [];
    int start = dayIndices[0];
    int end = start;
    
    for (int i = 1; i < dayIndices.length; i++) {
      if (dayIndices[i] == end + 1) {
        end = dayIndices[i];
      } else {
        if (start == end) {
          ranges.add(weekDays[start]);
        } else if (end == start + 1) {
          ranges.add('${weekDays[start]}, ${weekDays[end]}');
        } else {
          ranges.add('${weekDays[start]}-${weekDays[end]}');
        }
        start = dayIndices[i];
        end = start;
      }
    }
    
    // Add the last range
    if (start == end) {
      ranges.add(weekDays[start]);
    } else if (end == start + 1) {
      ranges.add('${weekDays[start]}, ${weekDays[end]}');
    } else {
      ranges.add('${weekDays[start]}-${weekDays[end]}');
    }
    
    return ranges.join(', ');
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
      return "No Schedule";

    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];

    // If today is not a class day, return "No Class Today" instead of "Upcoming"
    if (!days.contains(todayAbbrev)) return "No Class Today";

    final startTimeParts = startTimeStr.split(':');
    final endTimeParts = endTimeStr.split(':');
    if (startTimeParts.length < 2 || endTimeParts.length < 2) return "No Schedule";

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
                      ElevatedButton(
                        onPressed: onViewAttendance,
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
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                        child: const Text("Attendance"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onViewSummary,
                        icon: const Icon(
                          Icons.bar_chart,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          "Summary",
                          style: TextStyle(color: Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF2563EB),
                          side: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 0,
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
      ),
    );
  }
}
