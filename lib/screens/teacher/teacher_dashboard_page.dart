import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'class_list_page.dart';
import '../../services/attendance_monitoring_service.dart';
import '../../services/attendance_ticketing_service.dart';
import '../../widgets/attendance_status_badge.dart';
import '../../widgets/smart_attendance_button.dart';
import '../../widgets/attendance_insights_card.dart';

// Sample avatars for mock/student images
const _avatarImages = [
  "https://randomuser.me/api/portraits/women/1.jpg",
  "https://randomuser.me/api/portraits/men/2.jpg",
  "https://randomuser.me/api/portraits/women/3.jpg",
  "https://randomuser.me/api/portraits/men/4.jpg",
  "https://randomuser.me/api/portraits/women/5.jpg",
];

class TeacherDashboardPage extends StatefulWidget {
  final VoidCallback? onOpenClassList;

  const TeacherDashboardPage({super.key, this.onOpenClassList});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final supabase = Supabase.instance.client;
  final AttendanceMonitoringService _attendanceService = AttendanceMonitoringService();
  final AttendanceTicketingService _ticketingService = AttendanceTicketingService();
  String? teacherId;
  String? teacherName;
  String? profileImageUrl;
  List<Map<String, dynamic>> assignedSections = [];
  Map<int, List<Map<String, dynamic>>> sectionStudents = {};
  Map<int, Map<String, int>> sectionAttendanceStats = {};
  Map<int, Map<int, String>> sectionStudentStatus = {};
  List<Map<String, dynamic>> studentsWithAttendanceIssues = [];
  Map<String, dynamic> attendanceInsights = {};
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
            .select('fname, lname, profile_image_url')
            .eq('id', teacherId!)
            .maybeSingle();

    teacherName =
        teacherData != null
            ? '${teacherData['fname'] ?? ''} ${teacherData['lname'] ?? ''}'
                .trim()
            : user?.email ?? '';

