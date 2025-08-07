import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_attendance_calendar_page.dart';

class TeacherSectionAttendancePage extends StatefulWidget {
  final int sectionId;
  final String sectionName;
  final VoidCallback? onBack;

  const TeacherSectionAttendancePage({
    Key? key,
    required this.sectionId,
    required this.sectionName,
    this.onBack,
  }) : super(key: key);

  @override
  State<TeacherSectionAttendancePage> createState() =>
      _TeacherSectionAttendancePageState();
}

class _TeacherSectionAttendancePageState
    extends State<TeacherSectionAttendancePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> students = [];
  Map<int, Map<String, dynamic>> todayAttendance = {};
  Map<int, Map<String, dynamic>> todayScan = {};

  // Add these new variables for local state management
  Map<int, Map<String, dynamic>> pendingAttendance = {};
  bool hasUnsavedChanges = false;

  bool isLoading = true;
  bool isSubmitting = false;
  String filterStatus = "All";
  int lateThresholdMinutes = 10;

  // Section schedule
  List<String> classDays = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool attendanceActive = false;
  String? scheduleString;
  DateTime? classStartTime;
  DateTime? classEndTime;
  bool isTestingSection = false;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => isLoading = true);

    // Load section info (to get is_testing flag)
    final sectionRes =
        await supabase
            .from('sections')
            .select('id, is_testing')
            .eq('id', widget.sectionId)
            .maybeSingle();

    isTestingSection = sectionRes != null && sectionRes['is_testing'] == true;

    // Load section schedule from section_teachers
    final schedRes =
        await supabase
            .from('section_teachers')
            .select('days, start_time, end_time')
            .eq('section_id', widget.sectionId)
            .maybeSingle();

    DateTime now = DateTime.now();
    scheduleString = null;
    classDays = [];
    startTime = null;
    endTime = null;
    classStartTime = null;
    classEndTime = null;
    attendanceActive = false;

    if (schedRes != null) {
      // Parse days
      classDays =
          schedRes['days'] is List
              ? (schedRes['days'] as List).cast<String>()
              : (schedRes['days']?.toString() ?? '')
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
      // Parse start/end times
      var st = schedRes['start_time'];
      var et = schedRes['end_time'];
      if (st != null) {
        final p = st.split(":");
        if (p.length >= 2) {
          startTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }
      if (et != null) {
        final p = et.split(":");
        if (p.length >= 2) {
          endTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }
      // Build readable schedule string
      if (classDays.isNotEmpty && startTime != null && endTime != null) {
        scheduleString =
            "${classDays.join(', ')} | ${startTime!.format(context)} - ${endTime!.format(context)}";
      }

      // Check if current day/time is within schedule
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayAbbrev = weekDays[now.weekday - 1];
      if (classDays.contains(todayAbbrev) &&
          startTime != null &&
          endTime != null) {
        // Build today's DateTime for start/end
        classStartTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTime!.hour,
          startTime!.minute,
        );
        classEndTime = DateTime(
          now.year,
          now.month,
          now.day,
          endTime!.hour,
          endTime!.minute,
        );
        if (now.isAfter(classStartTime!) && now.isBefore(classEndTime!)) {
          attendanceActive = true;
        }
      }
    }

    // OVERRIDE: If this is a testing section, always allow attendance
    if (isTestingSection) {
      attendanceActive = true;
    }

    // Load students in section
    final studentList = await supabase
        .from('students')
        .select('id, fname, lname, rfid_uid')
        .eq('section_id', widget.sectionId);

    // Load today's scan_records for all students (for RFID tap status)
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final studentIds = [for (final s in studentList) s['id'] as int];
    Map<int, Map<String, dynamic>> scanRecordByStudent = {};
    if (studentIds.isNotEmpty) {
      final scans = await supabase
          .from('scan_records')
          .select('id, student_id, scan_time, action, status')
          .inFilter('student_id', studentIds)
          .gte('scan_time', startOfDay.toIso8601String())
          .lte('scan_time', endOfDay.toIso8601String())
          .order('scan_time', ascending: true);
      for (final s in scans) {
        final sid = s['student_id'] as int;
        // Use the first 'entry' action for today as tap-in
        if (s['action']?.toString().toLowerCase() == 'entry' &&
            scanRecordByStudent[sid] == null) {
          scanRecordByStudent[sid] = s;
        }
      }
    }

    // Load today's section_attendance for all students
    Map<int, Map<String, dynamic>> attendanceByStudent = {};
    if (studentIds.isNotEmpty) {
      final todayDateStr =
          "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final attendanceRows = await supabase
          .from('section_attendance')
          .select('*')
          .eq('section_id', widget.sectionId)
          .eq('date', todayDateStr);
      for (final att in attendanceRows) {
        attendanceByStudent[att['student_id'] as int] = att;
      }
    }

    // Compose student rows
    students.clear();
    for (final stu in studentList) {
      final id = stu['id'] as int;
      students.add({
        'id': id,
        'fname': stu['fname'],
        'lname': stu['lname'],
        'rfid_uid': stu['rfid_uid'],
        'scan': scanRecordByStudent[id], // may be null
        'attendance': attendanceByStudent[id], // may be null
      });
    }

    setState(() {
      isLoading = false;
      todayScan = scanRecordByStudent;
      todayAttendance = attendanceByStudent;
    });
  }

  // --- Attendance marking logic ---
  Future<void> _markAttendance(
    int studentId,
    String status, {
    String? notes,
  }) async {
    if (!attendanceActive) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final todayDateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Store in local state instead of database
    setState(() {
      pendingAttendance[studentId] = {
        'section_id': widget.sectionId,
        'student_id': studentId,
        'date': todayDateStr,
        'status': status,
        'marked_by': user.id,
        'marked_at': DateTime.now().toIso8601String(),
        'notes': notes,
      };
      hasUnsavedChanges = true;
    });
  }

  Future<void> _undoAttendance(int studentId) async {
    if (!attendanceActive) return;

    setState(() {
      pendingAttendance.remove(studentId);
      // Check if there are any remaining changes
      hasUnsavedChanges = pendingAttendance.isNotEmpty;
    });
  }

  Future<void> _markAllPresent() async {
    if (!attendanceActive) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Mark All as Present"),
            content: const Text(
              "Are you sure you want to mark all students as Present (or Late if past threshold)?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Mark All"),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    for (final stu in students) {
      final currentAttendance = _getCurrentAttendanceStatus(stu['id']);
      if (currentAttendance == "Absent") {
        await _handleMarkPresent(stu['id']);
      }
    }
  }

  // Add helper method to get current attendance status (including pending changes)
  String _getCurrentAttendanceStatus(int studentId) {
    if (pendingAttendance.containsKey(studentId)) {
      return pendingAttendance[studentId]!['status'];
    }
    final att = todayAttendance[studentId];
    return att != null ? att['status'] : "Absent";
  }

  // Modified summary method to include pending changes
  Map<String, int> _getSummary() {
    int present = 0, late = 0, absent = 0, excused = 0, total = students.length;
    for (final s in students) {
      final status = _getCurrentAttendanceStatus(s['id']);
      if (status == "Present")
        present++;
      else if (status == "Late")
        late++;
      else if (status == "Excused")
        excused++;
      else
        absent++;
    }
    return {
      'Present': present,
      'Late': late,
      'Absent': absent,
      'Excused': excused,
      'Total': total,
    };
  }

  // Modified filtered students to use current status
  List<Map<String, dynamic>> get _filteredStudents {
    if (filterStatus == "All") return students;
    return students.where((s) {
      final status = _getCurrentAttendanceStatus(s['id']);
      return status == filterStatus;
    }).toList();
  }

  // Modified submit method to save all pending changes
  Future<void> _submitAttendance() async {
    if (!attendanceActive || isSubmitting || pendingAttendance.isEmpty) return;

    setState(() => isSubmitting = true);

    try {
      // Submit all pending attendance records
      for (final attendance in pendingAttendance.values) {
        await supabase.from('section_attendance').upsert(attendance);
      }

      // Clear pending changes and reload data
      setState(() {
        pendingAttendance.clear();
        hasUnsavedChanges = false;
      });

      await _loadAttendanceData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attendance submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting attendance: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  // Handle mark present (determines if late based on time)
  Future<void> _handleMarkPresent(int studentId) async {
    if (!attendanceActive) return;

    String status = "Present";

    // Check if it should be marked as late
    if (classStartTime != null) {
      final now = DateTime.now();
      final lateThreshold = classStartTime!.add(
        Duration(minutes: lateThresholdMinutes),
      );
      if (now.isAfter(lateThreshold)) {
        status = "Late";
      }
    }

    await _markAttendance(studentId, status);
  }

  // Handle mark excused
  Future<void> _handleMarkExcused(int studentId) async {
    if (!attendanceActive) return;

    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Mark as Excused"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add a note for this excused absence (optional):"),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: "Reason for excuse...",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Mark Excused"),
              ),
            ],
          ),
    );

    if (result == true) {
      await _markAttendance(
        studentId,
        "Excused",
        notes:
            notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
      );
    }
  }

  // Export CSV function
  Future<void> _exportCSV() async {
    try {
      // Create CSV content
      final List<List<String>> csvData = [
        ['Student Name', 'RFID Status', 'Attendance Status', 'Time'],
      ];

      for (final student in students) {
        final scan = todayScan[student['id']];
        final status = _getCurrentAttendanceStatus(student['id']);
        final scanTime =
            scan != null
                ? DateFormat("h:mm a").format(DateTime.parse(scan['scan_time']))
                : 'Not tapped';

        csvData.add([
          '${student['fname']} ${student['lname']}',
          scan != null ? 'Tapped' : 'Not tapped',
          status,
          scanTime,
        ]);
      }

      // Convert to CSV string
      String csvString = csvData.map((row) => row.join(',')).join('\n');

      // For web, you would typically download the file
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("CSV export functionality would be implemented here"),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error exporting CSV: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate countdown to next session
  String? _nextSessionCountdown() {
    if (classStartTime == null || !classDays.isNotEmpty) return null;

    final now = DateTime.now();

    // If we're before today's class time
    if (classStartTime != null && now.isBefore(classStartTime!)) {
      final difference = classStartTime!.difference(now);

      if (difference.inHours > 0) {
        return "${difference.inHours}h ${difference.inMinutes.remainder(60)}m";
      } else {
        return "${difference.inMinutes}m";
      }
    }

    // Find next class day
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final currentDayIndex = now.weekday - 1;

    // Look for next class day in the week
    for (int i = 1; i <= 7; i++) {
      final nextDayIndex = (currentDayIndex + i) % 7;
      final nextDayAbbrev = weekDays[nextDayIndex];

      if (classDays.contains(nextDayAbbrev)) {
        final nextClassDate = now.add(Duration(days: i));
        final nextClassTime = DateTime(
          nextClassDate.year,
          nextClassDate.month,
          nextClassDate.day,
          startTime!.hour,
          startTime!.minute,
        );

        final difference = nextClassTime.difference(now);
        final days = difference.inDays;
        final hours = difference.inHours.remainder(24);
        final minutes = difference.inMinutes.remainder(60);

        if (days > 0) {
          return "${days}d ${hours}h ${minutes}m";
        } else if (hours > 0) {
          return "${hours}h ${minutes}m";
        } else {
          return "${minutes}m";
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _getSummary();
    final percent =
        summary['Total'] == 0
            ? 0
            : ((summary['Present']! + summary['Late']! + summary['Excused']!) /
                    summary['Total']!) *
                100;
    final now = DateTime.now();
    final countdown = _nextSessionCountdown();

    return Scaffold(
      backgroundColor: const Color(0xF7F9FCFF),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header and controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section name and header
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.sectionName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8F9BB3),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  // Add unsaved changes indicator
                                  if (hasUnsavedChanges) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        "Unsaved Changes",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Take Attendance",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222B45),
                                ),
                              ),
                              if (scheduleString != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    "Schedule: $scheduleString",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8F9BB3),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Export
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text("Export CSV"),
                          onPressed: _exportCSV,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF2E3A59),
                            side: const BorderSide(color: Color(0xFFE4E9F2)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 26,
                            color: Color(0xFF8F9BB3),
                          ),
                          tooltip: 'Close',
                          splashRadius: 22,
                          onPressed:
                              widget.onBack ??
                              () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // TESTING SECTION banner
                  if (isTestingSection)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Card(
                        color: const Color(0xFFFCF4DD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: const [
                              Icon(Icons.warning, color: Color(0xFFFFA726)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "This is a testing section. Attendance can be recorded at any time.",
                                  style: TextStyle(
                                    color: Color(0xFF8F9BB3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Status message if attendance is not active
                  if (!attendanceActive && !isTestingSection) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classStartTime != null &&
                                        now.isBefore(classStartTime!)
                                    ? "Attendance not open yet"
                                    : "Attendance is closed for this session",
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                classStartTime != null &&
                                        now.isBefore(classStartTime!)
                                    ? "You can take attendance starting at ${DateFormat.jm().format(classStartTime!)}."
                                    : "You can only take attendance during your scheduled class time.",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8F9BB3),
                                ),
                              ),
                              if (countdown != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer,
                                      size: 18,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      "Next attendance opens in: $countdown",
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Summary bar & filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Text(
                          "Present: ${summary['Present']}   ",
                          style: const TextStyle(
                            color: Color(0xFF19AE61),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "Late: ${summary['Late']}   ",
                          style: const TextStyle(
                            color: Color(0xFFFFA726),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "Absent: ${summary['Absent']}   ",
                          style: const TextStyle(
                            color: Color(0xFFEB5757),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "Excused: ${summary['Excused']}   ",
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          "${percent.round()}% attended",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: filterStatus,
                          items:
                              ["All", "Present", "Late", "Absent", "Excused"]
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setState(() => filterStatus = v ?? "All"),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bulk/Settings
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Mark All as Present"),
                          onPressed:
                              attendanceActive && summary['Absent']! > 0
                                  ? _markAllPresent
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF19AE61),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Row(
                          children: [
                            const Text(
                              "Late after: ",
                              style: TextStyle(fontSize: 14),
                            ),
                            DropdownButton<int>(
                              value: lateThresholdMinutes,
                              items: const [
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text("5 mins"),
                                ),
                                DropdownMenuItem(
                                  value: 10,
                                  child: Text("10 mins"),
                                ),
                                DropdownMenuItem(
                                  value: 15,
                                  child: Text("15 mins"),
                                ),
                                DropdownMenuItem(
                                  value: 20,
                                  child: Text("20 mins"),
                                ),
                              ],
                              onChanged:
                                  attendanceActive
                                      ? (v) => setState(() {
                                        if (v != null) lateThresholdMinutes = v;
                                      })
                                      : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Table/List
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        color: Colors.white,
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        child: Column(
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF7F9FC),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFE4E9F2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "RFID Tap",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      "Student",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Status",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "Actions",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child:
                                  _filteredStudents.isEmpty
                                      ? const Center(
                                        child: Text("No students to display."),
                                      )
                                      : ListView.builder(
                                        itemCount: _filteredStudents.length,
                                        itemBuilder: (ctx, idx) {
                                          final s = _filteredStudents[idx];
                                          final status =
                                              _getCurrentAttendanceStatus(
                                                s['id'],
                                              );
                                          final scan = todayScan[s['id']];
                                          final tapped = scan != null;
                                          final scanTime =
                                              scan != null
                                                  ? DateFormat("h:mm a").format(
                                                    DateTime.parse(
                                                      scan['scan_time'],
                                                    ),
                                                  )
                                                  : "";
                                          return Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  idx % 2 == 0
                                                      ? const Color(0xFFF7F9FC)
                                                      : Colors.white,
                                              border: const Border(
                                                bottom: BorderSide(
                                                  color: Color(0xFFE4E9F2),
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                // RFID Tap
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        tapped
                                                            ? Icons
                                                                .wifi_tethering
                                                            : Icons.wifi_off,
                                                        color:
                                                            tapped
                                                                ? const Color(
                                                                  0xFF19AE61,
                                                                )
                                                                : const Color(
                                                                  0xFF8F9BB3,
                                                                ),
                                                        size: 18,
                                                      ),
                                                      if (tapped) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            scanTime,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF19AE61,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Student Name
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    "${s['fname']} ${s['lname']}",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF222B45),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // Status badge
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: _StatusBadge(
                                                      status: status,
                                                    ),
                                                  ),
                                                ),
                                                // Actions
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (attendanceActive &&
                                                          (status == "Absent" ||
                                                              status == "Late"))
                                                        SizedBox(
                                                          height: 28,
                                                          child: ElevatedButton(
                                                            onPressed:
                                                                () =>
                                                                    _handleMarkPresent(
                                                                      s['id'],
                                                                    ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFF19AE61,
                                                                  ),
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              elevation: 0,
                                                              textStyle:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              "Present",
                                                            ),
                                                          ),
                                                        ),
                                                      if (attendanceActive &&
                                                          (status == "Absent" ||
                                                              status ==
                                                                  "Late") &&
                                                          status != "Excused")
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                      if (attendanceActive &&
                                                          status != "Excused")
                                                        SizedBox(
                                                          height: 28,
                                                          child: TextButton(
                                                            onPressed:
                                                                () =>
                                                                    _handleMarkExcused(
                                                                      s['id'],
                                                                    ),
                                                            style: TextButton.styleFrom(
                                                              foregroundColor:
                                                                  const Color(
                                                                    0xFF2563EB,
                                                                  ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                              ),
                                                              textStyle:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              "Excuse",
                                                            ),
                                                          ),
                                                        ),
                                                      if (attendanceActive &&
                                                          status != "Absent")
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.undo_rounded,
                                                            size: 16,
                                                            color: Color(
                                                              0xFF8F9BB3,
                                                            ),
                                                          ),
                                                          tooltip: "Undo",
                                                          onPressed:
                                                              () =>
                                                                  _undoAttendance(
                                                                    s['id'],
                                                                  ),
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 28,
                                                                minHeight: 28,
                                                              ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          splashRadius: 14,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Submit attendance
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ElevatedButton.icon(
                      icon:
                          isSubmitting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.done_all),
                      label: Text(
                        isSubmitting ? "Submitting..." : "Submit Attendance",
                      ),
                      onPressed:
                          attendanceActive && !isSubmitting && hasUnsavedChanges
                              ? _submitAttendance
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hasUnsavedChanges
                                ? const Color(0xFF2563EB)
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    Color textColor;
    switch (status) {
      case "Present":
        color = const Color(0xFFD9FBE8);
        textColor = const Color(0xFF19AE61);
        break;
      case "Late":
        color = const Color(0xFFFFF3E1);
        textColor = const Color(0xFFFFA726);
        break;
      case "Excused":
        color = const Color(0xFFE4F0FF);
        textColor = const Color(0xFF2563EB);
        break;
      default:
        color = const Color(0xFFFBE9E9);
        textColor = const Color(0xFFEB5757);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
