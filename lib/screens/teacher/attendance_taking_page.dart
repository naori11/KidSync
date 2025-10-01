// ...existing code...
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:html' as html;
import '../../services/teacher_audit_service.dart';

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
  final teacherAuditService = TeacherAuditService();
  List<Map<String, dynamic>> students = [];
  Map<int, Map<String, dynamic>> todayAttendance = {};
  Map<int, Map<String, dynamic>> todayScan = {};

  // Add these new variables for local state management
  Map<int, Map<String, dynamic>> pendingAttendance = {};
  bool hasUnsavedChanges = false;
  
  // Performance optimization
  Timer? _loadingDebouncer;

  bool isLoading = true;
  bool isSubmitting = false;
  String filterStatus = "All";
  int lateThresholdMinutes = 10;

  // Early dismissal state
  bool hasActiveEarlyDismissal = false;
  Map<String, dynamic>? activeEarlyDismissal;
  bool isDismissingSection = false;

  // Section schedule (now supports multiple schedule rows)
  List<Map<String, dynamic>> scheduleRows = [];
  List<String> classDays = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool attendanceActive = false;
  String? scheduleString;
  DateTime? classStartTime;
  DateTime? classEndTime;
  bool isTodayClassDay = false;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    // Set up periodic checking for new RFID taps
    _setupRfidMonitoring();
  }

  Timer? _rfidTimer;

  void _setupRfidMonitoring() {
    // Check for new RFID taps every 45 seconds (reduced from 30) to save resources
    _rfidTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (attendanceActive) {
        _checkForNewRfidTaps();
      }
      // Also check for students who should be automatically marked absent
      _checkForAutomaticAbsences();
    });
  }

  @override
  void dispose() {
    _rfidTimer?.cancel();
    _loadingDebouncer?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => isLoading = true);

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
    isTodayClassDay = false;

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

      // Check if today is a class day
      isTodayClassDay = classDays.contains(todayAbbrev);

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

    // Attendance is only active during scheduled class times

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

    // Load early dismissal status
    await _loadEarlyDismissalStatus();

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
    // Only process during active attendance
    if (!attendanceActive) {
      print('Auto-attendance skipped: not active');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      print('Auto-attendance skipped: no user logged in');
      return;
    }

    final today = DateTime.now();
    final todayDateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> autoAttendanceRecords = [];
    int processedCount = 0;

    for (final student in students) {
      final studentId = student['id'] as int;
      final scan = scans[studentId];
      final existingAttendance = attendance[studentId];

      // Only process if student has tapped RFID but no attendance record exists
      if (scan != null && existingAttendance == null) {
        processedCount++;
        String status = "Present";
        String notes = "Auto-marked via RFID tap";

        // Check if it should be marked as late based on scan time and class start time
        // Only apply late logic if we have a valid class start time
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
        
        print('Auto-marking student $studentId as $status via RFID');
      }
    }

    print('Auto-attendance processing: $processedCount students with RFID taps, ${autoAttendanceRecords.length} records to create');

    // Bulk insert auto-attendance records if any
    if (autoAttendanceRecords.isNotEmpty) {
      try {
        // Use upsert with proper conflict resolution for auto-attendance
        for (final record in autoAttendanceRecords) {
          await supabase.from('section_attendance').upsert(
            record,
            onConflict: 'section_id, student_id, date',
          );

          // Log RFID attendance marking
          final student = students.firstWhere(
            (s) => s['id'] == record['student_id'],
            orElse: () => {'fname': 'Unknown', 'lname': 'Student'},
          );
          final studentName = '${student['fname']} ${student['lname']}';
          
          await teacherAuditService.logAttendanceMarking(
            studentId: record['student_id'].toString(),
            studentName: studentName,
            sectionId: widget.sectionId.toString(),
            sectionName: widget.sectionName,
            status: record['status'],
            date: record['date'],
            isRfidAssisted: true,
            notes: 'RFID auto-attendance',
          );
        }
        print('Auto-marked ${autoAttendanceRecords.length} students via RFID');
      } catch (e) {
        print('Error auto-marking attendance: $e');
      }
    }
  }

  // Check for students who should be automatically marked absent when class time has ended
  Future<void> _checkForAutomaticAbsences() async {
    // Apply auto-absence logic for all sections
    
    // Only check if we have a valid class end time
    if (classEndTime == null) return;
    
    final now = DateTime.now();
    
    // Only proceed if class time has ended
    if (!now.isAfter(classEndTime!)) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final todayDateStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> autoAbsenceRecords = [];
    final List<String> affectedStudents = [];
    int processedCount = 0;

    for (final student in students) {
      final studentId = student['id'] as int;
      
      // Check if student has no attendance record (neither pending nor existing)
      final hasPendingAttendance = pendingAttendance.containsKey(studentId);
      final hasExistingAttendance = todayAttendance.containsKey(studentId);
      
      if (!hasPendingAttendance && !hasExistingAttendance) {
        processedCount++;
        final studentName = '${student['fname']} ${student['lname']}';
        
        final attendanceRecord = {
          'section_id': widget.sectionId,
          'student_id': studentId,
          'date': todayDateStr,
          'status': 'Absent',
          'marked_by': user.id,
          'marked_at': DateTime.now().toIso8601String(),
          'notes': 'Auto-marked absent - class time ended',
        };

        autoAbsenceRecords.add(attendanceRecord);
        affectedStudents.add(studentName);
        
        // Update local attendance map
        todayAttendance[studentId] = attendanceRecord;
        
        print('Auto-marking student $studentId as absent - class time ended');
      }
    }

    print('Auto-absence processing: $processedCount students to mark absent, ${autoAbsenceRecords.length} records to create');

    // Bulk insert auto-absence records if any
    if (autoAbsenceRecords.isNotEmpty) {
      try {
        // Use upsert with proper conflict resolution for auto-absence
        for (final record in autoAbsenceRecords) {
          await supabase.from('section_attendance').upsert(
            record,
            onConflict: 'section_id, student_id, date',
          );

          // Log absence marking
          final student = students.firstWhere(
            (s) => s['id'] == record['student_id'],
            orElse: () => {'fname': 'Unknown', 'lname': 'Student'},
          );
          final studentName = '${student['fname']} ${student['lname']}';
          
          await teacherAuditService.logAttendanceMarking(
            studentId: record['student_id'].toString(),
            studentName: studentName,
            sectionId: widget.sectionId.toString(),
            sectionName: widget.sectionName,
            status: record['status'],
            date: record['date'],
            isRfidAssisted: false,
            notes: 'Auto-absence: class time ended',
          );
        }
        print('Auto-marked ${autoAbsenceRecords.length} students as absent');
        
        // Update UI to reflect changes
        if (mounted) {
          setState(() {
            // UI will automatically update with the new todayAttendance data
          });
        }
      } catch (e) {
        print('Error auto-marking absences: $e');
      }
    }
  }

  // Check for new RFID taps and process them
  Future<void> _checkForNewRfidTaps() async {
    if (!attendanceActive) return;

    try {
      // Get current students list
      final studentIds = [for (final s in students) s['id'] as int];
      if (studentIds.isEmpty) return;

      // Load today's scan_records for all students
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final scans = await supabase
          .from('scan_records')
          .select('id, student_id, scan_time, action, status')
          .inFilter('student_id', studentIds)
          .gte('scan_time', startOfDay.toIso8601String())
          .lte('scan_time', endOfDay.toIso8601String())
          .eq('action', 'entry')
          .order('scan_time', ascending: true);

      // Build scan map (first entry action for each student)
      Map<int, Map<String, dynamic>> newScanRecords = {};
      for (final s in scans) {
        final sid = s['student_id'] as int;
        if (newScanRecords[sid] == null) {
          newScanRecords[sid] = s;
        }
      }

      // Load current attendance records
      final todayDateStr =
          "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final attendanceRows = await supabase
          .from('section_attendance')
          .select('*')
          .eq('section_id', widget.sectionId)
          .eq('date', todayDateStr);

      Map<int, Map<String, dynamic>> currentAttendance = {};
      for (final att in attendanceRows) {
        currentAttendance[att['student_id'] as int] = att;
      }

      // Process new RFID taps for auto-attendance
      await _processRfidAutoAttendance(newScanRecords, currentAttendance);

      // Update local state if there were changes
      bool hasChanges = false;
      for (final studentId in newScanRecords.keys) {
        if (todayScan[studentId] == null) {
          hasChanges = true;
          break;
        }
      }

      if (hasChanges) {
        setState(() {
          todayScan = newScanRecords;
          todayAttendance = currentAttendance;
        });
      }
    } catch (e) {
      print('Error checking for new RFID taps: $e');
    }
  }

  String _shortTime(String t) {
    if (t.isEmpty) return "";
    final parts = t.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final time = TimeOfDay(hour: hour, minute: minute);
        return time.format(context);
      }
    }
    return t;
  }

  // Load early dismissal status for this section today
  Future<void> _loadEarlyDismissalStatus() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      // Check for active early dismissals for this section today
      final dismissals = await supabase
          .from('early_dismissals')
          .select('*')
          .eq('section_id', widget.sectionId)
          .eq('status', 'active')
          .gte('dismissed_at', startOfDay.toIso8601String())
          .lt('dismissed_at', endOfDay.toIso8601String())
          .order('dismissed_at', ascending: false)
          .limit(1);

      setState(() {
        hasActiveEarlyDismissal = dismissals.isNotEmpty;
        activeEarlyDismissal = dismissals.isNotEmpty ? dismissals[0] : null;
      });
    } catch (e) {
      print('Error loading early dismissal status: $e');
    }
  }

  // Create early dismissal for the entire section
  Future<void> _createSectionEarlyDismissal(String reason) async {
    if (isDismissingSection) return;
    
    setState(() => isDismissingSection = true);
    
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isDismissingSection = false);
      return;
    }

    try {
      // Create early dismissal record
      final dismissalData = {
        'section_id': widget.sectionId,
        'dismissed_by': user.id,
        'dismissal_type': 'section',
        'reason': reason,
        'status': 'active',
        'dismissed_at': DateTime.now().toIso8601String(),
      };

      final dismissalResult = await supabase
          .from('early_dismissals')
          .insert(dismissalData)
          .select()
          .single();

      // Add all current students to the early dismissal
      final studentsToAdd = students.map((s) => {
        'early_dismissal_id': dismissalResult['id'],
        'student_id': s['id'],
        'dismissed_at': DateTime.now().toIso8601String(),
      }).toList();

      if (studentsToAdd.isNotEmpty) {
        await supabase
            .from('early_dismissal_students')
            .insert(studentsToAdd);
      }

      await _loadEarlyDismissalStatus();

      // Log the early dismissal creation
      await teacherAuditService.logEarlyDismissal(
        studentId: 'section_${widget.sectionId}', // For section-wide dismissals
        studentName: 'Entire Section',
        sectionId: widget.sectionId.toString(),
        sectionName: widget.sectionName,
        dismissalTime: DateTime.now().toIso8601String(),
        reason: reason,
        fetcherName: 'Section-wide dismissal',
        notes: 'Early dismissal applied to all ${students.length} students in section',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Section dismissed early. Students can now tap out."),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error creating early dismissal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating early dismissal: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isDismissingSection = false);
    }
  }

  // End early dismissal
  Future<void> _endEarlyDismissal() async {
    if (activeEarlyDismissal == null) return;

    try {
      await supabase
          .from('early_dismissals')
          .update({'status': 'completed'})
          .eq('id', activeEarlyDismissal!['id']);

      await _loadEarlyDismissalStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Early dismissal ended."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error ending early dismissal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error ending early dismissal: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show early dismissal dialog
  void _showEarlyDismissalDialog() {
    final reasons = [
      'Emergency drill',
      'Weather conditions',
      'School event',
      'Technical issues',
      'Other',
    ];
    String? selectedReason = reasons[0];
    TextEditingController customReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text("Early Dismissal"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Dismiss the entire section early. Students will be allowed to tap out immediately.",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              "Reason for early dismissal:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedReason,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: reasons.map((reason) => DropdownMenuItem(
                value: reason,
                child: Text(reason),
              )).toList(),
              onChanged: (value) => selectedReason = value,
            ),
            if (selectedReason == 'Other') ...[
              SizedBox(height: 12),
              TextField(
                controller: customReasonController,
                decoration: InputDecoration(
                  hintText: "Enter custom reason...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = selectedReason == 'Other' 
                  ? customReasonController.text.trim()
                  : selectedReason ?? 'No reason provided';
              
              if (reason.isNotEmpty) {
                Navigator.of(ctx).pop();
                _createSectionEarlyDismissal(reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text("Dismiss Section"),
          ),
        ],
      ),
    );
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

    List<String> affectedStudents = [];
    int markedCount = 0;

    for (final stu in students) {
      final currentAttendance = _getCurrentAttendanceStatus(stu['id']);
      final scan = todayScan[stu['id']];
      // Only mark as present if they haven't tapped RFID and are currently absent
      if (currentAttendance == "Absent" && scan == null) {
        await _markAttendance(stu['id'], "Present");
        affectedStudents.add('${stu['fname']} ${stu['lname']}');
        markedCount++;
      }
    }

    // Log the bulk operation
    if (markedCount > 0) {
      final today = DateTime.now();
      final todayDateStr = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      
      await teacherAuditService.logBulkAttendanceOperation(
        sectionId: widget.sectionId.toString(),
        sectionName: widget.sectionName,
        operation: 'mark_all_present',
        affectedStudentCount: markedCount,
        date: todayDateStr,
        affectedStudents: affectedStudents.map((name) => {
          'student_name': name,
          'new_status': 'present',
        }).toList(),
      );
    }
  }

  // Add helper method to get current attendance status (including pending changes)
  String _getCurrentAttendanceStatus(int studentId) {
    // Check pending attendance first (local changes not yet saved)
    if (pendingAttendance.containsKey(studentId)) {
      return pendingAttendance[studentId]!['status'];
    }
    
    // Check existing attendance records in database
    final att = todayAttendance[studentId];
    if (att != null) {
      return att['status'];
    }
    
    // Default logic for students without attendance records
    
    // Default logic for students without attendance records
    
    // If attendance is not active (not a class day/time), don't mark as absent yet
    if (!attendanceActive) {
      return "Not Marked";
    }
    
    // If class time has ended, the automatic absence marking will handle creating records
    // This method just reflects what's already in the database or pending changes
    // Students without records during active attendance time are "Not Marked"
    return "Not Marked";
  }

  // Check if student was auto-marked via RFID (exclude auto-absence from indicator)
  bool _isAutoMarked(int studentId) {
    // Check pending attendance first
    if (pendingAttendance.containsKey(studentId)) {
      final notes = pendingAttendance[studentId]!['notes']?.toString() ?? '';
      final status = pendingAttendance[studentId]!['status'];
      // Only show auto indicator for non-absent statuses
      return notes.contains('Auto-marked via RFID') && status != 'Absent';
    }
    
    // Check existing attendance
    final att = todayAttendance[studentId];
    if (att != null) {
      final notes = att['notes']?.toString() ?? '';
      final status = att['status'];
      // Only show auto indicator for non-absent statuses
      return notes.contains('Auto-marked via RFID') && status != 'Absent';
    }
    
    return false;
  }

  // Modified summary method to include pending changes
  Map<String, int> _getSummary() {
    int present = 0, late = 0, absent = 0, excused = 0, emergency = 0, notMarked = 0, total = students.length;
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
      else if (status == "Not Marked")
        notMarked++;
      else
        absent++;
    }
    return {
      'Present': present,
      'Late': late,
      'Absent': absent,
      'Excused': excused,
      'Emergency Exit': emergency,
      'Not Marked': notMarked,
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
          // Get student name for audit logging
          final student = students.firstWhere(
            (s) => s['id'] == attendance['student_id'],
            orElse: () => {'fname': 'Unknown', 'lname': 'Student'},
          );
          final studentName = '${student['fname']} ${student['lname']}';
          final studentId = attendance['student_id'].toString();
          final status = attendance['status'];
          final date = attendance['date'];
          final notes = attendance['notes'];

          // Check if this is an update or new record
          final existingAttendance = todayAttendance[attendance['student_id']];
          final previousStatus = existingAttendance?['status'];

          // Use upsert with onConflict to handle existing records
          await supabase.from('section_attendance').upsert(
            attendance,
            onConflict: 'section_id, student_id, date',
          );

          // Log the attendance action
          await teacherAuditService.logAttendanceMarking(
            studentId: studentId,
            studentName: studentName,
            sectionId: widget.sectionId.toString(),
            sectionName: widget.sectionName,
            status: status,
            date: date,
            previousStatus: previousStatus,
            notes: notes,
            isRfidAssisted: false, // Manual attendance submission
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
      // Get student information for audit logging
      final student = students.firstWhere(
        (s) => s['id'] == studentId,
        orElse: () => {'fname': 'Unknown', 'lname': 'Student'},
      );
      final studentName = '${student['fname']} ${student['lname']}';
      final reason = notesController.text.trim().isEmpty
          ? "Emergency exit - no details provided"
          : notesController.text.trim();

      await _markAttendance(
        studentId,
        "Emergency Exit",
        notes: reason,
      );

      // Log the emergency exit
      await teacherAuditService.logEmergencyExit(
        studentId: studentId.toString(),
        studentName: studentName,
        sectionId: widget.sectionId.toString(),
        sectionName: widget.sectionName,
        emergencyType: 'safety', // Default emergency type
        reason: reason,
        notes: 'Emergency exit logged by teacher',
      );
    }
  }

  // Export today's attendance as Excel file
  Future<void> _exportTodayAttendance() async {
    try {
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No students found to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Generate filename and log export action
      final today = DateTime.now();
      final todayLabel = DateFormat('yyyy-MM-dd').format(today);
      final fileName = '${widget.sectionName}_Attendance_${todayLabel}.xlsx';
      
      await teacherAuditService.logTeacherAttendanceExport(
        sectionId: widget.sectionId.toString(),
        sectionName: widget.sectionName,
        exportType: 'daily_attendance_report',
        fileName: fileName,
        recordCount: students.length,
        dateRange: todayLabel,
      );

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Generating attendance report...'),
                ],
              ),
            ),
          );
        },
      );

      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();

      // Create Today's Attendance sheet
      var attendanceSheet = excel['Today\'s Attendance'];
      await _createTodayAttendanceSheet(attendanceSheet);

      // Create Summary sheet
      var summarySheet = excel['Summary'];
      await _createTodaySummarySheet(summarySheet);

      // Clean up: Remove any default sheets
      final defaultSheetNames = ['Sheet1', 'Sheet', 'Worksheet'];
      for (String defaultName in defaultSheetNames) {
        if (excel.sheets.containsKey(defaultName)) {
          excel.delete(defaultName);
        }
      }

      // Set Today's Attendance as the default sheet
      excel.setDefaultSheet('Today\'s Attendance');

      // Generate and download file
      List<int>? fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Download file
      final blob = html.Blob([
        fileBytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance report exported successfully: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create Today's Attendance sheet with detailed attendance data
  Future<void> _createTodayAttendanceSheet(excel_lib.Sheet sheet) async {
    int rowIndex = 0;
    final today = DateTime.now();
    final todayLabel = DateFormat('EEEE, MMMM d, yyyy').format(today);

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'DAILY ATTENDANCE REPORT - ${widget.sectionName}',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Report info
    var reportInfos = [
      ['Section:', widget.sectionName],
      ['Date:', todayLabel],
      ['Class Schedule:', _getClassScheduleString()],
      ['Today is Class Day:', isTodayClassDay ? 'Yes' : 'No'],
      ['Generated On:', DateFormat('yyyy-MM-dd h:mm a').format(DateTime.now())],
      ['Generated By:', _getCurrentUserName()],
    ];

    for (var info in reportInfos) {
      var labelCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      labelCell.value = excel_lib.TextCellValue(info[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      );
      valueCell.value = excel_lib.TextCellValue(info[1]);
      rowIndex++;
    }
    rowIndex++;

    // Headers
    final headers = [
      'Student Name',
      'Attendance Status',
      'Time',
    ];

    for (int i = 0; i < headers.length; i++) {
      var headerCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: rowIndex,
        ),
      );
      headerCell.value = excel_lib.TextCellValue(headers[i]);
      headerCell.cellStyle = excel_lib.CellStyle(bold: true);
    }
    rowIndex++;

    // Student data rows
    for (final student in students) {
      final studentId = student['id'] as int;
      final fullName = '${student['fname']} ${student['lname']}';
      final status = _getCurrentAttendanceStatus(studentId);
      final scan = todayScan[studentId];
      final attendance = _getCurrentAttendanceRecord(studentId);
      
      // Determine time to display based on attendance status
      String timeToShow = '';
      if (status == 'Present' || status == 'Late') {
        // For Present/Late, prefer attendance marked time, fallback to RFID tap time
        if (attendance?['marked_at'] != null) {
          timeToShow = DateFormat('h:mm a').format(DateTime.parse(attendance!['marked_at']));
        } else if (scan != null) {
          timeToShow = DateFormat('h:mm a').format(DateTime.parse(scan['scan_time']));
        }
      } else if (status == 'Excused' || status == 'Emergency Exit') {
        // For Excused/Emergency Exit, show when it was marked
        if (attendance?['marked_at'] != null) {
          timeToShow = DateFormat('h:mm a').format(DateTime.parse(attendance!['marked_at']));
        }
      }
      // For Absent or Not Marked, leave time empty (no meaningful time to show)

      final rowData = [
        fullName,
        status,
        timeToShow,
      ];

      for (int i = 0; i < rowData.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: rowIndex,
          ),
        );
        cell.value = excel_lib.TextCellValue(rowData[i]);
      }
      rowIndex++;
    }

    // Auto-resize columns
    final columnWidths = [25.0, 18.0, 15.0]; // Student Name, Attendance Status, Time
    for (int i = 0; i < columnWidths.length; i++) {
      sheet.setColumnWidth(i, columnWidths[i]);
    }
  }

  // Create Summary sheet with attendance statistics
  Future<void> _createTodaySummarySheet(excel_lib.Sheet sheet) async {
    int rowIndex = 0;
    final today = DateTime.now();
    final todayLabel = DateFormat('EEEE, MMMM d, yyyy').format(today);
    final summary = _getSummary();

    // Title
    var titleCell = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    titleCell.value = excel_lib.TextCellValue(
      'ATTENDANCE SUMMARY - ${widget.sectionName}',
    );
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Report info
    var reportInfos = [
      ['Section:', widget.sectionName],
      ['Date:', todayLabel],
      ['Class Schedule:', _getClassScheduleString()],
      ['Today is Class Day:', isTodayClassDay ? 'Yes' : 'No'],
      ['Attendance Active:', attendanceActive ? 'Yes' : 'No'],
    ];

    for (var info in reportInfos) {
      var labelCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      labelCell.value = excel_lib.TextCellValue(info[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      );
      valueCell.value = excel_lib.TextCellValue(info[1]);
      rowIndex++;
    }
    rowIndex++;

    // Attendance Statistics
    var statsHeader = sheet.cell(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    statsHeader.value = excel_lib.TextCellValue('ATTENDANCE STATISTICS');
    statsHeader.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
    rowIndex += 2;

    var attendanceStats = [
      ['Present', summary['Present']],
      ['Late', summary['Late']],
      ['Absent', summary['Absent']],
      ['Excused', summary['Excused']],
      ['Emergency Exit', summary['Emergency Exit']],
      ['Not Marked', summary['Not Marked']],
      ['Total Students', summary['Total']],
    ];

    for (var stat in attendanceStats) {
      var labelCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: rowIndex,
        ),
      );
      labelCell.value = excel_lib.TextCellValue(stat[0] as String);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(
        excel_lib.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: rowIndex,
        ),
      );
      valueCell.value = excel_lib.IntCellValue(stat[1] as int);
      rowIndex++;
    }

    // Auto-resize columns
    sheet.setColumnWidth(0, 20.0);
    sheet.setColumnWidth(1, 15.0);
  }

  // Helper methods for Excel generation
  String _getClassScheduleString() {
    if (scheduleString != null && scheduleString!.isNotEmpty) {
      return scheduleString!;
    }
    if (classDays.isNotEmpty && startTime != null && endTime != null) {
      return '${classDays.join(", ")} ${_shortTime(startTime!.format(context))} - ${_shortTime(endTime!.format(context))}';
    }
    return 'No schedule information';
  }

  String _getCurrentUserName() {
    final user = supabase.auth.currentUser;
    if (user?.userMetadata?['fname'] != null &&
        user?.userMetadata?['lname'] != null) {
      return '${user!.userMetadata!['fname']} ${user.userMetadata!['lname']}';
    }
    return user?.email ?? 'Unknown User';
  }

  Map<String, dynamic>? _getCurrentAttendanceRecord(int studentId) {
    // Check pending attendance first
    if (pendingAttendance.containsKey(studentId)) {
      return pendingAttendance[studentId];
    }
    // Check existing attendance
    return todayAttendance[studentId];
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
                                                color: Color(0xFF2563EB),
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
                              Icons.refresh,
                              color: Color(0xFF2563EB),
                              size: 18,
                            ),
                            label: const Text(
                              "Refresh RFID",
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: _checkForNewRfidTaps,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF2563EB),
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
                        const SizedBox(width: 12),
                        // Export button with student management styling
                        Tooltip(
                          message: isTodayClassDay 
                            ? "Export today's attendance to Excel"
                            : "Export is only available on class days",
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              icon: Icon(
                                Icons.file_download_outlined,
                                color: isTodayClassDay 
                                  ? const Color(0xFF2ECC71) 
                                  : Colors.grey,
                                size: 18,
                              ),
                              label: Text(
                                "Export",
                                style: TextStyle(
                                  color: isTodayClassDay 
                                    ? const Color(0xFF2ECC71) 
                                    : Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onPressed: isTodayClassDay ? _exportTodayAttendance : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: isTodayClassDay 
                                    ? const Color(0xFF2ECC71) 
                                    : Colors.grey,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: isTodayClassDay ? 1 : 0,
                                shadowColor: Colors.black.withOpacity(0.05),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Class status information is shown below if needed
                  // Status message if attendance is not active
                  if (!attendanceActive) ...[
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
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  "Not Marked",
                                  summary['Not Marked']!,
                                  const Color(0xFF757575),
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
                                              "Not Marked",
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
                                const SizedBox(width: 12),
                                // Early Dismissal Button
                                if (attendanceActive && !hasActiveEarlyDismissal)
                                  ElevatedButton.icon(
                                    icon: isDismissingSection
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Icon(Icons.exit_to_app, size: 16),
                                    label: Text(isDismissingSection ? "Dismissing..." : "Early Dismissal"),
                                    onPressed: isDismissingSection ? null : _showEarlyDismissalDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
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
                                // End Early Dismissal Button
                                if (hasActiveEarlyDismissal)
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.stop, size: 16),
                                    label: Text("End Early Dismissal"),
                                    onPressed: _endEarlyDismissal,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
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
                                const Spacer(),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.wifi_tethering,
                                        color: const Color(0xFF19AE61),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "RFID Auto-Attendance Active",
                                          style: TextStyle(
                                            color: const Color(0xFF19AE61),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "• Students are automatically marked Present/Late when they tap their RFID card\n• System checks for new taps every 30 seconds\n• Use 'Refresh RFID' button to check immediately\n• Manual buttons below override automatic attendance",
                                    style: TextStyle(
                                      color: const Color(0xFF2E7D32),
                                      fontSize: 12,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Early Dismissal Status Indicator
                            if (hasActiveEarlyDismissal) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.exit_to_app,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Early Dismissal Active",
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "• Section dismissed early: ${activeEarlyDismissal?['reason'] ?? 'No reason provided'}\n• Students can now tap out at any time\n• Guard verification will show early dismissal indicator",
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
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
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        _StatusBadge(
                                                          status: status,
                                                        ),
                                                        // Show auto-marked indicator if student was auto-marked via RFID
                                                        if (_isAutoMarked(s['id']))
                                                          Container(
                                                            margin: const EdgeInsets.only(top: 2),
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF19AE61).withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  Icons.auto_mode,
                                                                  size: 10,
                                                                  color: const Color(0xFF19AE61),
                                                                ),
                                                                const SizedBox(width: 2),
                                                                Text(
                                                                  "Auto",
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    color: const Color(0xFF19AE61),
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
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
      case "Not Marked":
        color = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF757575);
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