    profileImageUrl = teacherData?['profile_image_url'];

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
      for (final record in scanRecords) {
        final int sid = record['student_id'];
        presentIds.add(sid);
        entryTimes[sid] = DateTime.parse(record['scan_time']);
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

    // Load students with attendance issues using ticketing service
    studentsWithAttendanceIssues = await _ticketingService.getStudentsRequiringAttention(
      teacherId: teacherId!,
    );

    // Load attendance insights
    attendanceInsights = await _attendanceService.getAttendanceInsights(
      teacherId: teacherId!,
    );

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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _SummaryTile(
            label: "Classes Today",
            value: "$totalClassesToday",
            icon: Icons.folder_copy_outlined,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 16),
          _SummaryTile(
            label: "Total Students",
            value: "$totalStudentsToday",
            icon: Icons.people_outline,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 16),
          _SummaryTile(
            label: "Present",
            value: "$totalPresentToday",
            icon: Icons.check_circle_outline,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 16),
          _SummaryTile(
            label: "Absent",
            value: "$totalAbsentToday",
            icon: Icons.cancel_outlined,
            color: Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          if (todayAssignments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
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
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: Color(0xFF8F9BB3).withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No classes scheduled for today",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
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
                          sectionStudents[assignment['sections']['id']]
                              ?.length ??
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Attendance Alerts",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            if (totalAbsentToday > 0)
              Text(
                "$totalAbsentToday student${totalAbsentToday > 1 ? 's' : ''} absent today.",
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            if (lateArrivals.isNotEmpty) ...[
              if (totalAbsentToday > 0) const SizedBox(height: 8),
              Text(
                "${lateArrivals.length} late arrival${lateArrivals.length > 1 ? 's' : ''}:",
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final late in lateArrivals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage(late['avatar']),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${late['name']} (${late['section']})",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "at ${late['time'].hour.toString().padLeft(2, '0')}:${late['time'].minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (totalAbsentToday == 0 && lateArrivals.isEmpty)
              const Text(
                "No alerts. All students are present and on time!",
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceIssues() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Students Requiring Attention",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (studentsWithAttendanceIssues.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "All students have good attendance!",
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < studentsWithAttendanceIssues.length && i < 5; i++)
                    _buildAttendanceIssueItem(studentsWithAttendanceIssues[i]),
                  if (studentsWithAttendanceIssues.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: () {
                          // TODO: Navigate to full attendance issues page
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Full attendance monitoring page coming soon"),
                              backgroundColor: Color(0xFF2563EB),
                            ),
                          );
                        },
                        child: Text(
                          "View ${studentsWithAttendanceIssues.length - 5} more students with attendance issues",
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceIssueItem(Map<String, dynamic> studentData) {
    final student = studentData['student'];
    final section = studentData['section'];
    final consecutiveAbsences = studentData['consecutiveAbsences'] as int;
    final ticketStatus = studentData['ticketStatus'] as Map<String, dynamic>;
    
    final studentName = '${student['fname']} ${student['lname']}';
    final hasTicket = ticketStatus['hasTicket'] as bool;
    final isResolved = ticketStatus['isResolved'] as bool;

    // Determine badges to show based on consecutive absences and ticket status
    List<Widget> badgeWidgets = [];

    if (hasTicket && !isResolved) {
      badgeWidgets.add(const AttendanceStatusBadge(
        type: AttendanceBadgeType.monitoring,
      ));
    } else if (consecutiveAbsences >= 5) {
      badgeWidgets.add(const AttendanceStatusBadge(
        type: AttendanceBadgeType.critical,
      ));
    } else if (consecutiveAbsences >= 4) {
      badgeWidgets.add(const AttendanceStatusBadge(
        type: AttendanceBadgeType.urgent,
      ));
    } else if (consecutiveAbsences >= 3) {
      badgeWidgets.add(const AttendanceStatusBadge(
        type: AttendanceBadgeType.attention,
      ));
    }

    // Determine priority color for container styling
    Color priorityColor;
    if (consecutiveAbsences >= 5) {
      priorityColor = const Color(0xFF8B0000);
    } else if (consecutiveAbsences >= 4) {
      priorityColor = const Color(0xFFDC2626);
    } else if (hasTicket && !isResolved) {
      priorityColor = const Color(0xFF3B82F6);
    } else {
      priorityColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: priorityColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: student['profile_image_url'] != null 
                ? NetworkImage(student['profile_image_url'])
                : null,
            child: student['profile_image_url'] == null
                ? Text(
                    studentName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    ...badgeWidgets.map((badge) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: badge,
                    )),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  section['name'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "$consecutiveAbsences consecutive absences",
                      style: TextStyle(
                        fontSize: 12,
                        color: priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasTicket && !isResolved) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "notification sent",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SmartAttendanceButton(
            studentId: student['id'],
            sectionId: section['id'],
            studentName: '${student['fname']} ${student['lname']}',
            teacherName: teacherName ?? 'Teacher',
            sectionName: section['name'],
            teacherId: teacherId,
            onActionComplete: () => _loadDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllClassesButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              // If parent provided a callback, use it to navigate via the panel nav.
              if (widget.onOpenClassList != null) {
                widget.onOpenClassList!();
                return;
              }
              // Fallback: Navigate to the full class list page directly.
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => TeacherClassListPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 1,
              shadowColor: Colors.black.withOpacity(0.05),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: const Text("View All Classes"),
          ),
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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFDDD6FE),
                              radius: 26,
                              backgroundImage:
                                  profileImageUrl != null &&
                                          profileImageUrl!.isNotEmpty
                                      ? NetworkImage(profileImageUrl!)
                                      : null,
                              child:
                                  profileImageUrl == null ||
                                          profileImageUrl!.isEmpty
                                      ? Text(
                                        (teacherName != null &&
                                                teacherName!.isNotEmpty)
                                            ? teacherName![0].toUpperCase()
                                            : 'T',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Good day, ${teacherName?.split(' ').first ?? 'Teacher'}!",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        getTodayLabel(),
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
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
                      const SizedBox(height: 24),
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      // Add attendance insights card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AttendanceInsightsCard(
                          insights: attendanceInsights,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildScheduleList(),
                      const SizedBox(height: 24),
                      _buildAlerts(),
                      const SizedBox(height: 24),
                      _buildAttendanceIssues(),
                      _buildViewAllClassesButton(),
                      const SizedBox(height: 32),
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
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(24),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
        return const Color(0xFF10B981);
      case "ongoing":
        return const Color(0xFF10B981);
      case "upcoming":
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF10B981);
    }
  }

  Color getStatusBgColor() {
    switch (status.toLowerCase()) {
      case "completed":
        return const Color(0xFFD1FAE5);
      case "ongoing":
        return const Color(0xFFD1FAE5);
      case "upcoming":
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFD1FAE5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (subject.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        subject,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Present: $present / $total",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
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
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: getStatusBgColor(),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    color: getStatusColor(),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onGoToClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
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
                  child: const Text("Go to Class"),
                ),
              ),
            ],
          ),
        ],
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
