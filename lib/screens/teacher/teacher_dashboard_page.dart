import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final supabase = Supabase.instance.client;
  String? teacherId;
  List<Map<String, dynamic>> assignedSections = [];
  Map<int, List<Map<String, dynamic>>> sectionStudents = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => isLoading = true);

    // Get current teacher's id
    final user = supabase.auth.currentUser;
    teacherId = user?.id;

    if (teacherId == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch assigned sections for this teacher
    final sectionAssignments = await supabase
        .from('section_teachers')
        .select(
          'id, section_id, subject, assigned_at, sections(id, name, grade_level, schedule)',
        )
        .eq('teacher_id', teacherId!);

    assignedSections = List<Map<String, dynamic>>.from(sectionAssignments);

    // For each section, fetch students
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
                          // Header Row
                          Row(
                            children: [
                              const Text(
                                "Today's Classes",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                height: 40,
                                width: 260,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText: 'Search students...',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Top class cards (dynamically, max 3 visible, horizontally scrollable)
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: assignedSections.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, idx) {
                                final assignment = assignedSections[idx];
                                return SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width / 3 -
                                      40, // Fits 3 cards
                                  child: _ClassCard(
                                    title: assignment['sections']['name'],
                                    time:
                                        assignment['sections']['schedule'] ??
                                        "--",
                                    status:
                                        "Ongoing", // You can make this dynamic later
                                    statusColor: const Color(0xFF2ECC71),
                                    students:
                                        sectionStudents[assignment['sections']['id']]
                                            ?.length ??
                                        0,
                                    present:
                                        0, // Add attendance logic if available
                                    attendance:
                                        0, // Add attendance logic if available
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: Text(
                                                "Students for ${assignment['sections']['name']}",
                                              ),
                                              content: SizedBox(
                                                width: 400,
                                                child: _ClassStudentList(
                                                  classTitle:
                                                      assignment['sections']['name'],
                                                  students: [
                                                    for (final student
                                                        in sectionStudents[assignment['sections']['id']] ??
                                                            [])
                                                      _StudentRowData(
                                                        "${student['fname']} ${student['lname']}",
                                                        "https://randomuser.me/api/portraits/lego/1.jpg",
                                                        "Unknown", // Add attendance status if available
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Student list for first section/class (as example)
                          if (assignedSections.isNotEmpty)
                            _ClassStudentList(
                              classTitle:
                                  assignedSections[0]['sections']['name'],
                              students: [
                                for (final student
                                    in sectionStudents[assignedSections[0]['sections']['id']] ??
                                        [])
                                  _StudentRowData(
                                    "${student['fname']} ${student['lname']}",
                                    "https://randomuser.me/api/portraits/lego/1.jpg",
                                    "Unknown",
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

// Do NOT wrap in Expanded when using inside a horizontally scrolling ListView
class _ClassCard extends StatelessWidget {
  final String title;
  final String time;
  final String status;
  final Color statusColor;
  final int students;
  final int present;
  final int attendance;
  final VoidCallback onPressed;
  const _ClassCard({
    required this.title,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.students,
    required this.present,
    required this.attendance,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(time, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Spacer(),
          Row(
            children: [
              Text(
                "Total Students $students",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Text(
                "Present $present",
                style: TextStyle(fontSize: 13, color: Colors.blue[700]),
              ),
              const SizedBox(width: 10),
              Text(
                "Attendance $attendance%",
                style: TextStyle(fontSize: 13, color: Colors.green[700]),
              ),
              const Spacer(),
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
        ],
      ),
    );
  }
}

class _ClassStudentList extends StatelessWidget {
  final String classTitle;
  final List<_StudentRowData> students;
  const _ClassStudentList({required this.classTitle, required this.students});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                classTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // List of students
            ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, idx) {
                final s = students[idx];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(s.avatarUrl),
                  ),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.status == "Present")
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2ECC71),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              "Present",
                              style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              "Absent",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
            // Pagination
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
              child: Row(
                children: [
                  Text(
                    "Showing 1 to 5 of 50 entries",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "1",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: const Text(
                      "2",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: const Text(
                      "3",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRowData {
  final String name;
  final String avatarUrl;
  final String status;
  _StudentRowData(this.name, this.avatarUrl, this.status);
}
