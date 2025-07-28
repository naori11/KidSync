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
  Map<int, Map<String, int>> sectionAttendanceStats =
      {}; // sectionId -> {present, attendance}
  Map<int, Map<int, String>> sectionStudentStatus =
      {}; // sectionId -> {studentId: status}
  bool isLoading = true;

  // Pagination state for each section
  Map<int, int> sectionPage = {}; // sectionId -> currentPage (1-based)
  static const int studentsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => isLoading = true);

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

    sectionStudents.clear();
    sectionAttendanceStats.clear();
    sectionStudentStatus.clear();
    sectionPage.clear();

    final nowUtc = DateTime.now().toUtc();
    final todayStart = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      0,
      0,
      0,
    );
    final todayEnd = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      23,
      59,
      59,
    );

    for (final assignment in assignedSections) {
      final section = assignment['sections'];
      if (section == null) continue;

      // Fetch students for this section
      final students = await supabase
          .from('students')
          .select('id, fname, lname, rfid_uid')
          .eq('section_id', section['id']);
      final studentsList = List<Map<String, dynamic>>.from(students);
      sectionStudents[section['id']] = studentsList;
      sectionPage[section['id']] = 1; // start from page 1

      final studentIds = studentsList.map((s) => s['id'] as int).toList();
      if (studentIds.isEmpty) {
        sectionAttendanceStats[section['id']] = {'present': 0, 'attendance': 0};
        sectionStudentStatus[section['id']] = {};
        continue;
      }

      // Fetch all scan_records for today with action='entry'
      final scanRecords = await supabase
          .from('scan_records')
          .select('student_id, scan_time, action')
          .inFilter('student_id', studentIds)
          .eq('action', 'entry')
          .gte('scan_time', todayStart.toIso8601String())
          .lte('scan_time', todayEnd.toIso8601String());

      // Map: studentId -> hasEntryToday
      final Set<int> presentIds = {};
      if (scanRecords is List) {
        for (final record in scanRecords) {
          final int sid = record['student_id'];
          presentIds.add(sid);
        }
      }

      // Attendance stats
      int presentCount = 0;
      Map<int, String> statusMap = {};
      for (final student in studentsList) {
        final int sid = student['id'];
        if (presentIds.contains(sid)) {
          presentCount++;
          statusMap[sid] = "Present";
        } else {
          statusMap[sid] = "Absent";
        }
      }
      int attendancePercent =
          studentsList.isEmpty
              ? 0
              : ((presentCount / studentsList.length) * 100).round();

      sectionAttendanceStats[section['id']] = {
        'present': presentCount,
        'attendance': attendancePercent,
      };
      sectionStudentStatus[section['id']] = statusMap;
    }

    setState(() => isLoading = false);
  }

  void _setSectionPage(int sectionId, int page) {
    setState(() {
      sectionPage[sectionId] = page;
    });
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
                              itemCount:
                                  assignedSections.length > 3
                                      ? 3
                                      : assignedSections.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 16),
                              itemBuilder: (context, idx) {
                                final assignment = assignedSections[idx];
                                final sectionId = assignment['sections']['id'];
                                final attendanceStats =
                                    sectionAttendanceStats[sectionId] ??
                                    {'present': 0, 'attendance': 0};
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
                                        sectionStudents[sectionId]?.length ?? 0,
                                    present: attendanceStats['present'] ?? 0,
                                    attendance:
                                        attendanceStats['attendance'] ?? 0,
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
                                                        in sectionStudents[sectionId] ??
                                                            [])
                                                      _StudentRowData(
                                                        "${student['fname']} ${student['lname']}",
                                                        "https://randomuser.me/api/portraits/lego/1.jpg",
                                                        sectionStudentStatus[sectionId]?[student['id']] ??
                                                            "Absent",
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
                            _ClassStudentListPaginated(
                              classTitle:
                                  assignedSections[0]['sections']['name'],
                              students: [
                                for (final student
                                    in sectionStudents[assignedSections[0]['sections']['id']] ??
                                        [])
                                  _StudentRowData(
                                    "${student['fname']} ${student['lname']}",
                                    "https://randomuser.me/api/portraits/lego/1.jpg",
                                    sectionStudentStatus[assignedSections[0]['sections']['id']]?[student['id']] ??
                                        "Absent",
                                  ),
                              ],
                              currentPage:
                                  sectionPage[assignedSections[0]['sections']['id']] ??
                                  1,
                              onPageChanged:
                                  (page) => _setSectionPage(
                                    assignedSections[0]['sections']['id'],
                                    page,
                                  ),
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

// Class Card (unchanged aside from actual values passed in)
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Attendance $attendance%",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
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

// Paginated student list widget
class _ClassStudentListPaginated extends StatefulWidget {
  final String classTitle;
  final List<_StudentRowData> students;
  final int currentPage;
  final void Function(int page) onPageChanged;

  const _ClassStudentListPaginated({
    required this.classTitle,
    required this.students,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  State<_ClassStudentListPaginated> createState() =>
      _ClassStudentListPaginatedState();
}

class _ClassStudentListPaginatedState
    extends State<_ClassStudentListPaginated> {
  static const int studentsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    int totalEntries = widget.students.length;
    int totalPages = (totalEntries / studentsPerPage).ceil();
    int page = widget.currentPage.clamp(1, totalPages == 0 ? 1 : totalPages);

    int start = (page - 1) * studentsPerPage;
    int end = (start + studentsPerPage).clamp(0, totalEntries);

    List<_StudentRowData> pageStudents = widget.students.sublist(start, end);

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
                widget.classTitle,
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
              itemCount: pageStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, idx) {
                final s = pageStudents[idx];
                final isPresent = s.status == "Present";
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
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isPresent
                                      ? const Color(0xFF2ECC71)
                                      : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPresent ? "Present" : "Absent",
                            style: TextStyle(
                              color:
                                  isPresent
                                      ? const Color(0xFF2ECC71)
                                      : Colors.red,
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
                    "Showing ${totalEntries == 0 ? 0 : (start + 1)} to $end of $totalEntries entries",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        page > 1 ? () => widget.onPageChanged(page - 1) : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  for (int p = 1; p <= totalPages; p++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            page == p
                                ? const Color(0xFF2ECC71)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: GestureDetector(
                        onTap: () => widget.onPageChanged(p),
                        child: Text(
                          "$p",
                          style: TextStyle(
                            color: page == p ? Colors.white : Colors.black87,
                            fontWeight:
                                page == p ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed:
                        page < totalPages
                            ? () => widget.onPageChanged(page + 1)
                            : null,
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

// For backwards compatibility
class _StudentRowData {
  final String name;
  final String avatarUrl;
  final String status;
  _StudentRowData(this.name, this.avatarUrl, this.status);
}

// The original _ClassStudentList (for dialog) remains unchanged, using the same logic for status color as in the paginated list.
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
                final isPresent = s.status == "Present";
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
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isPresent
                                      ? const Color(0xFF2ECC71)
                                      : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPresent ? "Present" : "Absent",
                            style: TextStyle(
                              color:
                                  isPresent
                                      ? const Color(0xFF2ECC71)
                                      : Colors.red,
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
            // Pagination (optional for dialog list, not implemented here)
          ],
        ),
      ),
    );
  }
}
