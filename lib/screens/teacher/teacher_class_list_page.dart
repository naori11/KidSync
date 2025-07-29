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

  Future<void> _loadClassList() async {
  setState(() => isLoading = true);

  final user = supabase.auth.currentUser;
  teacherId = user?.id;

  if (teacherId == null) {
    setState(() => isLoading = false);
    // Optionally show a message to the user here
    return;
  }

  try {
    final sectionAssignments = await supabase
        .from('section_teachers')
        .select(
          'id, section_id, subject, assigned_at, sections(id, name, schedule)' // use only existing columns!
        )
        .eq('teacher_id', teacherId!);

    assignedSections = List<Map<String, dynamic>>.from(sectionAssignments ?? []);

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
      sectionStudents[section['id']] = List<Map<String, dynamic>>.from(students);
    }
  } catch (e) {
    print("Supabase error: $e");
    // Optionally show error message to user
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
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
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
                                child: _ClassListCard(
                                  title: assignment['sections']['name'],
                                  time:
                                      assignment['sections']['schedule'] ??
                                      "--",
                                  students:
                                      sectionStudents[assignment['sections']['id']]
                                          ?.length ??
                                      0,
                                  // Example: status could be "Ongoing", "Upcoming", etc. Use your own logic if needed.
                                  status:
                                      assignment['sections']['status'] ??
                                      "Ongoing",
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

class _ClassListCard extends StatelessWidget {
  final String title;
  final String time;
  final int students;
  final String status;
  final VoidCallback onPressed;
  const _ClassListCard({
    required this.title,
    required this.time,
    required this.students,
    required this.status,
    required this.onPressed,
  });

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case "ongoing":
        return const Color(0xFF19AE61); // green
      case "upcoming":
        return const Color(0xFFFFA726); // orange
      case "completed":
        return const Color(0xFF2E3A59); // muted/gray
      default:
        return const Color(0xFF19AE61);
    }
  }

  Color getStatusBgColor() {
    switch (status.toLowerCase()) {
      case "ongoing":
        return const Color(0xFFD9FBE8); // light green
      case "upcoming":
        return const Color(0xFFFFF3E0); // light orange
      case "completed":
        return const Color(0xFFE4E9F2);
      default:
        return const Color(0xFFD9FBE8);
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    "Total Students: $students",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                ],
              ),
            ),
            // Status
            Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              decoration: BoxDecoration(
                color: getStatusBgColor(),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: getStatusColor(),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            // View Details
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
      ),
    );
  }
}
