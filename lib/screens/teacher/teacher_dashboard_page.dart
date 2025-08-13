import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sample avatars for mock/student images
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
  String? teacherName;
  List<Map<String, dynamic>> assignedSections = [];
  Map<int, List<Map<String, dynamic>>> sectionStudents = {};
  Map<int, Map<String, int>> sectionAttendanceStats = {};
  Map<int, Map<int, String>> sectionStudentStatus = {};
  bool isLoading = true;

  int totalClassesToday = 0;
  int totalStudentsToday = 0;
  int totalPresentToday = 0;
  int totalAbsentToday = 0;
  List<Map<String, dynamic>> lateArrivals = [];
  List<Map<String, dynamic>> todayAssignments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

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

  Future<void> _loadDashboard() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    teacherId = user?.id;
    // Fetch teacher's first and last name from the users table
    final teacherData =
        await supabase
            .from('users')
            .select('fname, lname')
            .eq('id', teacherId!)
            .maybeSingle();

    teacherName =
        teacherData != null
            ? '${teacherData['fname'] ?? ''} ${teacherData['lname'] ?? ''}'
                .trim()
            : user?.email ?? '';

    if (teacherId == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch section assignments for this teacher
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

    // Date filters for today
    final now = DateTime.now();
    final nowUtc = now.toUtc();
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
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];

    // TEMP: Show all assigned sections, regardless of day
    // todayAssignments = List<Map<String, dynamic>>.from(assignedSections);

    // Filter only today's assignments
    todayAssignments =
        assignedSections.where((asgmt) {
          final days =
              asgmt['days'] is List
                  ? (asgmt['days'] as List).cast<String>()
                  : (asgmt['days']?.toString() ?? '')
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
          return days.contains(todayAbbrev);
        }).toList();

    int totalStudents = 0, totalPresent = 0;
    List<Map<String, dynamic>> allLateArrivals = [];

    for (final assignment in todayAssignments) {
      final section = assignment['sections'];
      if (section == null) continue;

      final students = await supabase
          .from('students')
          .select('id, fname, lname, rfid_uid')
          .eq('section_id', section['id']);
      final studentsList = List<Map<String, dynamic>>.from(students);
      sectionStudents[section['id']] = studentsList;

      final studentIds = studentsList.map((s) => s['id'] as int).toList();
      if (studentIds.isEmpty) {
        sectionAttendanceStats[section['id']] = {'present': 0, 'attendance': 0};
        sectionStudentStatus[section['id']] = {};
        continue;
      }

      // Attendance records for today
      final scanRecords = await supabase
          .from('scan_records')
          .select('student_id, scan_time, action')
          .inFilter('student_id', studentIds)
          .eq('action', 'entry')
          .gte('scan_time', todayStart.toIso8601String())
          .lte('scan_time', todayEnd.toIso8601String());

      final Set<int> presentIds = {};
      Map<int, DateTime> entryTimes = {};
      if (scanRecords is List) {
        for (final record in scanRecords) {
          final int sid = record['student_id'];
          presentIds.add(sid);
          entryTimes[sid] = DateTime.parse(record['scan_time']);
        }
      }

      int presentCount = 0;
      Map<int, String> statusMap = {};
      List<Map<String, dynamic>> lateThisSection = [];
      // Parse class start time
      final startTimeStr = assignment['start_time'] ?? '';
      DateTime? classStartTime;
      if (startTimeStr.contains(':')) {
        final st = startTimeStr.split(':');
        classStartTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(st[0]),
          int.parse(st[1]),
        );
      }
      for (final student in studentsList) {
        final int sid = student['id'];
        if (presentIds.contains(sid)) {
          presentCount++;
          statusMap[sid] = "Present";
          // Determine late arrivals (entryTime > classStartTime + 5min)
          if (classStartTime != null &&
              entryTimes[sid] != null &&
              entryTimes[sid]!.isAfter(
                classStartTime.add(const Duration(minutes: 5)),
              )) {
            lateThisSection.add({
              'name': '${student['fname']} ${student['lname']}',
              'avatar': _avatarImages[student['id'] % _avatarImages.length],
              'section': section['name'],
              'time': entryTimes[sid]!,
            });
          }
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
      totalStudents += studentsList.length;
      totalPresent += presentCount;
      allLateArrivals.addAll(lateThisSection);
    }
    totalClassesToday = todayAssignments.length;
    totalStudentsToday = totalStudents;
    totalPresentToday = totalPresent;
    totalAbsentToday = totalStudentsToday - totalPresentToday;
    lateArrivals = allLateArrivals;

    setState(() => isLoading = false);
  }

  String getTodayLabel() {
    final now = DateTime.now();
    final date =
        "${["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][now.weekday - 1]}, "
        "${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.month - 1]} ${now.day}";
    return date;
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _SummaryTile(
            label: "Classes Today",
            value: "$totalClassesToday",
            icon: Icons.class_,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 18),
          _SummaryTile(
            label: "Total Students",
            value: "$totalStudentsToday",
            icon: Icons.people,
            color: Color(0xFF19AE61),
          ),
          const SizedBox(width: 18),
          _SummaryTile(
            label: "Present",
            value: "$totalPresentToday",
            icon: Icons.check_circle,
            color: Color(0xFF19AE61),
          ),
          const SizedBox(width: 18),
          _SummaryTile(
            label: "Absent",
            value: "$totalAbsentToday",
            icon: Icons.cancel,
            color: Color(0xFFEB5757),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final assignment in todayAssignments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ScheduleListTile(
                    className: assignment['sections']['name'],
                    subject: assignment['subject'] ?? '',
                    time: formatSchedule(assignment),
                    status: computeSectionStatus(assignment),
                    present:
                        sectionAttendanceStats[assignment['sections']['id']]?['present'] ??
                        0,
                    total:
                        sectionStudents[assignment['sections']['id']]?.length ??
                        0,
                    onGoToClass: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              contentPadding: const EdgeInsets.all(0),
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              content: SizedBox(
                                width: 540,
                                child: _ClassStudentListModal(
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
                                ),
                              ),
                            ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Attendance Alerts",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF222B45),
                ),
              ),
              const SizedBox(height: 10),
              if (totalAbsentToday > 0)
                Text(
                  "$totalAbsentToday student${totalAbsentToday > 1 ? 's' : ''} absent today.",
                  style: const TextStyle(
                    color: Color(0xFFEB5757),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              if (lateArrivals.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "${lateArrivals.length} late arrival${lateArrivals.length > 1 ? 's' : ''}:",
                  style: const TextStyle(
                    color: Color(0xFFEB5757),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final late in lateArrivals)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage(late['avatar']),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            "${late['name']} (${late['section']})",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF222B45),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "at ${late['time'].hour.toString().padLeft(2, '0')}:${late['time'].minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              if (totalAbsentToday == 0 && lateArrivals.isEmpty)
                const Text(
                  "No alerts. All students are present and on time!",
                  style: TextStyle(
                    color: Color(0xFF19AE61),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllClassesButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () {
            // Navigate to the full class list page (implement navigation as needed)
            Navigator.of(context).pushNamed('/teacher_classes');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFF2563EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          icon: const Icon(Icons.list_alt, size: 19),
          label: const Text("View All Classes"),
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
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              radius: 23,
                              child: Text(
                                (teacherName != null && teacherName!.isNotEmpty)
                                    ? teacherName![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Good day, ${teacherName ?? ''}!",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        getTodayLabel(),
                                        style: const TextStyle(
                                          color: Color(0xFF8F9BB3),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
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
                      const SizedBox(height: 22),
                      _buildSummaryCards(),
                      const SizedBox(height: 28),
                      _buildScheduleList(),
                      const SizedBox(height: 24),
                      _buildAlerts(),
                      _buildViewAllClassesButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 29, color: color),
              const SizedBox(height: 7),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8F9BB3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleListTile extends StatelessWidget {
  final String className;
  final String subject;
  final String time;
  final String status;
  final int present;
  final int total;
  final VoidCallback onGoToClass;

  const _ScheduleListTile({
    required this.className,
    required this.subject,
    required this.time,
    required this.status,
    required this.present,
    required this.total,
    required this.onGoToClass,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Class Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        className,
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
                    "Present: $present / $total",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge and button in a Row, right side
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
                    onPressed: onGoToClass,
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
                    child: const Text("Go to Class"),
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

class _StudentRowData {
  final String name;
  final String avatarUrl;
  final String status;
  _StudentRowData(this.name, this.avatarUrl, this.status);
}
