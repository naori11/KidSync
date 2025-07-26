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
      return;
    }

    final sectionAssignments = await supabase
        .from('section_teachers')
        .select(
          'id, section_id, subject, assigned_at, sections(id, name, grade_level, schedule)',
        )
        .eq('teacher_id', teacherId!);

    assignedSections = List<Map<String, dynamic>>.from(sectionAssignments);

    sectionStudents.clear();
    for (final assignment in assignedSections) {
      final section = assignment['sections'];
      if (section == null) continue;
      final students = await supabase
          .from('students')
          .select('id, fname, lname, rfid_uid')
          .eq('section_id', section['id']);
      sectionStudents[section['id']] = List<Map<String, dynamic>>.from(
        students,
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
              )
              : Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "My Classes",
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Column(
                            children: [
                              for (final assignment in assignedSections)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _ClassListCard(
                                    title: assignment['sections']['name'],
                                    time:
                                        assignment['sections']['schedule'] ??
                                        "--",
                                    students:
                                        sectionStudents[assignment['sections']['id']]
                                            ?.length ??
                                        0,
                                    status: "Ongoing",
                                    statusColor: const Color(0xFF2ECC71),
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ClassListCard extends StatelessWidget {
  final String title;
  final String time;
  final int students;
  final String status;
  final Color statusColor;
  final VoidCallback onPressed;
  const _ClassListCard({
    required this.title,
    required this.time,
    required this.students,
    required this.status,
    required this.statusColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Total Students: $students",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "View Details",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
