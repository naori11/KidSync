// ...existing code...
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherSectionAttendancePage extends StatefulWidget {
  final int sectionId;
  final String sectionName;
  final VoidCallback? onBack;

  const TeacherSectionAttendancePage({
    super.key,
    required this.sectionId,
    required this.sectionName,
    this.onBack,
  });

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

  // Section schedule (now supports multiple schedule rows)
  List<Map<String, dynamic>> scheduleRows = [];
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

    // Load ALL section_teachers rows for this section (handle duplicates)
    final schedRows = await supabase
        .from('section_teachers')
        .select('id, subject, days, start_time, end_time, assigned_at')
        .eq('section_id', widget.sectionId)
        .order('assigned_at', ascending: true);

    scheduleRows = List<Map<String, dynamic>>.from(schedRows);

    DateTime now = DateTime.now();
    scheduleString = null;
    classDays = [];
    startTime = null;
    endTime = null;
    classStartTime = null;
    classEndTime = null;
    attendanceActive = false;

    if (scheduleRows.isNotEmpty) {
      // Build a readable schedule string (list multiple rows)
      final scheduleStrings = <String>[];
      final Set<String> unionDays = {};
      for (final r in scheduleRows) {
        final days =
            r['days'] is List
                ? (r['days'] as List).cast<String>()
                : (r['days']?.toString() ?? '')
                    .split(',')
                    .map((e) => e.trim())
                    .toList();
        final st = r['start_time']?.toString() ?? '';
        final et = r['end_time']?.toString() ?? '';
        if (days.isNotEmpty) unionDays.addAll(days);
        scheduleStrings.add(
          days.isNotEmpty
              ? "${days.join(', ')} | ${_shortTime(st)} - ${_shortTime(et)}${r['subject'] != null ? ' (${r['subject']})' : ''}"
              : "${_shortTime(st)} - ${_shortTime(et)}",
        );
      }
      scheduleString = scheduleStrings.join("  /  ");
      classDays = unionDays.toList();

      // Determine today's schedules (rows that include today)
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayAbbrev = weekDays[now.weekday - 1];

      final todays =
          scheduleRows.where((r) {
            final days =
                r['days'] is List
                    ? (r['days'] as List).cast<String>()
                    : (r['days']?.toString() ?? '')
                        .split(',')
                        .map((e) => e.trim())
                        .toList();
            return days.contains(todayAbbrev);
          }).toList();

      final rowsToConsider = todays.isNotEmpty ? todays : scheduleRows;

      // Pick earliest start_time and latest end_time among considered rows
      DateTime? earliestStart;
      DateTime? latestEnd;
      for (final r in rowsToConsider) {
        final st = r['start_time']?.toString() ?? '';
        final et = r['end_time']?.toString() ?? '';
        final sp = st.split(':');
        final ep = et.split(':');
        if (sp.length >= 2 && ep.length >= 2) {
          final sDt = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(sp[0]),
            int.parse(sp[1]),
          );
          final eDt = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(ep[0]),
            int.parse(ep[1]),
          );
          if (earliestStart == null || sDt.isBefore(earliestStart))
            earliestStart = sDt;
          if (latestEnd == null || eDt.isAfter(latestEnd)) latestEnd = eDt;
        }
      }
      if (earliestStart != null && latestEnd != null) {
        classStartTime = earliestStart;
        classEndTime = latestEnd;
        startTime = TimeOfDay(
          hour: classStartTime!.hour,
          minute: classStartTime!.minute,
        );
        endTime = TimeOfDay(
          hour: classEndTime!.hour,
          minute: classEndTime!.minute,
        );
        // If any of the considered rows envelop now, attendanceActive = true
        if (now.isAfter(classStartTime!) && now.isBefore(classEndTime!))
          attendanceActive = true;
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

    final sList = List<Map<String, dynamic>>.from(studentList);
    final studentIds = [for (final s in sList) s['id'] as int];
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
    for (final stu in sList) {
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

    // Auto-mark students as present if they tapped RFID but don't have attendance record
    await _processRfidAutoAttendance(scanRecordByStudent, attendanceByStudent);

    setState(() {
      isLoading = false;
      todayScan = scanRecordByStudent;
      todayAttendance = attendanceByStudent;
    });
  }

  // Auto-mark students as present when they tap RFID during school hours
  Future<void> _processRfidAutoAttendance(
    Map<int, Map<String, dynamic>> scans,
    Map<int, Map<String, dynamic>> attendance,
  ) async {
    if (!attendanceActive && !isTestingSection) return; // Only process during active attendance or in testing sections

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final todayDateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> autoAttendanceRecords = [];

    for (final student in students) {
      final studentId = student['id'] as int;
      final scan = scans[studentId];
      final existingAttendance = attendance[studentId];

      // If student has tapped RFID but no attendance record exists, auto-mark as present
      if (scan != null && existingAttendance == null) {
        String status = "Present";
        String notes = "Auto-marked via RFID tap";

        // Check if it should be marked as late based on scan time and class start time
        if (classStartTime != null) {
          final scanTime = DateTime.parse(scan['scan_time']);
          final lateThreshold = classStartTime!.add(
            Duration(minutes: lateThresholdMinutes),
          );
          if (scanTime.isAfter(lateThreshold)) {
            status = "Late";
            notes = "Auto-marked as late via RFID tap";
          }
        }

        final attendanceRecord = {
          'section_id': widget.sectionId,
          'student_id': studentId,
          'date': todayDateStr,
          'status': status,
          'marked_by': user.id,
          'marked_at': scan['scan_time'], // Use the scan time as marked time
          'notes': notes,
        };

        autoAttendanceRecords.add(attendanceRecord);
        
        // Update local attendance map
        attendance[studentId] = attendanceRecord;
      }
    }

    // Bulk insert auto-attendance records if any
    if (autoAttendanceRecords.isNotEmpty) {
      try {
        // Use upsert with proper conflict resolution for auto-attendance
        for (final record in autoAttendanceRecords) {
          await supabase.from('section_attendance').upsert(
            record,
            onConflict: 'section_id, student_id, date',
          );
        }
        print('Auto-marked ${autoAttendanceRecords.length} students as present via RFID');
      } catch (e) {
        print('Error auto-marking attendance: $e');
      }
    }
  }

  String _shortTime(String t) {
    if (t.isEmpty) return "";
    final parts = t.split(':');
    if (parts.length >= 2) {
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return "$h:$m";
    }
    return t;
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

    // Get existing attendance record (if any) to preserve the ID
    final existingAttendance = todayAttendance[studentId];
    
    // Store in local state instead of database
    setState(() {
      pendingAttendance[studentId] = {
        if (existingAttendance != null) 'id': existingAttendance['id'], // Preserve existing ID
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
      // If there's a pending change, remove it
      if (pendingAttendance.containsKey(studentId)) {
        pendingAttendance.remove(studentId);
      } else {
        // If there's an existing attendance record, mark it for deletion by setting status to "Absent"
        final existingAttendance = todayAttendance[studentId];
        if (existingAttendance != null) {
          final user = supabase.auth.currentUser;
          if (user != null) {
            final today = DateTime.now();
            final todayDateStr =
                "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
            
            pendingAttendance[studentId] = {
              'id': existingAttendance['id'], // Preserve existing ID
              'section_id': widget.sectionId,
              'student_id': studentId,
              'date': todayDateStr,
              'status': 'Absent',
              'marked_by': user.id,
              'marked_at': DateTime.now().toIso8601String(),
              'notes': 'Undone by teacher',
            };
          }
        }
      }
      
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
              "Are you sure you want to mark all non-RFID tapped students as Present?",
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
      final scan = todayScan[stu['id']];
      // Only mark as present if they haven't tapped RFID and are currently absent
      if (currentAttendance == "Absent" && scan == null) {
        await _markAttendance(stu['id'], "Present");
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
    int present = 0, late = 0, absent = 0, excused = 0, emergency = 0, total = students.length;
    for (final s in students) {
      final status = _getCurrentAttendanceStatus(s['id']);
      if (status == "Present")
        present++;
      else if (status == "Late")
        late++;
      else if (status == "Excused")
        excused++;
      else if (status == "Emergency Exit")
        emergency++;
      else
        absent++;
    }
    return {
      'Present': present,
      'Late': late,
      'Absent': absent,
      'Excused': excused,
      'Emergency Exit': emergency,
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
      // Submit all pending attendance records with proper upsert logic
      for (final attendance in pendingAttendance.values) {
        try {
          // Use upsert with onConflict to handle existing records
          await supabase.from('section_attendance').upsert(
            attendance,
            onConflict: 'section_id, student_id, date',
          );
        } catch (individualError) {
          print('Error updating individual attendance record: $individualError');
          // Continue with other records even if one fails
        }
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

  // Handle mark absent
  Future<void> _handleMarkAbsent(int studentId) async {
    if (!attendanceActive) return;
    await _markAttendance(studentId, "Absent");
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

  // Handle emergency exit
  Future<void> _handleEmergencyExit(int studentId) async {
    if (!attendanceActive) return;

    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text("Emergency Exit"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Record emergency exit for this student:"),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: "Emergency reason/details...",
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Record Emergency Exit"),
              ),
            ],
          ),
    );

    if (result == true) {
      await _markAttendance(
        studentId,
        "Emergency Exit",
        notes:
            notesController.text.trim().isEmpty
                ? "Emergency exit - no details provided"
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

      // Convert to CSV string and would be used for download
      // String csvString = csvData.map((row) => row.join(',')).join('\n');

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

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _getSummary();
    final percent =
        summary['Total'] == 0
            ? 0
            : ((summary['Present']! + summary['Late']! + summary['Excused']! + summary['Emergency Exit']!) /
                    summary['Total']!) *
                100;
    final now = DateTime.now();
    final countdown = _nextSessionCountdown();

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 24,
                                      color: Color(0xFF8F9BB3),
                                    ),
                                    tooltip: 'Back to Class List',
                                    splashRadius: 22,
                                    onPressed:
                                        widget.onBack ??
                                        () => Navigator.of(context).maybePop(),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              "Take Attendance",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF222B45),
                                              ),
                                            ),
                                            const Text(
                                              "/",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8F9BB3),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget.sectionName,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8F9BB3),
                                              ),
                                            ),
                                            // Add unsaved changes indicator
                                            if (hasUnsavedChanges) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        Colors.orange.shade300,
                                                  ),
                                                ),
                                                child: Text(
                                                  "Unsaved Changes",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (scheduleString != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              "Schedule: $scheduleString",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF2E3A59),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Export button with student management styling
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.file_download_outlined,
                              color: Color(0xFF2ECC71),
                              size: 18,
                            ),
                            label: const Text(
                              "Export",
                              style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: _exportCSV,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF2ECC71),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 1,
                              shadowColor: Colors.black.withOpacity(0.05),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
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
                        vertical: 8,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  classStartTime != null &&
                                          now.isBefore(classStartTime!)
                                      ? "Attendance not open yet"
                                      : "Attendance is closed for this session",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              if (countdown != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.timer,
                                        size: 12,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        countdown,
                                        style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  // ... rest of UI remains unchanged ...
                  // Summary and Controls Container
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Summary Stats Row
                            Row(
                              children: [
                                _buildStatChip(
                                  "Present",
                                  summary['Present']!,
                                  const Color(0xFF19AE61),
                                ),
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  "Late",
                                  summary['Late']!,
                                  const Color(0xFFFFA726),
                                ),
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  "Absent",
                                  summary['Absent']!,
                                  const Color(0xFFEB5757),
                                ),
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  "Excused",
                                  summary['Excused']!,
                                  const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${percent.round()}% attended",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Filter Dropdown
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 80,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFE4E9F2),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: DropdownButton<String>(
                                    value: filterStatus,
                                    isExpanded: false,
                                    items:
                                        [
                                              "All",
                                              "Present",
                                              "Late",
                                              "Absent",
                                              "Excused",
                                            ]
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        (v) => setState(
                                          () => filterStatus = v ?? "All",
                                        ),
                                    style: const TextStyle(fontSize: 13),
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16,
                                    ),
                                    dropdownColor: Colors.white,
                                    menuMaxHeight: 200,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Controls Row
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                  ),
                                  label: const Text("Mark All Non-RFID as Present"),
                                  onPressed:
                                      attendanceActive && summary['Absent']! > 0
                                          ? _markAllPresent
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF19AE61),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    const Text(
                                      "Late after: ",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8F9BB3),
                                      ),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 80,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFE4E9F2),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButton<int>(
                                        value: lateThresholdMinutes,
                                        isExpanded: false,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 5,
                                            child: Text(
                                              "5 mins",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 10,
                                            child: Text(
                                              "10 mins",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 15,
                                            child: Text(
                                              "15 mins",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 20,
                                            child: Text(
                                              "20 mins",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                        onChanged:
                                            attendanceActive
                                                ? (v) => setState(() {
                                                  if (v != null)
                                                    lateThresholdMinutes = v;
                                                })
                                                : null,
                                        style: const TextStyle(fontSize: 13),
                                        underline: const SizedBox(),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                        ),
                                        dropdownColor: Colors.white,
                                        menuMaxHeight: 200,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // RFID Auto-Attendance Information
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF19AE61),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.wifi_tethering,
                                    color: const Color(0xFF19AE61),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "RFID Auto-Attendance: Students are automatically marked Present/Late when they tap their RFID card during school hours. Use buttons below for manual overrides.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w500,
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
                  ),
                  const SizedBox(height: 8),
                  // Table/List
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF7F9FC),
                                    const Color(0xFFF2F6FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                border: const Border(
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
                                                      // Absent button - only show if student is currently Present/Late (to mark them absent)
                                                      if (attendanceActive &&
                                                          (status == "Present" ||
                                                              status == "Late"))
                                                        SizedBox(
                                                          height: 28,
                                                          child: ElevatedButton(
                                                            onPressed:
                                                                () =>
                                                                    _handleMarkAbsent(
                                                                      s['id'],
                                                                    ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFFEB5757,
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
                                                              "Absent",
                                                            ),
                                                          ),
                                                        ),
                                                      if (attendanceActive &&
                                                          (status == "Present" ||
                                                              status == "Late") &&
                                                          status != "Excused")
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                      // Excused button - show for any status except Excused
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
                                                          status != "Excused" &&
                                                          status != "Emergency Exit")
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                      // Emergency Exit button - show for Present/Late students
                                                      if (attendanceActive &&
                                                          (status == "Present" ||
                                                              status == "Late"))
                                                        SizedBox(
                                                          height: 28,
                                                          child: ElevatedButton(
                                                            onPressed:
                                                                () =>
                                                                    _handleEmergencyExit(
                                                                      s['id'],
                                                                    ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFFF44336,
                                                                  ),
                                                              foregroundColor:
                                                                  Colors.white,
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
                                                              elevation: 0,
                                                              textStyle:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              "Emergency",
                                                            ),
                                                          ),
                                                        ),
                                                      // Undo button - show for non-absent students
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow:
                            hasUnsavedChanges
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : null,
                      ),
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
                            attendanceActive &&
                                    !isSubmitting &&
                                    hasUnsavedChanges
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
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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
      case "Emergency Exit":
        color = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFF44336);
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
