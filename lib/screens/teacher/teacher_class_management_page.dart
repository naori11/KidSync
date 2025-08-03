import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_student_attendance_calendar_page.dart';

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
  bool isLoading = true;
  bool isSubmitting = false;
  String filterStatus = "All";
  int lateThresholdMinutes = 10; // Default, can be adjusted

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
    await supabase.from('section_attendance').upsert({
      'section_id': widget.sectionId,
      'student_id': studentId,
      'date': todayDateStr,
      'status': status,
      'marked_by': user.id,
      'marked_at': DateTime.now().toIso8601String(),
      'notes': notes,
    });
    await _loadAttendanceData();
  }

  Future<void> _undoAttendance(int studentId) async {
    if (!attendanceActive) return;
    final today = DateTime.now();
    final todayDateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    await supabase
        .from('section_attendance')
        .delete()
        .eq('section_id', widget.sectionId)
        .eq('student_id', studentId)
        .eq('date', todayDateStr);
    await _loadAttendanceData();
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
      if (todayAttendance[stu['id']] == null) {
        await _handleMarkPresent(stu['id']);
      }
    }
    await _loadAttendanceData();
  }

  Future<void> _handleMarkPresent(int studentId) async {
    if (!attendanceActive) return;
    final now = DateTime.now();
    String status = "Present";
    // For normal sections, use late logic. For testing, always "Present".
    if (!isTestingSection) {
      if (classStartTime == null) return; // Defensive: should not happen
      final threshold = classStartTime!.add(
        Duration(minutes: lateThresholdMinutes),
      );
      if (now.isAfter(threshold)) {
        status = "Late";
      }
    }
    await _markAttendance(studentId, status);
  }

  Future<void> _handleMarkExcused(int studentId) async {
    if (!attendanceActive) return;
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String note = '';
        return AlertDialog(
          title: const Text("Mark as Excused"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: "Reason / Notes"),
            onChanged: (val) => note = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(note),
              child: const Text("Excuse"),
            ),
          ],
        );
      },
    );
    if (notes != null && notes.trim().isNotEmpty) {
      await _markAttendance(studentId, "Excused", notes: notes.trim());
    }
  }

  // --- Attendance summary ---
  Map<String, int> _getSummary() {
    int present = 0, late = 0, absent = 0, excused = 0, total = students.length;
    for (final s in students) {
      final att = todayAttendance[s['id']];
      final status = att != null ? att['status'] : null;
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

  // --- Filtering ---
  List<Map<String, dynamic>> get _filteredStudents {
    if (filterStatus == "All") return students;
    return students.where((s) {
      final att = todayAttendance[s['id']];
      final status = att != null ? att['status'] : "Absent";
      return status == filterStatus;
    }).toList();
  }

  // --- Export CSV ---
  Future<void> _exportCSV() async {
    // Generate CSV string
    final buffer = StringBuffer();
    buffer.writeln("Student ID,First Name,Last Name,RFID UID,Status,Notes");
    for (final s in students) {
      final att = todayAttendance[s['id']];
      final status = att != null ? att['status'] : "Absent";
      final notes = att != null && att['notes'] != null ? att['notes'] : "";
      buffer.writeln(
        '"${s['id']}","${s['fname']}","${s['lname']}","${s['rfid_uid'] ?? ''}","$status","$notes"',
      );
    }
    // Save/export logic...
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("CSV Generated"),
            content: const Text(
              "The CSV has been generated. Implement file download/share as needed.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  String? _nextSessionCountdown() {
    // Only show if today is a class day and class is not active yet
    if (isTestingSection) return null;
    if (classStartTime == null || classDays.isEmpty) return null;
    final now = DateTime.now();
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayAbbrev = weekDays[now.weekday - 1];
    if (classDays.contains(todayAbbrev) && now.isBefore(classStartTime!)) {
      final diff = classStartTime!.difference(now);
      if (diff.inSeconds > 0) {
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        final s = diff.inSeconds % 60;
        return "${h > 0 ? '$h h ' : ''}${m.toString().padLeft(2, '0')} min ${s.toString().padLeft(2, '0')} s";
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
                              Text(
                                widget.sectionName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8F9BB3),
                                  fontWeight: FontWeight.w600,
                                ),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: const [
                                  Expanded(flex: 2, child: Text("RFID Tap")),
                                  Expanded(flex: 4, child: Text("Student")),
                                  Expanded(flex: 2, child: Text("Status")),
                                  Expanded(flex: 3, child: Text("Actions")),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
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
                                          final att = todayAttendance[s['id']];
                                          final status =
                                              att != null
                                                  ? att['status']
                                                  : "Absent";
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
                                            color:
                                                idx % 2 == 0
                                                    ? const Color(0xFFF7F9FC)
                                                    : Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 7,
                                              horizontal: 0,
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
                                                                ? Colors.green
                                                                : Colors.grey,
                                                        size: 20,
                                                      ),
                                                      if (tapped) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          scanTime,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors
                                                                        .green,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                // Student Name
                                                Expanded(
                                                  flex: 4,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      Navigator.of(
                                                        context,
                                                      ).push(
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                context,
                                                              ) => TeacherStudentAttendanceCalendarPage(
                                                                studentId:
                                                                    s['id'],
                                                                studentName:
                                                                    "${s['fname']} ${s['lname']}",
                                                                sectionId:
                                                                    widget
                                                                        .sectionId,
                                                                sectionName:
                                                                    widget
                                                                        .sectionName,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    child: Text(
                                                      "${s['fname']} ${s['lname']}",
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF222B45,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Status badge
                                                Expanded(
                                                  flex: 2,
                                                  child: _StatusBadge(
                                                    status: status,
                                                  ),
                                                ),
                                                // Actions
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      if (attendanceActive &&
                                                          (status == "Absent" ||
                                                              status == "Late"))
                                                        ElevatedButton(
                                                          onPressed:
                                                              attendanceActive
                                                                  ? () =>
                                                                      _handleMarkPresent(
                                                                        s['id'],
                                                                      )
                                                                  : null,
                                                          child: const Text(
                                                            "Mark Present",
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFF19AE61,
                                                                ),
                                                            foregroundColor:
                                                                Colors.white,
                                                            textStyle:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 0,
                                                                ),
                                                            minimumSize:
                                                                const Size(
                                                                  0,
                                                                  32,
                                                                ),
                                                          ),
                                                        ),
                                                      if (attendanceActive &&
                                                          status != "Excused")
                                                        TextButton(
                                                          onPressed:
                                                              attendanceActive
                                                                  ? () =>
                                                                      _handleMarkExcused(
                                                                        s['id'],
                                                                      )
                                                                  : null,
                                                          child: const Text(
                                                            "Excuse",
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF2563EB,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      if (attendanceActive &&
                                                          status != "Absent")
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.undo,
                                                            size: 18,
                                                            color: Colors.grey,
                                                          ),
                                                          tooltip: "Undo",
                                                          onPressed:
                                                              attendanceActive
                                                                  ? () =>
                                                                      _undoAttendance(
                                                                        s['id'],
                                                                      )
                                                                  : null,
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
                      icon: const Icon(Icons.done_all),
                      label: Text(
                        isSubmitting ? "Submitting..." : "Submit Attendance",
                      ),
                      onPressed:
                          attendanceActive && !isSubmitting
                              ? () async {
                                setState(() => isSubmitting = true);
                                // Optionally lock attendance or show confirmation
                                await Future.delayed(
                                  const Duration(seconds: 1),
                                );
                                setState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Attendance submitted!"),
                                  ),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
