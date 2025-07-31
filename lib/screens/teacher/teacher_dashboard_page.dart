import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sample avatars if you want to mock or add real photos.
const _avatarImages = [
  "https://randomuser.me/api/portraits/women/1.jpg",
  "https://randomuser.me/api/portraits/men/2.jpg",
  "https://randomuser.me/api/portraits/women/3.jpg",
  "https://randomuser.me/api/portraits/men/4.jpg",
  "https://randomuser.me/api/portraits/women/5.jpg",
];

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
  Map<int, Map<String, int>> sectionAttendanceStats = {};
  Map<int, Map<int, String>> sectionStudentStatus = {};
  bool isLoading = true;

  // Pagination state for each section
  Map<int, int> sectionPage = {}; // sectionId -> currentPage (1-based)
  static const int studentsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // Utility to nicely format schedule for a section-teacher assignment
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

    // Get today's day abbreviation, e.g., "Mon"
    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];

    if (!days.contains(todayAbbrev)) return "Upcoming";

    // Parse time strings as today
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

  Future<void> _loadDashboard() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    teacherId = user?.id;

    if (teacherId == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch schedule fields from section_teachers
    final sectionAssignments = await supabase
        .from('section_teachers')
        .select(
          'id, section_id, subject, days, start_time, end_time, assigned_at, sections(id, name, grade_level)',
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

      final students = await supabase
          .from('students')
          .select('id, fname, lname, rfid_uid')
          .eq('section_id', section['id']);
      final studentsList = List<Map<String, dynamic>>.from(students);
      sectionStudents[section['id']] = studentsList;
      sectionPage[section['id']] = 1;

      final studentIds = studentsList.map((s) => s['id'] as int).toList();
      if (studentIds.isEmpty) {
        sectionAttendanceStats[section['id']] = {'present': 0, 'attendance': 0};
        sectionStudentStatus[section['id']] = {};
        continue;
      }

      final scanRecords = await supabase
          .from('scan_records')
          .select('student_id, scan_time, action')
          .inFilter('student_id', studentIds)
          .eq('action', 'entry')
          .gte('scan_time', todayStart.toIso8601String())
          .lte('scan_time', todayEnd.toIso8601String());

      final Set<int> presentIds = {};
      if (scanRecords is List) {
        for (final record in scanRecords) {
          final int sid = record['student_id'];
          presentIds.add(sid);
        }
      }

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

  String getTodayLabel() {
    final now = DateTime.now();
    final date =
        "${["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][now.weekday - 1]}, "
        "${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.month - 1]} ${now.day}";
    return date;
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
                        child: Row(
                          children: [
                            Text(
                              "Today's Classes",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222B45),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Icon(
                              Icons.calendar_today,
                              size: 19,
                              color: Color(0xFF8F9BB3),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              getTodayLabel(),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF8F9BB3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Search students...",
                                  hintStyle: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8F9BB3),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF8F9BB3),
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE4E9F2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE4E9F2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Classes Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Row(
                          children: [
                            for (final assignment in assignedSections)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: _ClassCard(
                                    title: assignment['sections']['name'],
                                    // Use formatted schedule string
                                    time: formatSchedule(assignment),
                                    status: computeSectionStatus(assignment),
                                    students:
                                        sectionStudents[assignment['sections']['id']]
                                            ?.length ??
                                        0,
                                    present:
                                        sectionAttendanceStats[assignment['sections']['id']]?['present'] ??
                                        0,
                                    attendance:
                                        sectionAttendanceStats[assignment['sections']['id']]?['attendance'] ??
                                        0,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              contentPadding:
                                                  const EdgeInsets.all(0),
                                              backgroundColor:
                                                  Colors.transparent,
                                              elevation: 0,
                                              content: SizedBox(
                                                width: 540,
                                                child: _ClassStudentListModal(
                                                  classTitle:
                                                      assignment['sections']['name'],
                                                  schedule: formatSchedule(
                                                    assignment,
                                                  ),
                                                  subject:
                                                      assignment['subject'] ??
                                                      '',
                                                  students: [
                                                    for (final student
                                                        in sectionStudents[assignment['sections']['id']] ??
                                                            [])
                                                      _StudentRowData(
                                                        "${student['fname']} ${student['lname']}",
                                                        _avatarImages[student['id'] %
                                                            _avatarImages
                                                                .length],
                                                        sectionStudentStatus[assignment['sections']['id']]?[student['id']] ??
                                                            "Absent",
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Class student lists (paged)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            for (final assignment in assignedSections)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 22.0),
                                child: _ClassStudentListPaginated(
                                  classTitle: assignment['sections']['name'],
                                  schedule: formatSchedule(assignment),
                                  subject: assignment['subject'] ?? '',
                                  students: [
                                    for (final student
                                        in sectionStudents[assignment['sections']['id']] ??
                                            [])
                                      _StudentRowData(
                                        "${student['fname']} ${student['lname']}",
                                        _avatarImages[student['id'] %
                                            _avatarImages.length],
                                        sectionStudentStatus[assignment['sections']['id']]?[student['id']] ??
                                            "Absent",
                                      ),
                                  ],
                                  currentPage:
                                      sectionPage[assignment['sections']['id']] ??
                                      1,
                                  onPageChanged:
                                      (page) => _setSectionPage(
                                        assignment['sections']['id'],
                                        page,
                                      ),
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

class _ClassCard extends StatelessWidget {
  final String title;
  final String time;
  final String status;
  final int students;
  final int present;
  final int attendance;
  final VoidCallback onPressed;
  const _ClassCard({
    required this.title,
    required this.time,
    required this.status,
    required this.students,
    required this.present,
    required this.attendance,
    required this.onPressed,
  });

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFF19AE61);
      case "ongoing":
        return const Color(0xFF2563EB);
      case "upcoming":
        return const Color(0xFF8F9BB3); 
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color getStatusBgColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFFD9FBE8);
      case "ongoing":
        return const Color(0xFFE8F1FF);
      case "upcoming":
        return const Color(0xFFF2F3F5);
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status
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
                const Spacer(),
                Container(
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
              ],
            ),
            const SizedBox(height: 7),
            Text(
              time,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8F9BB3)),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  "Total Students $students",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Present $present",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF19AE61),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Attendance $attendance%",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
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

// For dialog "View Details" modal
class _ClassStudentListModal extends StatelessWidget {
  final String classTitle;
  final String schedule;
  final String subject;
  final List<_StudentRowData> students;
  const _ClassStudentListModal({
    required this.classTitle,
    required this.schedule,
    required this.subject,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(0),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
              child: Text(
                classTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
              child: Row(
                children: [
                  if (subject.isNotEmpty)
                    Text(
                      subject,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  if (subject.isNotEmpty) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      schedule,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8F9BB3),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 2, 32, 0),
              child: Text(
                "Current Class Students",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 32),
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              isPresent
                                  ? const Color(0xFF19AE61)
                                  : const Color(0xFFEB5757),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPresent ? "Present" : "Absent",
                        style: TextStyle(
                          color:
                              isPresent
                                  ? const Color(0xFF19AE61)
                                  : const Color(0xFFEB5757),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Paginated student list widget
class _ClassStudentListPaginated extends StatefulWidget {
  final String classTitle;
  final String schedule;
  final String subject;
  final List<_StudentRowData> students;
  final int currentPage;
  final void Function(int page) onPageChanged;

  const _ClassStudentListPaginated({
    required this.classTitle,
    required this.schedule,
    required this.subject,
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
  static const int studentsPerPage = 5;

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
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 18, left: 32, right: 32, bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with schedule
            Row(
              children: [
                Text(
                  widget.classTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.subject.isNotEmpty)
                  Text(
                    widget.subject,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                if (widget.subject.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.schedule,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8F9BB3),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              "Current Class Students",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8F9BB3),
              ),
            ),
            const SizedBox(height: 5),
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              isPresent
                                  ? const Color(0xFF19AE61)
                                  : const Color(0xFFEB5757),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isPresent ? "Present" : "Absent",
                        style: TextStyle(
                          color:
                              isPresent
                                  ? const Color(0xFF19AE61)
                                  : const Color(0xFFEB5757),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Pagination
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    "Showing ${totalEntries == 0 ? 0 : (start + 1)} to $end of $totalEntries entries",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8F9BB3),
                    ),
                  ),
                  const Spacer(),
                  _ClassStudentListPagination(
                    totalPages: totalPages,
                    currentPage: page,
                    onPageChanged: widget.onPageChanged,
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

class _ClassStudentListPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final void Function(int) onPageChanged;
  const _ClassStudentListPagination({
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox();
    List<Widget> pages = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= currentPage - 1 && i <= currentPage + 1)) {
        pages.add(
          GestureDetector(
            onTap: () => onPageChanged(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    currentPage == i
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color:
                      currentPage == i
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFE4E9F2),
                ),
              ),
              child: Text(
                "$i",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      currentPage == i ? Colors.white : const Color(0xFF222B45),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        pages.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text("...", style: TextStyle(color: Color(0xFF8F9BB3))),
          ),
        );
      }
    }
    return Row(
      children: [
        TextButton(
          onPressed:
              currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            foregroundColor: const Color(0xFF2563EB),
            textStyle: const TextStyle(fontSize: 14),
          ),
          child: const Text("Previous"),
        ),
        ...pages,
        TextButton(
          onPressed:
              currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            foregroundColor: const Color(0xFF2563EB),
            textStyle: const TextStyle(fontSize: 14),
          ),
          child: const Text("Next"),
        ),
      ],
    );
  }
}

class _StudentRowData {
  final String name;
  final String avatarUrl;
  final String status;
  _StudentRowData(this.name, this.avatarUrl, this.status);
}
