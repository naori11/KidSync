import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'class_list_page.dart';
import 'attendance_taking_page.dart';
import '../../services/attendance_monitoring_service.dart';
import '../../services/attendance_ticketing_service.dart';
import '../../widgets/attendance_status_badge.dart';
import '../../widgets/smart_attendance_button.dart';

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
  final Function(int sectionId, String sectionName)? onOpenAttendance;

  const TeacherDashboardPage({super.key, this.onOpenClassList, this.onOpenAttendance});

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
  
  // Simple performance caching
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;

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
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
    
    // Format times to 12-hour format
    final formattedStart = _formatTimeTo12Hour(startTime);
    final formattedEnd = _formatTimeTo12Hour(endTime);
    
    return "$days | $formattedStart - $formattedEnd";
  }
  
  String _formatTimeTo12Hour(String timeStr) {
    if (timeStr.isEmpty) return timeStr;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final displayMinute = minute.toString().padLeft(2, '0');
        return '$displayHour:$displayMinute $period';
      }
    }
    return timeStr;
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
    // Simple cache check - avoid reloading data if loaded recently
    final currentTime = DateTime.now();
    if (_lastLoadTime != null && 
        currentTime.difference(_lastLoadTime!).inMinutes < 2) {
      return;
    }
    
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

      // Batch load students for all sections at once
      final allSectionIds = assignedSections
          .map((a) => a['sections']?['id'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toSet()
          .toList();

      if (allSectionIds.isNotEmpty) {
        final allStudents = await supabase
            .from('students')
            .select('id, fname, lname, rfid_uid, section_id')
            .inFilter('section_id', allSectionIds);
        
        // Group students by section
        for (final student in allStudents) {
          final sectionId = student['section_id'] as int;
          sectionStudents.putIfAbsent(sectionId, () => []).add(student);
        }
      }    // Date filters for today
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

    // Batch process today's attendance for all sections
    int totalStudents = 0, totalPresent = 0;
    List<Map<String, dynamic>> allLateArrivals = [];

    // Get all student IDs across all sections
    final allStudentIds = sectionStudents.values
        .expand((students) => students)
        .map((s) => s['id'] as int)
        .toList();

    if (allStudentIds.isNotEmpty) {
      // Batch load scan records for all students
      final scanRecords = await supabase
          .from('scan_records')
          .select('student_id, scan_time, action')
          .inFilter('student_id', allStudentIds)
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
      
      // Process each section's attendance
      for (final assignment in todayAssignments) {
        final section = assignment['sections'];
        if (section == null) continue;
        final sectionId = section['id'] as int;
        final studentsList = sectionStudents[sectionId] ?? [];
        
        if (studentsList.isEmpty) {
          sectionAttendanceStats[sectionId] = {'present': 0, 'attendance': 0};
          sectionStudentStatus[sectionId] = {};
          continue;
        }
        
        totalStudents += studentsList.length;
        
        int presentCount = 0;
        Map<int, String> statusMap = {};
        List<Map<String, dynamic>> lateThisSection = [];
        
        // Parse class times for this assignment
        final startTimeStr = assignment['start_time'] ?? '';
        final endTimeStr = assignment['end_time'] ?? '';
        DateTime? classStartTime;
        DateTime? classEndTime;
        
        if (startTimeStr.contains(':')) {
          final st = startTimeStr.split(':');
          classStartTime = DateTime(
            now.year, now.month, now.day,
            int.parse(st[0]), int.parse(st[1]),
          );
        }
        if (endTimeStr.contains(':')) {
          final et = endTimeStr.split(':');
          classEndTime = DateTime(
            now.year, now.month, now.day,
            int.parse(et[0]), int.parse(et[1]),
          );
        }
        
        for (final student in studentsList) {
          final int sid = student['id'];
          if (presentIds.contains(sid)) {
            presentCount++;
            statusMap[sid] = "Present";
            // Check for late arrivals
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
            // Only count as absent if class time has ended
            if (classEndTime != null && now.isAfter(classEndTime)) {
              statusMap[sid] = "Absent";
            } else {
              statusMap[sid] = "Not Marked";
            }
          }
        }
        
        int attendancePercent =
            studentsList.isEmpty
                ? 0
                : ((presentCount / studentsList.length) * 100).round();

        sectionAttendanceStats[sectionId] = {
          'present': presentCount,
          'attendance': attendancePercent,
        };
        sectionStudentStatus[sectionId] = statusMap;
        totalPresent += presentCount;
        allLateArrivals.addAll(lateThisSection);
      }
    }

    // Count actual absences (not including "Not Marked" students)
    int actualAbsent = 0;
    for (final assignment in todayAssignments) {
      final section = assignment['sections'];
      if (section == null) continue;
      final statusMap = sectionStudentStatus[section['id']] ?? {};
      for (final status in statusMap.values) {
        if (status == "Absent") {
          actualAbsent++;
        }
      }
    }
    
    totalClassesToday = todayAssignments.length;
    totalStudentsToday = totalStudents;
    totalPresentToday = totalPresent;
    totalAbsentToday = actualAbsent;
    lateArrivals = allLateArrivals;

    // Load students with attendance issues using ticketing service
    studentsWithAttendanceIssues = await _ticketingService.getStudentsRequiringAttention(
      teacherId: teacherId!,
    );

    // Load attendance insights
    attendanceInsights = await _attendanceService.getAttendanceInsights(
      teacherId: teacherId!,
    );

    _lastLoadTime = DateTime.now();
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

  // Responsive details layout following the reference wireframe:
  // - Broad overview at top (we use AttendanceInsightsCard above)
  // - Below it: two-column grid
  //   Left: Today's Schedule (top) + Attendance Alerts (bottom)
  //   Right: Students Requiring Attention (spans vertically)
  // On narrow screens, stack vertically in the original order.
  Widget _buildDetailLayoutGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000; // desktop/tablet wide breakpoint
        if (!isWide) {
          // Original stacked order for mobile / narrow screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScheduleList(),
              const SizedBox(height: 24),
              _buildAttendanceIssues(),
            ],
          );
        }

        // Two-column grid for wide screens
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: schedule only
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScheduleList(),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // No extra horizontal spacer to avoid doubling with inner paddings
            // Right column: students requiring attention spanning vertically
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Opacity(
                    opacity: 0.0,
                    child: Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAttendanceIssues(),
                ],
              ),
            ),
          ],
        );
      },
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
                        if (widget.onOpenAttendance != null) {
                          widget.onOpenAttendance!(assignment['sections']['id'], assignment['sections']['name']);
                        } else {
                          // Fallback: Direct navigation (loses sidebar)
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => TeacherSectionAttendancePage(
                                sectionId: assignment['sections']['id'],
                                sectionName: assignment['sections']['name'],
                                onBack: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
        ],
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

    // Only show badges if there are 3+ consecutive absences and no unresolved notifications
    if (consecutiveAbsences >= 3 && (!hasTicket || isResolved)) {
      if (consecutiveAbsences >= 8) {
        badgeWidgets.add(const AttendanceStatusBadge(
          type: AttendanceBadgeType.critical,
        ));
      } else if (consecutiveAbsences >= 5) {
        badgeWidgets.add(const AttendanceStatusBadge(
          type: AttendanceBadgeType.urgent,
        ));
      } else if (consecutiveAbsences >= 3) {
        badgeWidgets.add(const AttendanceStatusBadge(
          type: AttendanceBadgeType.attention,
        ));
      }
    } else if (hasTicket && !isResolved) {
      badgeWidgets.add(const AttendanceStatusBadge(
        type: AttendanceBadgeType.monitoring,
      ));
    }

    // Determine priority color for container styling
    Color priorityColor;
    if (consecutiveAbsences >= 8) {
      priorityColor = const Color(0xFF8B0000); // Dark red for critical
    } else if (consecutiveAbsences >= 5) {
      priorityColor = const Color(0xFFDC2626); // Red for urgent
    } else if (hasTicket && !isResolved) {
      priorityColor = const Color(0xFF3B82F6); // Blue for monitoring
    } else {
      priorityColor = const Color(0xFFF59E0B); // Orange for attention
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
                      // Reference layout grid (schedule + alerts on left, issues on right)
                      _buildDetailLayoutGrid(),
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


