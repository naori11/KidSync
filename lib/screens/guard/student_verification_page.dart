import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';
import 'dart:async';
import '../../models/guard_models.dart';
import '../../services/notification_service.dart';
import '../../services/guard_audit_service.dart';

final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;

class StudentVerificationPage extends StatefulWidget {
  const StudentVerificationPage({super.key});

  @override
  State<StudentVerificationPage> createState() =>
      _StudentVerificationPageState();
}

class _StudentVerificationPageState extends State<StudentVerificationPage> {
  Student? scannedStudent;
  List<Fetcher>? fetchers;
  String? fetchStatus;
  bool showNotification = false;
  String notificationMessage = '';
  Color notificationColor = Colors.green;
  DateTime? actionTimestamp;
  bool isLoadingStudent = false;
  bool isLoadingFetchers = false;
  Map<String, dynamic>? verifiedTempFetcher;
  bool isShowingTempFetcher = false;

  // Token to make auto-clear timers specific to a scan
  String? activeScanToken;

  // Remove isEntryMode and isAwaitingDecision - replaced with auto detection
  String? currentAction; // 'entry' or 'exit'
  String? currentScanner; // Track which scanner was used for current scan
  bool isScheduleValidationEnabled = true;
  bool isOverrideMode = false;
  String? scheduleValidationMessage;
  TimeOfDay? lastClassEndTime;
  Map<String, dynamic>? currentScheduleCheck; // Store the schedule check result

  // Guard override mode variables
  DateTime? _overrideModeStartTime;
  List<Student>? _searchResults;
  bool _isSearching = false;
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  late HtmlWebSocketChannel channel;
  final NotificationService _notificationService = NotificationService();
  final GuardAuditService _guardAuditService = GuardAuditService();

  // Make cooldown tracking static so it persists across page navigations
  static Map<String, DateTime> rfidCooldowns = {};
  static const int cooldownSeconds = 30; // 30 second cooldown

  // Scanner tracking - prevent consecutive taps on same scanner
  static Map<String, String> lastScannerPerRfid = {}; // rfid_uid -> last_scanner
  static Map<String, DateTime> lastScanTimePerRfid = {}; // rfid_uid -> last_scan_time
  static const int scannerCooldownSeconds = 5; // 5 second cooldown for same scanner

  @override
  void initState() {
    super.initState();
    // Log guard dashboard access
    _guardAuditService.logDashboardAccess();
    
    // Initialize WebSocket channel
    try {
      channel = HtmlWebSocketChannel.connect(
        'wss://rfid-websocket-server.onrender.com',
      );
      
      // Log successful RFID system connection
      _guardAuditService.logRFIDSystemAccess(
        accessType: 'websocket_connect',
        connectionDetails: 'Connected to RFID WebSocket server',
        isSuccessful: true,
      );
    } catch (e) {
      // Log failed RFID system connection
      _guardAuditService.logRFIDSystemAccess(
        accessType: 'websocket_connect',
        connectionDetails: 'Failed to connect to RFID WebSocket server',
        isSuccessful: false,
        errorDetails: e.toString(),
      );
      rethrow;
    }

    // Listen for incoming RFID data
    channel.stream.listen((message) async {
      print("RFID received: $message");

      try {
        String? uid;
        String? scanner;

        // Try to parse as JSON first
        try {
          final Map<String, dynamic> parsedMessage = json.decode(message);
          if (parsedMessage['type'] == 'rfid_scan' &&
              parsedMessage['uid'] != null) {
            uid = parsedMessage['uid'];
            scanner = parsedMessage['scanner']; // Extract scanner info
          }
        } catch (jsonError) {
          // If JSON parsing fails, treat the message as a raw UID string
          String rawData = message.toString().trim();
          if (rawData.isNotEmpty && rawData.length > 4) {
            uid = rawData;
            // No scanner info available for legacy format
            scanner = null;
          }
        }

        if (uid != null) {
          // Log RFID scan attempt with scanner info
          _guardAuditService.logRFIDScanAttempt(
            rfidUid: uid,
            isSuccessful: true,
            scanMetadata: {
              'raw_message': message.toString(),
              'scan_source': 'websocket',
              'scanner': scanner ?? 'unknown',
            },
          );
          
          // Check if this is a guard RFID card first
          await _checkGuardRFID(uid, scanner: scanner);
        } else {
          // Log failed RFID scan
          _guardAuditService.logRFIDScanAttempt(
            rfidUid: 'unknown',
            isSuccessful: false,
            failureReason: 'Invalid RFID message format',
            scanMetadata: {
              'raw_message': message.toString(),
              'scan_source': 'websocket',
            },
          );
        }
      } catch (e) {
        print('Error processing WebSocket message: $e');
        
        // Log RFID scan processing error
        _guardAuditService.logSystemError(
          errorType: 'rfid_processing_error',
          errorDescription: 'Failed to process RFID WebSocket message',
          systemComponent: 'websocket',
          errorDetails: {
            'raw_message': message.toString(),
            'error': e.toString(),
          },
        );
        
        _showErrorNotification('Error processing RFID scan');
      }
    });
  }

  @override
  void dispose() {
    // Log WebSocket disconnection
    _guardAuditService.logRFIDSystemAccess(
      accessType: 'websocket_disconnect',
      connectionDetails: 'Disconnecting from RFID WebSocket server',
      isSuccessful: true,
    );
    
    _searchController.dispose();
    
    channel.sink.close();
    super.dispose();
  }

  // Check today's attendance status to determine entry/exit
  Future<String> _checkTodayAttendanceStatus(int studentId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    try {
      final response = await supabase
          .from('scan_records')
          .select('action, scan_time')
          .eq('student_id', studentId)
          .gte('scan_time', startOfDay.toIso8601String())
          .lt('scan_time', endOfDay.toIso8601String())
          .order('scan_time', ascending: true);

      if (response.isEmpty) {
        return 'entry'; // No records today, this is entry
      }

      // Check the latest record
      final records = response as List;
      final latestRecord = records.last;
      final latestAction = latestRecord['action'];

      if (latestAction == 'entry') {
        return 'exit'; // Last action was entry, so this should be exit
      } else if (latestAction == 'exit') {
        return 'entry'; // Last action was successful exit, so this should be entry
      } else {
        // Last action was 'denied' - student is still inside, so this should be exit
        return 'exit'; // Keep trying to exit until successful
      }
    } catch (e) {
      print('Error checking attendance status: $e');
      return 'entry'; // Default to entry on error
    }
  }

  // Enhanced exit validation with specific time-based rules
  Future<Map<String, dynamic>> _checkClassSchedule(Student student) async {
    try {
      final now = DateTime.now();
      final today = _getCurrentDayName();
      final currentTime = TimeOfDay.fromDateTime(now);

      print(
        'Checking schedule for section_id: ${student.sectionId}, day: $today',
      );

      // First check for early dismissal
      final earlyDismissalStatus = await _checkEarlyDismissal(student.sectionId);
      if (earlyDismissalStatus['hasEarlyDismissal']) {
        print('Early dismissal is active, allowing exit');
        return {
          'canExit': true,
          'message': 'Early dismissal active: ${earlyDismissalStatus['reason']}',
          'exitType': 'early_dismissal',
          'earlyDismissal': earlyDismissalStatus,
        };
      }

      // Check for emergency exit status in attendance
      final emergencyExitStatus = await _checkEmergencyExitStatus(student.id);
      if (emergencyExitStatus['isEmergencyExit']) {
        print('Student marked as Emergency Exit, allowing exit');
        return {
          'canExit': true,
          'message': 'Emergency Exit approved by teacher',
          'exitType': 'emergency_exit',
          'emergencyExit': emergencyExitStatus,
        };
      }

      // Query the section_teachers table for today's classes
      if (student.sectionId == null) {
        print('No section ID found, allowing exit');
        return {'canExit': true, 'message': null, 'exitType': 'regular'};
      }

      final response = await supabase
          .from('section_teachers')
          .select('''
            end_time, 
            subject, 
            start_time,
            users!section_teachers_teacher_id_fkey(fname, lname)
          ''')
          .eq('section_id', student.sectionId!)
          .contains('days', [today])
          .order('end_time', ascending: false);

      print('Schedule response: $response');
      print('Checking for classes on day: $today');

      if (response.isNotEmpty) {
        print('Found ${response.length} classes today');
        
        // Find current ongoing class (if any)
        Map<String, dynamic>? currentClass;
        Map<String, dynamic>? nextClass;
        
        for (final classInfo in response) {
          final startTimeStr = classInfo['start_time'];
          final endTimeStr = classInfo['end_time'];
          
          if (startTimeStr != null && endTimeStr != null) {
            final startTime = _parseTimeString(startTimeStr);
            final endTime = _parseTimeString(endTimeStr);
            final minutesFromStart = _getMinutesDifference(startTime, currentTime);
            final minutesUntilEnd = _getMinutesDifference(currentTime, endTime);
            
            // Check if current time is within this class period
            if (minutesFromStart <= 0 && minutesUntilEnd > 0) {
              currentClass = classInfo;
              break;
            }
            
            // If no current class, find the next class
            if (currentClass == null && minutesUntilEnd > 0) {
              nextClass = classInfo;
            }
          }
        }
        
        // Get the last class of the day for overall validation
        final lastClass = response.first;
        final endTimeStr = lastClass['end_time']; // Format: "HH:MM:SS"
        final subjectName = lastClass['subject'];
        final teacherInfo = lastClass['users'];
        final teacherName = teacherInfo != null 
            ? "${teacherInfo['fname'] ?? ''} ${teacherInfo['lname'] ?? ''}".trim()
            : 'Unknown Teacher';

        if (endTimeStr != null) {
          final endTime = _parseTimeString(endTimeStr);
          final minutesUntilEnd = _getMinutesDifference(currentTime, endTime);

          print('Current time: ${_formatTime(currentTime)}');
          print('Last class ends: ${_formatTime(endTime)}');
          print('Minutes until end: $minutesUntilEnd');
          print('Subject: $subjectName');

          // Determine what class info to show
          String classDisplayInfo;
          String teacherDisplayInfo;
          
          if (currentClass != null) {
            classDisplayInfo = currentClass['subject'] ?? 'Unknown Subject';
            final currentTeacher = currentClass['users'];
            teacherDisplayInfo = currentTeacher != null 
                ? "${currentTeacher['fname'] ?? ''} ${currentTeacher['lname'] ?? ''}".trim()
                : 'Unknown Teacher';
          } else if (nextClass != null) {
            classDisplayInfo = nextClass['subject'] ?? 'Unknown Subject';
            final nextTeacher = nextClass['users'];
            teacherDisplayInfo = nextTeacher != null 
                ? "${nextTeacher['fname'] ?? ''} ${nextTeacher['lname'] ?? ''}".trim()
                : 'Unknown Teacher';
          } else {
            classDisplayInfo = subjectName ?? 'Unknown Subject';
            teacherDisplayInfo = teacherName;
          }

          // Exit validation logic - all blocks now show current/next class info
          if (minutesUntilEnd > 0) {
            // Classes are still ongoing - block exit
            return {
              'canExit': false,
              'message': 'Student is not allowed to exit school grounds yet',
              'detailedMessage': 'Classes are still ongoing until ${_formatTime(endTime)}',
              'currentClass': classDisplayInfo,
              'currentTeacher': teacherDisplayInfo,
              'lastClassEndTime': endTime,
              'subject': subjectName,
              'exitType': minutesUntilEnd > 120 ? 'very_early' : 
                          minutesUntilEnd > 30 ? 'early' : 
                          minutesUntilEnd > 15 ? 'near_end' : 'within_15min',
              'requiresReason': minutesUntilEnd > 120,
            };
          } else {
            // Classes are finished (minutesUntilEnd <= 0)
            print('Classes are finished, allowing regular exit');
            return {
              'canExit': true,
              'message': 'Classes finished. Last class ($subjectName) ended at ${_formatTime(endTime)}',
              'exitType': 'regular',
              'subject': subjectName,
            };
          }
        }
      } else {
        print('No classes found for today ($today), allowing exit');
      }

      // Regular dismissal (after last class or no classes today)
      print('Allowing regular dismissal - no restrictions');
      return {'canExit': true, 'message': null, 'exitType': 'regular'};
    } catch (e) {
      print('Error checking schedule: $e');
      return {'canExit': true, 'message': null, 'exitType': 'error'};
    }
  }

  // Check for active early dismissal for the student's section
  Future<Map<String, dynamic>> _checkEarlyDismissal(int? sectionId) async {
    if (sectionId == null) {
      return {'hasEarlyDismissal': false};
    }

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      // Check for active early dismissals for this section today
      final dismissals = await supabase
          .from('early_dismissals')
          .select('*')
          .eq('section_id', sectionId)
          .eq('status', 'active')
          .gte('dismissed_at', startOfDay.toIso8601String())
          .lt('dismissed_at', endOfDay.toIso8601String())
          .order('dismissed_at', ascending: false)
          .limit(1);

      if (dismissals.isNotEmpty) {
        final dismissal = dismissals[0];
        return {
          'hasEarlyDismissal': true,
          'dismissalId': dismissal['id'],
          'reason': dismissal['reason'] ?? 'No reason provided',
          'dismissedAt': dismissal['dismissed_at'],
          'dismissedBy': dismissal['dismissed_by'],
          'dismissalType': dismissal['dismissal_type'],
        };
      }

      return {'hasEarlyDismissal': false};
    } catch (e) {
      print('Error checking early dismissal: $e');
      return {'hasEarlyDismissal': false};
    }
  }

  // Check for emergency exit status in today's attendance
  Future<Map<String, dynamic>> _checkEmergencyExitStatus(int studentId) async {
    try {
      final today = DateTime.now();
      final todayDateStr = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Check section_attendance for Emergency Exit status today
      final attendanceResponse = await supabase
          .from('section_attendance')
          .select('''
            *,
            sections!inner(name),
            users!section_attendance_marked_by_fkey(fname, lname)
          ''')
          .eq('student_id', studentId)
          .eq('date', todayDateStr)
          .eq('status', 'Emergency Exit')
          .maybeSingle();

      if (attendanceResponse != null) {
        return {
          'isEmergencyExit': true,
          'attendanceId': attendanceResponse['id'],
          'markedAt': attendanceResponse['marked_at'],
          'markedBy': attendanceResponse['users'],
          'notes': attendanceResponse['notes'],
          'sectionName': attendanceResponse['sections']['name'],
        };
      }

      return {'isEmergencyExit': false};
    } catch (e) {
      print('Error checking emergency exit status: $e');
      return {'isEmergencyExit': false};
    }
  }

  // Log early dismissal exit when student actually leaves
  Future<void> _logEarlyDismissalExit(int studentId, Map<String, dynamic> earlyDismissalInfo) async {
    try {
      // Update the early_dismissal_students table to mark when student actually exited
      await supabase
          .from('early_dismissal_students')
          .update({'exited_at': DateTime.now().toIso8601String()})
          .eq('early_dismissal_id', earlyDismissalInfo['dismissalId'])
          .eq('student_id', studentId);

      print('Logged early dismissal exit for student $studentId');
    } catch (e) {
      print('Error logging early dismissal exit: $e');
    }
  }

  // Log emergency exit completion
  Future<void> _logEmergencyExitCompletion(int studentId, Map<String, dynamic> emergencyExitInfo) async {
    try {
      // Update the section_attendance record to add exit timestamp in notes
      final currentNotes = emergencyExitInfo['notes'] ?? '';
      final exitTimestamp = DateTime.now().toIso8601String();
      final updatedNotes = currentNotes.isEmpty 
          ? 'Emergency exit completed at $exitTimestamp'
          : '$currentNotes - Exit completed at $exitTimestamp';

      await supabase
          .from('section_attendance')
          .update({'notes': updatedNotes})
          .eq('id', emergencyExitInfo['attendanceId']);

      print('Logged emergency exit completion for student $studentId');
    } catch (e) {
      print('Error logging emergency exit completion: $e');
    }
  }

  // Helper method to calculate minutes difference between two times
  int _getMinutesDifference(TimeOfDay current, TimeOfDay target) {
    final currentMinutes = current.hour * 60 + current.minute;
    final targetMinutes = target.hour * 60 + target.minute;
    return targetMinutes - currentMinutes;
  }

  // Helper method to format TimeOfDay to string
  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  // Helper method to parse time string to TimeOfDay
  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  // Helper method to get current day name
  String _getCurrentDayName() {
    final now = DateTime.now();
    final dayNames = [
      'Sun',    // Sunday = 0
      'Mon',    // Monday = 1  
      'Tue',    // Tuesday = 2
      'Wed',    // Wednesday = 3
      'Thu',    // Thursday = 4
      'Fri',    // Friday = 5
      'Sat',    // Saturday = 6
    ];
    return dayNames[now.weekday % 7];
  }

  // New method that includes scanner validation before processing student RFID
  Future<void> _fetchStudentByRFIDWithValidation(String rfidUid, {String? scanner}) async {
    print('Validating scanner access for RFID: $rfidUid, Scanner: ${scanner ?? "unknown"}');
    
    // First check if student exists
    try {
      final studentResponse = await supabase
          .from('students')
          .select('id, fname, lname, rfid_uid, status')
          .eq('rfid_uid', rfidUid)
          .neq('status', 'deleted')  // Changed from .eq('status', 'active') to match original logic
          .maybeSingle();

      if (studentResponse == null) {
        _showErrorNotification('Student not found or inactive');
        return;
      }

      final studentId = studentResponse['id'] as int;
      final studentName = '${studentResponse['fname']} ${studentResponse['lname']}';
      
      // Check today's scan records to determine current status
      final todayStatus = await _checkTodayAttendanceStatus(studentId);
      print('Student $studentName current status: $todayStatus');
      
      // Validate scanner usage based on student status and scanner type
      final validationResult = _validateScannerUsage(todayStatus, scanner);
      
      if (!validationResult['isValid']) {
        // Log invalid scanner usage attempt
        _guardAuditService.logRFIDScanAttempt(
          rfidUid: rfidUid,
          studentId: studentId.toString(),
          studentName: studentName,

          isSuccessful: false,
          failureReason: validationResult['message'],
        );
        
        _showErrorNotification(validationResult['message']);
        return;
      }
      
      // Validation passed, proceed with normal RFID processing
      await _fetchStudentByRFID(rfidUid, scanner: scanner);
      
    } catch (e) {
      print('Error validating student RFID: $e');
      _showErrorNotification('Error validating student access: ${e.toString()}');
    }
  }

  // Validate if the scanner usage is appropriate for student's current status
  Map<String, dynamic> _validateScannerUsage(String expectedAction, String? scanner) {
    // If no scanner info available, allow processing (backward compatibility)
    if (scanner == null) {
      return {'isValid': true, 'message': 'Scanner validation skipped - no scanner info'};
    }
    
    // Check scanner and expected action compatibility
    if (expectedAction == 'entry') {
      if (scanner == 'entry') {
        return {'isValid': true, 'message': 'Valid entry scanner usage'};
      } else {
        return {
          'isValid': false, 
          'message': 'Student needs to check IN first. Please use the ENTRY scanner.'
        };
      }
    } else if (expectedAction == 'exit') {
      if (scanner == 'exit') {
        return {'isValid': true, 'message': 'Valid exit scanner usage'};
      } else {
        return {
          'isValid': false, 
          'message': 'Student is already checked in. Please use the EXIT scanner to check out.'
        };
      }
    }
    
    // Default case - allow processing
    return {'isValid': true, 'message': 'Scanner validation passed'};
  }
  Future<void> _fetchStudentByRFID(String rfidUid, {String? scanner}) async {
    _cleanupCooldowns();

    final now = DateTime.now();

    // Check general cooldown (existing logic)
    if (rfidCooldowns.containsKey(rfidUid)) {
      final lastScan = rfidCooldowns[rfidUid]!;
      final timeDiff = now.difference(lastScan).inSeconds;

      if (timeDiff < cooldownSeconds) {
        final remainingTime = cooldownSeconds - timeDiff;
        
        // Log cooldown blocked scan attempt
        _guardAuditService.logRFIDScanAttempt(
          rfidUid: rfidUid,
          isSuccessful: false,
          failureReason: 'Scan cooldown active ($remainingTime seconds remaining)',
          scanMetadata: {
            'last_scan_time': lastScan.toIso8601String(),
            'cooldown_seconds': cooldownSeconds,
            'remaining_seconds': remainingTime,
            'scanner': scanner ?? 'unknown',
          },
        );
        
        _showErrorNotification(
          'Please wait ${remainingTime}s before scanning again',
        );
        return;
      }
    }

    // New scanner-specific validation
    if (scanner != null && lastScannerPerRfid.containsKey(rfidUid)) {
      final lastScanner = lastScannerPerRfid[rfidUid]!;
      final lastScanTime = lastScanTimePerRfid[rfidUid];
      
      // Check if same scanner was used recently
      if (lastScanner == scanner && lastScanTime != null) {
        final timeDiff = now.difference(lastScanTime).inSeconds;
        
        if (timeDiff < scannerCooldownSeconds) {
          final remainingTime = scannerCooldownSeconds - timeDiff;
          
          // Log scanner-specific blocked scan
          _guardAuditService.logRFIDScanAttempt(
            rfidUid: rfidUid,
            isSuccessful: false,
            failureReason: 'Same scanner used consecutively (${remainingTime}s cooldown remaining)',
            scanMetadata: {
              'current_scanner': scanner,
              'last_scanner': lastScanner,
              'last_scan_time': lastScanTime.toIso8601String(),
              'scanner_cooldown_seconds': scannerCooldownSeconds,
              'remaining_seconds': remainingTime,
            },
          );
          
          _showErrorNotification(
            'Cannot use same scanner consecutively. Please wait ${remainingTime}s or use a different scanner.',
          );
          return;
        }
      }
    }

    // Set cooldowns for this RFID
    rfidCooldowns[rfidUid] = now;
    
    // Update scanner tracking
    if (scanner != null) {
      lastScannerPerRfid[rfidUid] = scanner;
      lastScanTimePerRfid[rfidUid] = now;
    }

    setState(() {
      isLoadingStudent = true;
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
      currentAction = null;
      currentScanner = null; // Clear scanner info
      scheduleValidationMessage = null;
      isOverrideMode = false;
      lastClassEndTime = null;
    });

    try {
      final response =
          await supabase
              .from('students')
              .select('*, sections!inner(name)')
              .eq('rfid_uid', rfidUid)
              .neq('status', 'deleted')
              .maybeSingle();

      if (response != null) {
        final student = Student.fromJson(response);

        // Log successful RFID scan with student data and scanner info
        _guardAuditService.logRFIDScanAttempt(
          rfidUid: rfidUid,
          isSuccessful: true,
          studentId: student.id.toString(),
          studentName: student.fullName,
          scanMetadata: {
            'student_section': student.classSection,
            'student_grade': student.gradeLevel,
            'scan_timestamp': now.toIso8601String(),
            'scanner': scanner ?? 'unknown',
          },
        );

        // Determine if this should be entry or exit based on scanner type
        String action;
        if (scanner != null) {
          // Use scanner type to determine action
          action = scanner == 'entry' ? 'entry' : 'exit';
        } else {
          // Fallback to existing logic for legacy compatibility
          action = await _checkTodayAttendanceStatus(student.id);
        }

        setState(() {
          scannedStudent = student;
          currentAction = action;
          currentScanner = scanner; // Store scanner info
          isLoadingStudent = false;

          activeScanToken =
              '${student.id}_${DateTime.now().microsecondsSinceEpoch}';
        });

        if (action == 'entry') {
          // Entry: Always allow for elementary students
          await _processEntry(student, scanner: scanner);
        } else {
          // Exit: Apply schedule validation
          if (isScheduleValidationEnabled && !isOverrideMode) {
            final scheduleCheck = await _checkClassSchedule(student);
            currentScheduleCheck = scheduleCheck; // Store the result

            // Log schedule validation check
            _guardAuditService.logScheduleValidation(
              studentId: student.id.toString(),
              studentName: student.fullName,
              canExit: scheduleCheck['canExit'] ?? false,
              validationResult: scheduleCheck['message'],
              restrictionReason: scheduleCheck['canExit'] == false ? scheduleCheck['message'] : null,
              classEndTime: scheduleCheck['lastClassEndTime'],
              currentClass: scheduleCheck['currentClass'],
              scheduleDetails: scheduleCheck,
            );

            if (!scheduleCheck['canExit']) {
              setState(() {
                scheduleValidationMessage = scheduleCheck['message'];
                lastClassEndTime = scheduleCheck['lastClassEndTime'];
              });

              // Show blocked layout for all schedule blocks - no automatic popups
              return; // This will show the schedule blocked layout
            }
          } else {
            // If override mode or validation disabled, still check for early dismissal info
            currentScheduleCheck = await _checkClassSchedule(student);
            
            // Log override mode usage
            if (isOverrideMode) {
              _guardAuditService.logOverrideAuthorization(
                overrideType: 'schedule_validation',
                studentId: student.id.toString(),
                studentName: student.fullName,
                justification: 'Guard override - schedule validation bypassed',
                originalRestriction: scheduleValidationMessage,
              );
            }
          }
          await _processExit(student, scanner: scanner);
        }
      } else {
        // Log failed student lookup
        _guardAuditService.logRFIDScanAttempt(
          rfidUid: rfidUid,
          isSuccessful: false,
          failureReason: 'Student not found or inactive',
          scanMetadata: {
            'lookup_timestamp': now.toIso8601String(),
            'database_response': 'null',
            'scanner': scanner ?? 'unknown',
          },
        );
        
        setState(() {
          isLoadingStudent = false;
        });
        _showErrorNotification('Student not found or inactive');
      }
    } catch (e) {
      // Log database error during student lookup
      _guardAuditService.logSystemError(
        errorType: 'database_lookup_error',
        errorDescription: 'Failed to fetch student data from database',
        systemComponent: 'database',
        errorDetails: {
          'rfid_uid': rfidUid,
          'error': e.toString(),
          'lookup_timestamp': now.toIso8601String(),
          'scanner': scanner ?? 'unknown',
        },
      );
      
      setState(() {
        isLoadingStudent = false;
      });
      _showErrorNotification('Error fetching student data: ${e.toString()}');
    }
  }

  // Clean up old cooldowns periodically
  static void _cleanupCooldowns() {
    final now = DateTime.now();
    rfidCooldowns.removeWhere(
      (uid, lastScan) =>
          now.difference(lastScan).inSeconds > cooldownSeconds * 2,
    );
    
    // Clean up scanner tracking maps
    lastScanTimePerRfid.removeWhere(
      (uid, lastScan) =>
          now.difference(lastScan).inSeconds > scannerCooldownSeconds * 2,
    );
    
    // Remove entries from scanner map if they no longer have a timestamp
    lastScannerPerRfid.removeWhere((uid, scanner) => 
        !lastScanTimePerRfid.containsKey(uid));
  }

  // Check if scanned RFID belongs to a guard (for override mode)
  Future<void> _checkGuardRFID(String rfidUid, {String? scanner}) async {
    try {
      print('Checking if RFID $rfidUid belongs to a guard...');
      
      // First, let's check if there are any guard RFID cards in the database
      final allGuardCards = await supabase
          .from('guard_rfid_cards')
          .select('id, guard_id, rfid_uid, status')
          .limit(5);
      
      print('Available guard RFID cards in database: $allGuardCards');
      
      // Check if this RFID belongs to a guard
      final guardResponse = await supabase
          .from('guard_rfid_cards')
          .select('guard_id, users!guard_rfid_cards_guard_id_fkey(id, fname, lname, role)')
          .eq('rfid_uid', rfidUid)
          .eq('status', 'active')
          .maybeSingle();

      print('Guard RFID check response: $guardResponse');

      if (guardResponse != null && guardResponse['users'] != null) {
        // This is a guard RFID - enter override mode
        final guard = guardResponse['users'];
        String guardName = '${guard['fname'] ?? ''} ${guard['lname'] ?? ''}'.trim();
        
        if (guardName.isEmpty) {
          guardName = 'Guard ${guard['id']}';
        }
        
        print('Guard RFID detected: $guardName');
        
        // Log guard override activation
        _guardAuditService.logOverrideAuthorization(
          overrideType: 'guard_gate_override',
          studentId: 'N/A',
          studentName: 'Override Mode Activated',
          justification: 'Guard RFID card scanned - Override mode enabled',
          overrideDetails: {
            'guard_id': guard['id'],
            'guard_name': guardName,
            'guard_rfid': rfidUid,
            'scanner': scanner ?? 'unknown',
            'activation_time': DateTime.now().toIso8601String(),
          },
        );

        await _activateOverrideMode(guardName);
        return;
      }

      print('Not a guard RFID, processing as student RFID...');
      // Not a guard RFID, process as student RFID with validation
      await _fetchStudentByRFIDWithValidation(rfidUid, scanner: scanner);
    } catch (e) {
      print('Error checking guard RFID: $e');
      // Log the error but continue with student processing
      _guardAuditService.logSystemError(
        errorType: 'guard_rfid_check_error',
        errorDescription: 'Failed to check if RFID belongs to guard',
        systemComponent: 'database',
        errorDetails: {
          'rfid_uid': rfidUid,
          'scanner': scanner ?? 'unknown',
          'error': e.toString(),
        },
      );
      
      // Fall back to student RFID processing with validation
      await _fetchStudentByRFIDWithValidation(rfidUid, scanner: scanner);
    }
  }

  // Activate guard override mode
  Future<void> _activateOverrideMode(String guardName) async {
    setState(() {
      isOverrideMode = true;
      _overrideModeStartTime = DateTime.now();
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
      currentAction = null;
      currentScanner = null;
      scheduleValidationMessage = null;
      verifiedTempFetcher = null;
      isShowingTempFetcher = false;
      activeScanToken = null;
      _searchResults = null;
      _searchQuery = '';
      _searchController.clear();
    });

    _showSuccessNotification(
      'Override Mode Activated by $guardName. Search and select a student to process manually.',
    );

    // Log override mode activation
    _guardAuditService.logRFIDSystemAccess(
      accessType: 'override_mode_activated',
      connectionDetails: 'Guard override mode activated by $guardName',
      isSuccessful: true,
    );
  }

  // Exit override mode
  void _exitOverrideMode(String reason) {
    
    // Log override mode deactivation
    final duration = _overrideModeStartTime != null 
        ? DateTime.now().difference(_overrideModeStartTime!).inSeconds
        : 0;
    
    _guardAuditService.logRFIDSystemAccess(
      accessType: 'override_mode_deactivated',
      connectionDetails: 'Guard override mode deactivated - $reason (Duration: ${duration}s)',
      isSuccessful: true,
    );

    setState(() {
      isOverrideMode = false;
      _overrideModeStartTime = null;
      _searchResults = null;
      _searchQuery = '';
      _searchController.clear();
      _isSearching = false;
    });

    clearScan();
  }

  // Search for students in override mode
  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final response = await supabase
          .from('students')
          .select('''
            *,
            sections!inner(name)
          ''')
          .neq('status', 'deleted')
          .or('fname.ilike.%$query%,lname.ilike.%$query%,grade_level.ilike.%$query%')
          .limit(10);

      final students = response.map((data) => Student.fromJson(data)).toList();

      setState(() {
        _searchResults = students;
        _isSearching = false;
      });

      // Log student search in override mode
      _guardAuditService.logRFIDSystemAccess(
        accessType: 'override_student_search',
        connectionDetails: 'Student search in override mode: "$query" - ${students.length} results',
        isSuccessful: true,
      );
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _showErrorNotification('Error searching students: $e');
    }
  }

  // Select student in override mode
  Future<void> _selectStudentInOverrideMode(Student student) async {
    // Set the selected student
    setState(() {
      scannedStudent = student;
      _searchResults = null;
      _searchQuery = '';
      _searchController.clear();
    });

    // Log student selection in override mode
    _guardAuditService.logOverrideAuthorization(
      overrideType: 'student_selection_override',
      studentId: student.id.toString(),
      studentName: student.fullName,
      justification: 'Student manually selected in guard override mode',
      overrideDetails: {
        'override_method': 'manual_selection',
        'student_section': student.classSection,
        'selection_time': DateTime.now().toIso8601String(),
      },
    );

    // Determine action based on current context or default to exit
    final action = await _checkTodayAttendanceStatus(student.id);
    
    setState(() {
      currentAction = action;
      activeScanToken = '${student.id}_${DateTime.now().microsecondsSinceEpoch}_override';
    });

    if (action == 'entry') {
      await _processOverrideEntry(student);
    } else {
      await _processOverrideExit(student);
    }
  }

  // Process entry in override mode
  Future<void> _processOverrideEntry(Student student) async {
    try {
      // Create detailed notes with override information
      String notes = 'Guard override entry - Manual selection';
      
      await supabase.from('scan_records').insert({
        'student_id': student.id,
        'guard_id': user?.id,
        'rfid_uid': student.rfidUid ?? 'OVERRIDE',
        'scan_time': DateTime.now().toIso8601String(),
        'action': 'entry',
        'verified_by': 'Guard Override - Manual Selection',
        'status': 'Checked In',
        'notes': notes,
      });

      // Log successful override entry
      _guardAuditService.logStudentEntry(
        studentId: student.id.toString(),
        studentName: student.fullName,
        rfidUid: student.rfidUid ?? 'OVERRIDE',
        sectionName: student.classSection,
        isSuccessful: true,
        notes: '$notes - immediate check-in approved via guard override',
      );

      // Send notification to parents
      await _notificationService
          .sendRfidTapNotification(
            studentId: student.id,
            action: 'entry',
            studentName: '${student.fname} ${student.lname}',
          );

      _showSuccessNotification('Student checked in successfully via guard override');

      // Auto-clear after success
      Future.delayed(Duration(seconds: 5), () {
        if (mounted && isOverrideMode) {
          _exitOverrideMode('Entry completed successfully');
        }
      });
    } catch (e) {
      // Log failed override entry
      _guardAuditService.logStudentEntry(
        studentId: student.id.toString(),
        studentName: student.fullName,
        rfidUid: student.rfidUid ?? 'OVERRIDE',
        sectionName: student.classSection,
        isSuccessful: false,
        notes: 'Override entry failed due to database error: ${e.toString()}',
      );
      
      _showErrorNotification('Error recording override entry: ${e.toString()}');
    }
  }

  // Process exit in override mode (load fetchers for approval)
  Future<void> _processOverrideExit(Student student) async {
    setState(() {
      isLoadingFetchers = true;
    });

    await _fetchAuthorizedFetchers(student.id);
    
    // Note: In override mode, schedule validation is bypassed
    // The exit will be processed through the normal approval flow
    // but marked as an override in the records
  }

  // Process entry (immediate check-in)
  Future<void> _processEntry(Student student, {String? scanner}) async {
    try {
      // Create detailed notes with scanner information
      String notes = 'Automatic entry via RFID scan';
      if (scanner != null) {
        notes += ' - Scanner: $scanner';
      }

      await supabase.from('scan_records').insert({
        'student_id': student.id,
        'guard_id': user?.id,
        'rfid_uid': student.rfidUid ?? '',
        'scan_time': DateTime.now().toIso8601String(),
        'action': 'entry',
        'verified_by': 'RFID Entry',
        'status': 'Checked In',
        'notes': notes,
      });

      // Log successful student entry
      _guardAuditService.logStudentEntry(
        studentId: student.id.toString(),
        studentName: student.fullName,
        rfidUid: student.rfidUid ?? '',
        sectionName: student.classSection,
        isSuccessful: true,
        notes: '$notes - immediate check-in approved',
      );

      // Send RFID entry notification to parents
      print(
        'DEBUG: About to send RFID entry notification for student ${student.id}',
      );
      final notificationSent = await _notificationService
          .sendRfidTapNotification(
            studentId: student.id,
            action: 'entry',
            studentName: '${student.fname} ${student.lname}',
          );
      print('DEBUG: RFID entry notification sent: $notificationSent');

      _showSuccessNotification('Student checked in successfully');

      // Entry mode timer: hide after 8 seconds
      final currentToken = activeScanToken;
      Future.delayed(Duration(seconds: 8), () {
        if (mounted && currentToken != null && currentToken == activeScanToken) {
          clearScan();
        }
      });
    } catch (e) {
      // Log failed student entry
      _guardAuditService.logStudentEntry(
        studentId: student.id.toString(),
        studentName: student.fullName,
        rfidUid: student.rfidUid ?? '',
        sectionName: student.classSection,
        isSuccessful: false,
        notes: 'Entry failed due to database error: ${e.toString()}',
      );
      
      // Log the database error
      _guardAuditService.logSystemError(
        errorType: 'database_insert_error',
        errorDescription: 'Failed to insert scan record during entry process',
        systemComponent: 'database',
        errorDetails: {
          'student_id': student.id.toString(),
          'student_name': student.fullName,
          'rfid_uid': student.rfidUid ?? '',
          'scanner': scanner ?? 'unknown',
          'error': e.toString(),
        },
      );
      
      _showErrorNotification('Error recording entry: ${e.toString()}');
    }
  }

  // Process exit (show fetchers and require approval)
  Future<void> _processExit(Student student, {String? scanner}) async {
    setState(() {
      isLoadingFetchers = true;
    });

    await _fetchAuthorizedFetchers(student.id);
  }

  // Function to fetch authorized fetchers from database
  Future<void> _fetchAuthorizedFetchers(int studentId) async {
    setState(() {
      isLoadingFetchers = true;
      fetchers = null;
    });

    try {
      print('Fetching authorized fetchers for student ID: $studentId');

      // First, get the parent-student relationships
      final parentStudentResponse = await supabase
          .from('parent_student')
          .select('''
          parent_id,
          relationship_type,
          is_primary
        ''')
          .eq('student_id', studentId);

      print('Parent-Student relationships: $parentStudentResponse');

      if (parentStudentResponse.isNotEmpty) {
        final List<Fetcher> fetchersList = [];

        // Get the parent IDs
        final parentIds =
            parentStudentResponse
                .map((rel) => rel['parent_id'])
                .toSet()
                .toList();

        // Fetch parent details
        final parentsResponse = await supabase
            .from('parents')
            .select('''
            id,
            fname,
            mname,
            lname,
            phone,
            email,
            address,
            status,
            user_id
          ''')
            .inFilter('id', parentIds)
            .eq('status', 'active'); // Only get active parents

        print('Parents response: $parentsResponse');

        // Create fetchers list by combining parent data with relationship data
        for (final parentData in parentsResponse) {
          // Find the corresponding relationship data
          final relationshipData = parentStudentResponse
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (rel) => rel != null && rel['parent_id'] == parentData['id'],
                orElse: () => null,
              );

          if (relationshipData != null) {
            // Get user profile image if user_id exists
            String? profileImageUrl;
            if (parentData['user_id'] != null) {
              try {
                final userResponse =
                    await supabase
                        .from('users')
                        .select('profile_image_url')
                        .eq('id', parentData['user_id'])
                        .maybeSingle();

                profileImageUrl = userResponse?['profile_image_url'];
              } catch (e) {
                print('Error fetching user profile image: $e');
              }
            }

            final fetcher = Fetcher(
              id: parentData['id'],
              name:
                  '${parentData['fname']} ${parentData['mname'] ?? ''} ${parentData['lname']}'
                      .trim(),
              relationship: relationshipData['relationship_type'] ?? 'Parent',
              contact: parentData['phone'] ?? '',
              email: parentData['email'] ?? '',
              address: parentData['address'] ?? '',
              imageUrl: profileImageUrl ?? '',
              isPrimary: relationshipData['is_primary'] ?? false,
            );

            fetchersList.add(fetcher);
            print('Added fetcher: ${fetcher.name} (${fetcher.relationship})');
          }
        }

        // Sort fetchers: primary ones first, then by relationship type
        fetchersList.sort((a, b) {
          if (a.isPrimary && !b.isPrimary) return -1;
          if (!a.isPrimary && b.isPrimary) return 1;
          return a.relationship.compareTo(b.relationship);
        });

        setState(() {
          fetchers = fetchersList;
          isLoadingFetchers = false;
        });

        print('Found ${fetchersList.length} authorized fetchers');
      } else {
        setState(() {
          fetchers = [];
          isLoadingFetchers = false;
        });
        print(
          'No parent-student relationships found for student ID: $studentId',
        );
        _showErrorNotification('No authorized fetchers found for this student');
      }
    } catch (e) {
      setState(() {
        isLoadingFetchers = false;
        fetchers = [];
      });
      _showErrorNotification(
        'Error fetching authorized fetchers: ${e.toString()}',
      );
      print('Error fetching authorized fetchers: $e');
    }
  }

  // Add this method to the StudentVerificationPage class
  Future<Map<String, dynamic>?> _verifyTemporaryFetcherPin(
    String pin,
    int studentId,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Try exact match first (as entered)
      var response =
          await supabase
              .from('temporary_fetchers')
              .select('*')
              .eq('pin_code', pin)
              .eq('student_id', studentId)
              .eq('valid_date', today)
              .eq('status', 'active')
              .eq('is_used', false)
              .maybeSingle();

      // If no exact match found and pin has leading zeros, try without leading zeros
      if (response == null && pin.startsWith('0')) {
        final pinWithoutZeros = pin.replaceFirst(RegExp(r'^0+'), '');

        response =
            await supabase
                .from('temporary_fetchers')
                .select('*')
                .eq('pin_code', pinWithoutZeros)
                .eq('student_id', studentId)
                .eq('valid_date', today)
                .eq('status', 'active')
                .eq('is_used', false)
                .maybeSingle();
      }

      // If still no match, try with leading zeros (in case database stores with zeros)
      if (response == null && !pin.startsWith('0')) {
        final pinWithZeros = pin.padLeft(6, '0');

        response =
            await supabase
                .from('temporary_fetchers')
                .select('*')
                .eq('pin_code', pinWithZeros)
                .eq('student_id', studentId)
                .eq('valid_date', today)
                .eq('status', 'active')
                .eq('is_used', false)
                .maybeSingle();
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  // Fix the method call in _verifyAndProcessTemporaryFetcher
  Future<void> _verifyAndProcessTemporaryFetcher(String pin) async {
    if (scannedStudent == null) return;

    try {
      final tempFetcher = await _verifyTemporaryFetcherPin(
        pin,
        scannedStudent!.id,
      );

      if (tempFetcher != null) {
        // Log successful PIN verification
        _guardAuditService.logTemporaryFetcherPINVerification(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          pin: pin,
          isSuccessful: true,
          fetcherName: tempFetcher['fetcher_name'],
          tempFetcherId: tempFetcher['id'].toString(),
          fetcherDetails: {
            'relationship': tempFetcher['relationship'],
            'contact_number': tempFetcher['contact_number'],
            'id_type': tempFetcher['id_type'],
            'id_number': tempFetcher['id_number'],
            'valid_date': tempFetcher['valid_date'],
          },
        );

        setState(() {
          verifiedTempFetcher = tempFetcher;
          isShowingTempFetcher = true;
        });

        _showSuccessNotification(
          'PIN verified successfully! Please review fetcher details.',
        );
      } else {
        // Log failed PIN verification
        _guardAuditService.logTemporaryFetcherPINVerification(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          pin: pin,
          isSuccessful: false,
          failureReason: 'Invalid PIN or PIN not found',
        );

        await _showDetailedPinErrorNotification(pin, scannedStudent!.id);
      }
    } catch (e) {
      // Log error during PIN verification
      _guardAuditService.logSystemError(
        errorType: 'pin_verification_error',
        errorDescription: 'Error occurred during temporary fetcher PIN verification',
        systemComponent: 'database',
        errorDetails: {
          'student_id': scannedStudent!.id.toString(),
          'student_name': scannedStudent!.fullName,
          'pin': pin,
          'error': e.toString(),
        },
      );

      _showErrorNotification(
        'Error verifying temporary fetcher: ${e.toString()}',
      );
    }
  }

  // New method to handle final approval of temporary fetcher
  Future<void> _processTempFetcherPickup(
    bool approved, {
    String? denyReason,
  }) async {
    if (scannedStudent == null || verifiedTempFetcher == null) return;

    try {
      if (approved) {
        // Mark as used
        await _markTemporaryFetcherAsUsed(verifiedTempFetcher!['id']);

        // Create detailed notes with all fetcher information
        final detailedNotes =
            'Temporary fetcher verification - '
            'PIN: ${verifiedTempFetcher!['pin_code']}, '
            'Fetcher: ${verifiedTempFetcher!['fetcher_name']}, '
            'Relationship: ${verifiedTempFetcher!['relationship']}, '
            'Contact: ${verifiedTempFetcher!['contact_number'] ?? 'Not provided'}, '
            'ID Type: ${verifiedTempFetcher!['id_type'] ?? 'Not provided'}, '
            'ID Number: ${verifiedTempFetcher!['id_number'] ?? 'Not provided'}, '
            'Emergency Contact: ${verifiedTempFetcher!['emergency_contact'] ?? 'Not provided'}';

        // Save pickup record with enhanced information
        await supabase.from('scan_records').insert({
          'student_id': scannedStudent!.id,
          'guard_id': user?.id,
          'rfid_uid': scannedStudent!.rfidUid ?? '',
          'scan_time': DateTime.now().toIso8601String(),
          'action': 'exit',
          'verified_by':
              'Temporary Fetcher: ${verifiedTempFetcher!['fetcher_name']} (PIN: ${verifiedTempFetcher!['pin_code']})',
          'status': 'Checked Out',
          'notes': detailedNotes,
          'scanner_location': currentScanner, // Add scanner information
        });

        // Log successful temporary fetcher pickup
        _guardAuditService.logStudentExit(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          rfidUid: scannedStudent!.rfidUid ?? '',
          isApproved: true,
          fetcherName: verifiedTempFetcher!['fetcher_name'],
          fetcherType: 'temporary',
          exitType: 'regular',
          sectionName: scannedStudent!.classSection,
          notes: 'Temporary fetcher pickup approved after PIN verification',
        );

        // Send RFID exit notification to parents
        print(
          'DEBUG: About to send RFID exit notification for student ${scannedStudent!.id}',
        );
        final notificationSent = await _notificationService
            .sendRfidTapNotification(
              studentId: scannedStudent!.id,
              action: 'exit',
              studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
            );
        print('DEBUG: RFID exit notification sent: $notificationSent');

        _showSuccessNotification(
          'Pickup approved for temporary fetcher: ${verifiedTempFetcher!['fetcher_name']}',
        );
      } else {
        // Save denied record
        await supabase.from('scan_records').insert({
          'student_id': scannedStudent!.id,
          'guard_id': user?.id,
          'rfid_uid': scannedStudent!.rfidUid ?? '',
          'scan_time': DateTime.now().toIso8601String(),
          'action': 'denied',
          'verified_by': 'Guard',
          'status': 'Denied',
          'notes':
              'Temporary fetcher pickup denied: ${denyReason ?? 'No reason provided'}',
          'scanner_location': currentScanner, // Add scanner information
        });

        // Log denied temporary fetcher pickup
        _guardAuditService.logStudentExit(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          rfidUid: scannedStudent!.rfidUid ?? '',
          isApproved: false,
          fetcherName: verifiedTempFetcher!['fetcher_name'],
          fetcherType: 'temporary',
          denyReason: denyReason ?? 'No reason provided',
          sectionName: scannedStudent!.classSection,
          notes: 'Temporary fetcher pickup denied by guard',
        );

        // Log pickup denial decision
        _guardAuditService.logPickupDenialDecision(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          denyReason: denyReason ?? 'No reason provided',
          fetcherType: 'temporary',
          fetcherName: verifiedTempFetcher!['fetcher_name'],
          additionalNotes: 'Temporary fetcher with valid PIN denied by guard',
          decisionContext: {
            'pin_code': verifiedTempFetcher!['pin_code'],
            'fetcher_relationship': verifiedTempFetcher!['relationship'],
            'fetcher_contact': verifiedTempFetcher!['contact_number'],
          },
        );

        // Send pickup denial notification to parents
        print(
          'DEBUG: About to send temporary fetcher pickup denial notification for student ${scannedStudent!.id}',
        );

        // Get guard name for the notification
        String? guardName;
        if (user?.id != null) {
          try {
            final guardResponse =
                await supabase
                    .from('users')
                    .select('fname, lname')
                    .eq('id', user!.id)
                    .maybeSingle();
            if (guardResponse != null) {
              guardName =
                  '${guardResponse['fname'] ?? ''} ${guardResponse['lname'] ?? ''}'
                      .trim();
            }
          } catch (e) {
            print('Error getting guard name: $e');
          }
        }

        final notificationSent = await _notificationService
            .sendPickupDenialNotification(
              studentId: scannedStudent!.id,
              studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
              denyReason: denyReason ?? 'No reason provided',
              guardName: guardName,
              fetcherName: verifiedTempFetcher!['fetcher_name'],
              fetcherType: 'temporary',
            );
        print(
          'DEBUG: Temporary fetcher pickup denial notification sent: $notificationSent',
        );

        _showErrorNotification(
          'Pickup denied: ${denyReason ?? 'Access denied'}',
        );
      }

      // Auto-clear after success/denial
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) clearScan();
      });
    } catch (e) {
      // Log error during temp fetcher pickup processing
      _guardAuditService.logSystemError(
        errorType: 'temp_fetcher_pickup_error',
        errorDescription: 'Error processing temporary fetcher pickup decision',
        systemComponent: 'database',
        errorDetails: {
          'student_id': scannedStudent!.id.toString(),
          'student_name': scannedStudent!.fullName,
          'fetcher_name': verifiedTempFetcher!['fetcher_name'],
          'approved': approved,
          'deny_reason': denyReason,
          'error': e.toString(),
        },
      );

      _showErrorNotification(
        'Error processing temporary fetcher pickup: ${e.toString()}',
      );
    }
  }

  Future<void> _showDetailedPinErrorNotification(
    String pin,
    int studentId,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Check if there are any temporary fetchers for this student today
      final allTempFetchersToday = await supabase
          .from('temporary_fetchers')
          .select('*')
          .eq('student_id', studentId)
          .eq('valid_date', today);

      // Check if there are any active temporary fetchers for this student today
      final activeTempFetchersToday = await supabase
          .from('temporary_fetchers')
          .select('*')
          .eq('student_id', studentId)
          .eq('valid_date', today)
          .eq('status', 'active')
          .eq('is_used', false);

      // Check if this specific PIN exists for any student today
      final pinExistsForOtherStudent =
          await supabase
              .from('temporary_fetchers')
              .select('student_id, fetcher_name')
              .eq('pin_code', pin)
              .eq('valid_date', today)
              .eq('status', 'active')
              .eq('is_used', false)
              .maybeSingle();

      String errorMessage = '';

      if (allTempFetchersToday.isEmpty) {
        errorMessage =
            'No temporary fetchers assigned to ${scannedStudent!.fullName} for today ($today)';
      } else if (activeTempFetchersToday.isEmpty) {
        final usedCount =
            allTempFetchersToday.where((f) => f['is_used'] == true).length;
        final inactiveCount =
            allTempFetchersToday.where((f) => f['status'] != 'active').length;

        if (usedCount > 0 && inactiveCount > 0) {
          errorMessage =
              'All temporary fetcher PINs for ${scannedStudent!.fullName} have been used or are inactive';
        } else if (usedCount > 0) {
          errorMessage =
              'All temporary fetcher PINs for ${scannedStudent!.fullName} have already been used today';
        } else {
          errorMessage =
              'All temporary fetchers for ${scannedStudent!.fullName} are inactive';
        }
      } else if (pinExistsForOtherStudent != null) {
        errorMessage =
            'PIN $pin belongs to a different student. Please verify the correct PIN for ${scannedStudent!.fullName}';
      } else {
        // Check if PIN might exist with different formatting
        final availablePins =
            activeTempFetchersToday
                .map((f) => f['pin_code'].toString())
                .toList();
        if (availablePins.isNotEmpty) {
          errorMessage =
              'Invalid PIN "$pin" for ${scannedStudent!.fullName}. ${availablePins.length} active PIN(s) available for today';
        } else {
          errorMessage =
              'Invalid PIN "$pin" - no matching temporary fetcher found for ${scannedStudent!.fullName}';
        }
      }

      _showErrorNotification(errorMessage);
    } catch (e) {
      _showErrorNotification('Invalid PIN or PIN already used');
    }
  }

  // Method to mark temporary fetcher as used
  Future<void> _markTemporaryFetcherAsUsed(int tempFetcherId) async {
    try {
      await supabase
          .from('temporary_fetchers')
          .update({
            'is_used': true,
            'used_at': DateTime.now().toIso8601String(),
            'created_by_guard_id': user?.id,
          })
          .eq('id', tempFetcherId);
    } catch (e) {
      print('Error marking temporary fetcher as used: $e');
    }
  }

  // Modified save pickup record to include override information
  Future<void> _savePickupRecord(bool approved, {String? denyReason}) async {
    if (scannedStudent == null) return;
    try {
      final verifiedBy =
          fetchers?.isNotEmpty == true
              ? fetchers!.first.relationship
              : "Unknown";
      final action = approved ? "exit" : "denied";
      final status = approved ? "Checked Out" : "Denied";

      String notes = "";
      String? exitType;
      
      if (!approved) {
        notes = denyReason ?? "Denied by guard";
      } else if (currentScheduleCheck != null && currentScheduleCheck!['exitType'] == 'early_dismissal') {
        // Early dismissal exit
        final dismissalInfo = currentScheduleCheck!['earlyDismissal'];
        notes = "Early dismissal exit - Reason: ${dismissalInfo['reason']}";
        exitType = 'early_dismissal';
      } else if (currentScheduleCheck != null && currentScheduleCheck!['exitType'] == 'emergency_exit') {
        // Emergency exit
        final emergencyInfo = currentScheduleCheck!['emergencyExit'];
        final markedBy = emergencyInfo['markedBy'];
        final teacherName = "${markedBy['fname'] ?? ''} ${markedBy['lname'] ?? ''}".trim();
        notes = "Emergency exit - Approved by teacher: $teacherName";
        exitType = 'emergency_exit';
      } else if (isOverrideMode) {
        // Check what type of override this was
        if (scheduleValidationMessage != null) {
          if (scheduleValidationMessage!.contains('Very early')) {
            notes =
                "Very early dismissal override (2+ hours) - Reason: ${scheduleValidationMessage}";
          } else {
            notes = "Early dismissal override - ${scheduleValidationMessage}";
          }
        } else {
          notes = "Guard override - Student manually selected and approved";
        }
        exitType = 'override';
      } else {
        notes = "Regular exit after class hours";
        exitType = 'regular';
      }

      await supabase.from('scan_records').insert({
        'student_id': scannedStudent!.id,
        'guard_id': user?.id,
        'rfid_uid': scannedStudent!.rfidUid ?? '',
        'scan_time': DateTime.now().toIso8601String(),
        'action': action,
        'verified_by': verifiedBy,
        'status': status,
        'notes': notes,
        'scanner_location': currentScanner, // Add scanner information
      });

      // Log authorized fetcher verification
      if (fetchers != null && fetchers!.isNotEmpty) {
        final fetcher = fetchers!.first;
        _guardAuditService.logAuthorizedFetcherVerification(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          fetcherId: fetcher.id.toString(),
          fetcherName: fetcher.name,
          fetcherType: fetcher.relationship,
          isVerified: approved,
          verificationMethod: 'Guard visual confirmation',
          notes: approved ? 'Fetcher approved by guard' : 'Fetcher denied by guard: ${denyReason ?? 'No reason provided'}',
        );
      }

      // Log student exit/denial
      _guardAuditService.logStudentExit(
        studentId: scannedStudent!.id.toString(),
        studentName: scannedStudent!.fullName,
        rfidUid: scannedStudent!.rfidUid ?? '',
        isApproved: approved,
        fetcherName: fetchers?.isNotEmpty == true ? fetchers!.first.name : null,
        fetcherType: 'authorized',
        denyReason: denyReason,
        exitType: exitType ?? 'regular',
        sectionName: scannedStudent!.classSection,
        notes: notes,
        scheduleOverride: isOverrideMode ? {
          'override_enabled': true,
          'original_message': scheduleValidationMessage,
          'override_justification': 'Guard override authorization',
        } : null,
      );

      // Send RFID exit notification to parents only if approved
      if (approved) {
        // Log early dismissal exit if applicable
        if (currentScheduleCheck != null && 
            currentScheduleCheck!['exitType'] == 'early_dismissal' &&
            currentScheduleCheck!['earlyDismissal'] != null) {
          await _logEarlyDismissalExit(scannedStudent!.id, currentScheduleCheck!['earlyDismissal']);
          
          // Log emergency handling for early dismissal
          _guardAuditService.logEmergencyHandling(
            emergencyType: 'early_dismissal',
            description: 'Student released during early dismissal period',
            studentId: scannedStudent!.id.toString(),
            studentName: scannedStudent!.fullName,
            responseAction: 'Student exit approved',
            emergencyDetails: currentScheduleCheck!['earlyDismissal'],
          );
        }

        // Log emergency exit completion if applicable
        if (currentScheduleCheck != null && 
            currentScheduleCheck!['exitType'] == 'emergency_exit' &&
            currentScheduleCheck!['emergencyExit'] != null) {
          await _logEmergencyExitCompletion(scannedStudent!.id, currentScheduleCheck!['emergencyExit']);
          
          // Log emergency handling for emergency exit
          _guardAuditService.logEmergencyHandling(
            emergencyType: 'emergency_exit',
            description: 'Student released during emergency exit procedure',
            studentId: scannedStudent!.id.toString(),
            studentName: scannedStudent!.fullName,
            responseAction: 'Emergency exit approved and completed',
            emergencyDetails: currentScheduleCheck!['emergencyExit'],
          );
        }

        print(
          'DEBUG: About to send RFID exit notification for student ${scannedStudent!.id} (regular pickup)',
        );
        final notificationSent = await _notificationService
            .sendRfidTapNotification(
              studentId: scannedStudent!.id,
              action: 'exit',
              studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
            );
        print(
          'DEBUG: RFID exit notification sent (regular pickup): $notificationSent',
        );
      } else {
        // Log pickup denial decision for authorized fetchers
        _guardAuditService.logPickupDenialDecision(
          studentId: scannedStudent!.id.toString(),
          studentName: scannedStudent!.fullName,
          denyReason: denyReason ?? 'No reason provided',
          fetcherType: 'authorized',
          fetcherName: fetchers?.isNotEmpty == true ? fetchers!.first.name : null,
          additionalNotes: 'Authorized fetcher denied by guard decision',
          decisionContext: {
            'fetcher_details': fetchers?.isNotEmpty == true ? {
              'name': fetchers!.first.name,
              'relationship': fetchers!.first.relationship,
              'contact': fetchers!.first.contact,
              'is_primary': fetchers!.first.isPrimary,
            } : null,
            'schedule_check': currentScheduleCheck,
            'override_mode': isOverrideMode,
          },
        );

        // Send pickup denial notification to parents
        print(
          'DEBUG: About to send pickup denial notification for student ${scannedStudent!.id}',
        );

        // Get guard name for the notification
        String? guardName;
        if (user?.id != null) {
          try {
            final guardResponse =
                await supabase
                    .from('users')
                    .select('fname, lname')
                    .eq('id', user!.id)
                    .maybeSingle();
            if (guardResponse != null) {
              guardName =
                  '${guardResponse['fname'] ?? ''} ${guardResponse['lname'] ?? ''}'
                      .trim();
            }
          } catch (e) {
            print('Error getting guard name: $e');
          }
        }

        // Get fetcher information if available
        String? fetcherName;
        String? fetcherType;
        if (fetchers != null && fetchers!.isNotEmpty) {
          fetcherName = fetchers!.first.name;
          fetcherType = 'authorized';
        }

        final notificationSent = await _notificationService
            .sendPickupDenialNotification(
              studentId: scannedStudent!.id,
              studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
              denyReason: denyReason ?? 'No reason provided',
              guardName: guardName,
              fetcherName: fetcherName,
              fetcherType: fetcherType,
            );
        print('DEBUG: Pickup denial notification sent: $notificationSent');
      }
    } catch (e) {
      // Log error during pickup record saving
      _guardAuditService.logSystemError(
        errorType: 'pickup_record_error',
        errorDescription: 'Failed to save pickup record to database',
        systemComponent: 'database',
        errorDetails: {
          'student_id': scannedStudent!.id.toString(),
          'student_name': scannedStudent!.fullName,
          'approved': approved,
          'deny_reason': denyReason,
          'error': e.toString(),
        },
      );
      
      print('Error saving pickup record: $e');
    }
  }

  // Show error notification
  void _showErrorNotification(String message) {
    setState(() {
      showNotification = false;
    });
    Future.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      setState(() {
        showNotification = true;
        notificationMessage = message;
        notificationColor = Colors.red;
        fetchStatus = null;
      });
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });
  }

  // Show success notification
  void _showSuccessNotification(String message) {
    setState(() {
      showNotification = false;
    });
    Future.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      setState(() {
        showNotification = true;
        notificationMessage = message;
        notificationColor = Colors.green;
        fetchStatus = 'approved';
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });
  }

  void clearScan() {
    setState(() {
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
      isLoadingStudent = false;
      isLoadingFetchers = false;
      currentAction = null;
      currentScanner = null; // Clear scanner info
      scheduleValidationMessage = null;
      lastClassEndTime = null;
      verifiedTempFetcher = null;
      isShowingTempFetcher = false;
      activeScanToken = null;
      
      // Don't reset override mode here - let it timeout naturally
      // or be explicitly exited
      if (!isOverrideMode) {
        _searchResults = null;
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void handleApproval(bool approved, {String? denyReason}) {
    final now = DateTime.now();
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      fetchStatus = approved ? 'approved' : 'denied';
      showNotification = true;
      notificationMessage =
          approved
              ? (isOverrideMode
                  ? 'Early dismissal approved at $formattedTime'
                  : 'Pickup approved at $formattedTime')
              : 'Pickup denied at $formattedTime';
      notificationColor = approved ? Colors.green : Colors.red;
      actionTimestamp = now;
    });

    _savePickupRecord(approved, denyReason: denyReason);

    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });

    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        clearScan();
      }
    });
  }

  void _showDenyReasonDialog() async {
    final reasons = [
      'No valid ID presented',
      'Not an authorized fetcher',
      'Student requested not to leave',
      'Other',
    ];
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Deny Pick-up - Reason',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Please select a reason for denying this pickup request:',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    hint: Text(
                      'Select a reason',
                      style: TextStyle(fontSize: 16),
                    ),
                    items:
                        reasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(reason, style: TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                        if (value != 'Other') {
                          customReasonController.text = '';
                        }
                        errorText = null;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: customReasonController,
                    decoration: InputDecoration(
                      labelText: 'Custom reason',
                      labelStyle: TextStyle(fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabled: selectedReason == 'Other',
                    ),
                    style: TextStyle(fontSize: 16),
                    minLines: 2,
                    maxLines: 3,
                    enabled: selectedReason == 'Other',
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        errorText!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String reasonToSave = '';
                    if (selectedReason == null) {
                      setState(() {
                        errorText = "Please select a reason.";
                      });
                      return;
                    } else if (selectedReason == 'Other') {
                      if (customReasonController.text.trim().isEmpty) {
                        setState(() {
                          errorText = "Please provide a custom reason.";
                        });
                        return;
                      }
                      reasonToSave = customReasonController.text.trim();
                    } else {
                      reasonToSave = selectedReason!;
                    }
                    Navigator.pop(context, reasonToSave);
                  },
                  child: Text('Confirm', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is String && result.isNotEmpty) {
        handleApproval(false, denyReason: result);
      }
    });
  }

  // Simulate RFID scan for testing
  void simulateRFIDScan() {
    _fetchStudentByRFID('d9e0c801', scanner: 'entry');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content - full screen
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildMainContent(),
        ),

        // Debug controls in upper right corner
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Schedule validation toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: () {
                    final previousState = isScheduleValidationEnabled;
                    setState(() {
                      isScheduleValidationEnabled =
                          !isScheduleValidationEnabled;
                    });
                    
                    // Log schedule validation control change
                    _guardAuditService.logRFIDSystemAccess(
                      accessType: 'configuration_change',
                      connectionDetails: 'Schedule validation ${isScheduleValidationEnabled ? 'enabled' : 'disabled'} - Previous state: $previousState',
                      isSuccessful: true,
                    );
                  },
                  icon: Icon(
                    isScheduleValidationEnabled
                        ? Icons.schedule
                        : Icons.schedule_outlined,
                    size: 16,
                  ),
                  label: Text(
                    isScheduleValidationEnabled
                        ? 'Disable Schedule Check'
                        : 'Enable Schedule Check',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isScheduleValidationEnabled
                            ? Colors.green
                            : Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(height: 8),

              // Test RFID Scan Buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextButton.icon(
                      onPressed: simulateRFIDScan,
                      icon: Icon(Icons.credit_card, size: 16),
                      label: Text('Test Entry Scan', style: TextStyle(fontSize: 14)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _fetchStudentByRFID('d9e0c801', scanner: 'exit'),
                      icon: Icon(Icons.credit_card, size: 16),
                      label: Text('Test Exit Scan', style: TextStyle(fontSize: 14)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isOverrideMode 
                          ? () => _exitOverrideMode('Manual exit via debug button')
                          : () => _activateOverrideMode('Debug Mode'),
                      icon: Icon(
                        isOverrideMode ? Icons.security_outlined : Icons.security, 
                        size: 16
                      ),
                      label: Text(
                        isOverrideMode ? 'Exit Override' : 'Test Override', 
                        style: TextStyle(fontSize: 14)
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: isOverrideMode ? Colors.red[700] : Colors.orange[700],
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Floating notification
        if (showNotification) _buildFloatingNotification(),
      ],
    );
  }

  Widget _buildMainContent() {
    if (isOverrideMode) {
      return _buildOverrideModeLayout();
    } else if (currentAction == 'entry') {
      return _buildEntryModeLayout();
    } else if (currentAction == 'exit') {
      if (isShowingTempFetcher && verifiedTempFetcher != null) {
        return _buildTempFetcherVerificationLayout();
      } else if (scheduleValidationMessage != null && !isOverrideMode) {
        return _buildScheduleBlockedLayout();
      } else {
        return _buildExitModeLayout();
      }
    } else {
      return _buildBeforeScanWidget();
    }
  }

  // Updated before scan widget with enhanced accessibility for guards
  Widget _buildBeforeScanWidget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left side - RFID scan prompt (Enhanced for better visibility)
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[50]!, Colors.indigo[50]!],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[200]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // RFID Icon (Significantly Enlarged)
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.contact_page,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),

                // Main instruction text (Enlarged)
                Text(
                  'TAP RFID CARD',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 16),

                // Subtitle (Enlarged)
                Text(
                  'System will automatically detect\nentry or exit',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),

                // Auto mode badge (Enlarged)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_mode, size: 24, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'AUTO MODE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),

                // Manual Override Button
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[200]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _activateOverrideMode('Manual Activation'),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security, size: 20, color: Colors.orange[700]),
                          SizedBox(width: 10),
                          Text(
                            'MANUAL OVERRIDE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Override Instructions
                Text(
                  'For lost RFID cards or emergencies',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 32),

        // Right side - Information panel (Enhanced readability)
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Enlarged)
                  Text(
                    'EXIT SCHEDULE RULES',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Info items (All enlarged for better readability)
                  _buildEnhancedInfoItem(
                    Icons.login,
                    'Entry - Always Allowed',
                    'Students can enter at any time during school hours',
                    Colors.green,
                  ),
                  SizedBox(height: 20),

                  _buildEnhancedInfoItem(
                    Icons.warning,
                    'Very Early Exit (2+ hrs)',
                    'Requires override with reason selection',
                    Colors.red,
                  ),
                  SizedBox(height: 20),

                  _buildEnhancedInfoItem(
                    Icons.schedule,
                    'Early Exit (30+ min)',
                    'Requires guard override confirmation',
                    Colors.orange,
                  ),
                  SizedBox(height: 20),

                  _buildEnhancedInfoItem(
                    Icons.check_circle,
                    'Near End/Regular',
                    'Allowed without restrictions',
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced info item with larger text and icons for better visibility
  Widget _buildEnhancedInfoItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New layout for schedule-blocked exits - uniform design with entry/exit modes
  Widget _buildScheduleBlockedLayout() {
    final currentClass = currentScheduleCheck?['currentClass'];
    final currentTeacher = currentScheduleCheck?['currentTeacher'];
    final lastClassEndTime = currentScheduleCheck?['lastClassEndTime'];
    final subject = currentScheduleCheck?['subject'];
    
    // Auto-clear timer similar to entry mode (8 seconds)
    Future.delayed(Duration(seconds: 8), () {
      if (mounted && activeScanToken != null) {
        // Only clear if the active token hasn't changed (i.e. no newer scan)
        final currentToken = activeScanToken;
        if (currentToken != null && currentToken == activeScanToken) {
          clearScan();
        }
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Student Information Card - similar to entry/exit mode
        Expanded(
          flex: 7,
          child: Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red[50]!, Colors.orange[50]!],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red[200]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Side - Student Photo and Status (Significantly Enlarged)
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Blocked Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block,
                              size: 28,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'EXIT BLOCKED',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),

                      // Enlarged Student Photo
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _buildImageContent(scannedStudent!.imageUrl),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 24,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'CLASSES IN SESSION',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Current Time
                      Text(
                        'Current Time: ${_formatCurrentTime()}',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 48),

                // Right Side - Student Information and Class Details (Significantly Enlarged)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Student Name (Massively Enlarged)
                        Text(
                          scannedStudent!.fullName,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 16),

                        // Class Section (Enlarged)
                        Text(
                          scannedStudent!.classSection,
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: 32),

                        // Student ID Section
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.badge,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student ID',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    scannedStudent!.studentId,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Current Class Information
                        if (currentClass != null || subject != null) ...[
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.school,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Class',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        currentClass ?? subject ?? 'In Session',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (currentTeacher != null) ...[
                                        SizedBox(height: 6),
                                        Text(
                                          'Teacher: $currentTeacher',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.orange[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Class End Time
                        if (lastClassEndTime != null) ...[
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.schedule,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Classes End',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _formatTime(lastClassEndTime),
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 24),

                        // Informational Message
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 24,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  scheduleValidationMessage ?? 'Student cannot exit during class hours. Please wait until classes end.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
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
              ],
            ),
          ),
        ),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStudentImage({
    required String? imageUrl,
    required double width,
    required double height,
    double borderRadius = 8.0,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: _buildImageContent(imageUrl),
      ),
    );
  }

  Widget _buildImageContent(String? imageUrl) {
    // Check if we have a valid image URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildLoadingImage();
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading student image: $error');
        return _buildPlaceholderImage();
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.person, size: 60, color: Colors.grey[500]),
    );
  }

  Widget _buildLoadingImage() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }

  // Entry mode layout - refactored for better space utilization and accessibility
  Widget _buildEntryModeLayout() {
    if (isLoadingStudent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue, strokeWidth: 6),
            SizedBox(height: 32),
            Text(
              'Loading Student Data...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      );
    }

    if (scannedStudent == null) {
      return _buildBeforeScanWidget();
    }

    // Single column layout for better space utilization
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Student Information Card - Top Section
        Expanded(
          flex: 7,
          child: Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[50]!, Colors.blue[50]!],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green[200]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Side - Student Photo (Significantly Enlarged)
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 28,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'CHECK-IN SUCCESSFUL',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),

                      // Enlarged Student Photo
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _buildImageContent(scannedStudent!.imageUrl),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Verification Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 24,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'VERIFIED STUDENT',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Check-in Time
                      Text(
                        'Entry Time: ${_formatCurrentTime()}',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 48),

                // Right Side - Student Information (Significantly Enlarged)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Student Name (Massively Enlarged)
                        Text(
                          scannedStudent!.fullName,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 16),

                        // Class Section (Enlarged)
                        Text(
                          scannedStudent!.classSection,
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: 32),

                        // Student ID Section
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.badge,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student ID',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    scannedStudent!.studentId,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Address Information (Enlarged)
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.home,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Home Address',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      scannedStudent!.address,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 24),

                        // Additional Info Row
                        Row(
                          children: [
                            // Gender
                            if (scannedStudent!.gender != null)
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.purple[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gender',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.purple[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        scannedStudent!.gender ??
                                            'Not specified',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            if (scannedStudent!.gender != null &&
                                scannedStudent!.birthday != null)
                              SizedBox(width: 16),

                            // Birthday
                            if (scannedStudent!.birthday != null)
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.pink[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.pink[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date of Birth',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.pink[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        scannedStudent!.birthday!,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Scanner Information (if available)
                        if (currentScanner != null) ...[
                          SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    currentScanner == 'entry' ? Icons.login : Icons.logout,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scanner Used',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      currentScanner!.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12), // Slightly reduced padding for exit mode
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color), // Slightly smaller icon
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12, // Smaller font for labels
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14, // Smaller font for values in exit mode
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  // Exit mode layout - enhanced for better accessibility and space utilization
  Widget _buildExitModeLayout() {
    if (isLoadingStudent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green, strokeWidth: 6),
            SizedBox(height: 32),
            Text(
              'Loading Student Data...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    }

    if (scannedStudent == null) {
      return _buildBeforeScanWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Section - Student Information (Enlarged for better visibility)
        Expanded(
          flex: 6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left - Student Information Panel (Significantly Enlarged)
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange[50]!, Colors.red[50]!],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[200]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.exit_to_app,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXIT VERIFICATION',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Verify authorized pickup',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 32),

                      // Student Information Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Student Photo (Enlarged)
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImageContent(
                                scannedStudent!.imageUrl,
                              ),
                            ),
                          ),

                          SizedBox(width: 32),

                          // Student Details (Enlarged Text)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Student Name (Massively Enlarged)
                                Text(
                                  scannedStudent!.fullName,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                SizedBox(height: 12),

                                // Class Section (Enlarged)
                                Text(
                                  scannedStudent!.classSection,
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Student ID
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.badge,
                                        size: 24,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Student ID',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            scannedStudent!.studentId,
                                            style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 16),

                                // Exit Time
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 24,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Exit Time',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _formatCurrentTime(),
                                            style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Early Dismissal Indicator
                                if (currentScheduleCheck != null && 
                                    currentScheduleCheck!['exitType'] == 'early_dismissal') ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 24,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Early Dismissal Approved',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                currentScheduleCheck!['earlyDismissal']['reason'] ?? 'No reason provided',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Emergency Exit Indicator
                                if (currentScheduleCheck != null && 
                                    currentScheduleCheck!['exitType'] == 'emergency_exit') ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.emergency,
                                          size: 24,
                                          color: Colors.red[600],
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Emergency Exit Approved',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.red[700],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'Approved by teacher: ${currentScheduleCheck!['emergencyExit']['markedBy']['fname'] ?? ''} ${currentScheduleCheck!['emergencyExit']['markedBy']['lname'] ?? ''}'.trim(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Verification Badge
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 24,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'VERIFIED STUDENT',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 24),

              // Right - Authorized Fetchers Panel (Enhanced for better readability)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.blue[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.people,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AUTHORIZED FETCHERS',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Select pickup person',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Fetchers List
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: _buildEnhancedFetchersList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Bottom - Action Buttons (Enlarged)
        Container(
          height: 80,
          child: Row(
            children: [
              // Approve Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (fetchers != null && fetchers!.isNotEmpty)
                          ? () => handleApproval(true)
                          : null,
                  icon: Icon(Icons.check_circle, size: 32),
                  label: Text(
                    'APPROVE PICKUP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.green.withOpacity(0.3),
                  ),
                ),
              ),

              SizedBox(width: 16),

              // PIN Verification Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showTemporaryFetcherDialog(),
                  icon: Icon(Icons.pin, size: 32),
                  label: Text(
                    'VERIFY PIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                ),
              ),

              SizedBox(width: 16),

              // Deny Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDenyReasonDialog(),
                  icon: Icon(Icons.cancel, size: 32),
                  label: Text(
                    'DENY PICKUP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.red.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTempFetcherVerificationLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column - Student Information
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pin, size: 32, color: Colors.white),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temporary Fetcher Verification',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'PIN verified - Review fetcher details',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Student Information Card (same as exit mode)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Student Photo and Basic Info Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Photo Section
                          Column(
                            children: [
                              _buildStudentImage(
                                imageUrl: scannedStudent!.imageUrl,
                                width: 180,
                                height: 180,
                                borderRadius: 16,
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'VERIFIED STUDENT',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(width: 32),

                          // Student Information Section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Student Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 16),

                                Text(
                                  scannedStudent!.fullName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),

                                Text(
                                  scannedStudent!.classSection,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 24),

                                // Information Grid (2x2)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Student ID',
                                        scannedStudent!.studentId,
                                        Icons.badge,
                                        Colors.blue,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Exit Time',
                                        _formatCurrentTime(),
                                        Icons.access_time,
                                        Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),

                                Row(
                                  children: [
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCard(
                                        'Verification',
                                        'PIN Verified',
                                        Icons.security,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Additional Student Information
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Address',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        scannedStudent!.address,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gender',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        scannedStudent!.gender ??
                                            'Not specified',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 32),

        // Right Column - Temporary Fetcher Information
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temp Fetcher Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_pin,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temporary Fetcher',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'PIN verified - Review details below',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
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

              SizedBox(height: 20),

              // Temp Fetcher Details Card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16), // Reduced padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PIN Status Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green[600],
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PIN VERIFIED',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Fetcher Name
                        Text(
                          verifiedTempFetcher!['fetcher_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 20, // Reduced from 24
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12), // Reduced spacing
                        // Compact fetcher details using a more space-efficient layout
                        _buildCompactDetailRow(
                          'Relationship',
                          verifiedTempFetcher!['relationship'] ??
                              'Not specified',
                          Icons.family_restroom,
                        ),
                        SizedBox(height: 10),

                        _buildCompactDetailRow(
                          'Contact',
                          verifiedTempFetcher!['contact_number'] ??
                              'Not provided',
                          Icons.phone,
                        ),
                        SizedBox(height: 10),

                        _buildCompactDetailRow(
                          'PIN Code',
                          verifiedTempFetcher!['pin_code'].toString(),
                          Icons.pin,
                        ),

                        // Conditional fields in a more compact format
                        if (verifiedTempFetcher!['id_type'] != null ||
                            verifiedTempFetcher!['id_number'] != null) ...[
                          SizedBox(height: 10),
                          _buildCompactDetailRow(
                            'ID Info',
                            '${verifiedTempFetcher!['id_type'] ?? 'ID'}: ${verifiedTempFetcher!['id_number'] ?? 'Not provided'}',
                            Icons.credit_card,
                          ),
                        ],

                        if (verifiedTempFetcher!['emergency_contact'] !=
                            null) ...[
                          SizedBox(height: 10),
                          _buildCompactDetailRow(
                            'Emergency',
                            verifiedTempFetcher!['emergency_contact'],
                            Icons.emergency,
                          ),
                        ],

                        SizedBox(height: 10),
                        _buildCompactDetailRow(
                          'Valid Date',
                          verifiedTempFetcher!['valid_date'] ?? 'Today',
                          Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Action Buttons for Temp Fetcher
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16), // Reduced from 20
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Approve button
                    SizedBox(
                      width: double.infinity,
                      height: 44, // Slightly smaller
                      child: ElevatedButton.icon(
                        onPressed: () => _processTempFetcherPickup(true),
                        icon: Icon(Icons.check_circle, size: 18),
                        label: Text(
                          'Approve Pickup',
                          style: TextStyle(fontSize: 14), // Smaller font
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 10), // Reduced spacing
                    // Back to PIN entry
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            verifiedTempFetcher = null;
                            isShowingTempFetcher = false;
                          });
                        },
                        icon: Icon(Icons.arrow_back, size: 18),
                        label: Text(
                          'Back to PIN Entry',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    // Deny button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _showTempFetcherDenyReasonDialog(),
                        icon: Icon(Icons.cancel, size: 18),
                        label: Text(
                          'Deny Pickup',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.blue[600]), // Smaller icon
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12, // Smaller font
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14, // Smaller font
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New deny reason dialog specifically for temp fetchers
  void _showTempFetcherDenyReasonDialog() async {
    final reasons = [
      'Invalid ID presented',
      'Suspicious behavior',
      'Information mismatch',
      'Student refused to go',
      'Other',
    ];
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Deny Temporary Fetcher Pickup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Please select a reason for denying this temporary fetcher pickup:',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    hint: Text(
                      'Select a reason',
                      style: TextStyle(fontSize: 16),
                    ),
                    items:
                        reasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(reason, style: TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                        if (value != 'Other') {
                          customReasonController.text = '';
                        }
                        errorText = null;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: customReasonController,
                    decoration: InputDecoration(
                      labelText: 'Custom reason',
                      labelStyle: TextStyle(fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabled: selectedReason == 'Other',
                    ),
                    style: TextStyle(fontSize: 16),
                    minLines: 2,
                    maxLines: 3,
                    enabled: selectedReason == 'Other',
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        errorText!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(fontSize: 16)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String reasonToSave = '';
                    if (selectedReason == null) {
                      setState(() {
                        errorText = "Please select a reason.";
                      });
                      return;
                    } else if (selectedReason == 'Other') {
                      if (customReasonController.text.trim().isEmpty) {
                        setState(() {
                          errorText = "Please provide a custom reason.";
                        });
                        return;
                      }
                      reasonToSave = customReasonController.text.trim();
                    } else {
                      reasonToSave = selectedReason!;
                    }
                    Navigator.pop(context, reasonToSave);
                  },
                  child: Text('Confirm', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is String && result.isNotEmpty) {
        _processTempFetcherPickup(false, denyReason: result);
      }
    });
  }

  // Enhanced fetchers list with better accessibility
  Widget _buildEnhancedFetchersList() {
    if (isLoadingFetchers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue, strokeWidth: 4),
            SizedBox(height: 20),
            Text(
              'Loading authorized fetchers...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (fetchers == null || fetchers!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange[400],
            ),
            SizedBox(height: 20),
            Text(
              'NO AUTHORIZED FETCHERS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[600],
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This student has no registered\nparents or guardians.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: fetchers!.length,
      separatorBuilder: (context, index) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final fetcher = fetchers![index];
        return _buildEnhancedFetcherCard(fetcher);
      },
    );
  }

  // Enhanced fetcher card with larger text and better visibility
  Widget _buildEnhancedFetcherCard(Fetcher fetcher) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fetcher Photo and Name Row
          Row(
            children: [
              // Fetcher Photo (Enlarged)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildFetcherImageContent(fetcher.imageUrl),
                ),
              ),
              SizedBox(width: 20),

              // Fetcher Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name (Significantly Enlarged)
                    Text(
                      fetcher.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    // Badges Row
                    Row(
                      children: [
                        if (fetcher.isPrimary) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 16, color: Colors.blue),
                                SizedBox(width: 6),
                                Text(
                                  'PRIMARY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'AUTHORIZED',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
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
            ],
          ),

          SizedBox(height: 16),

          // Details Section (Enlarged Text)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Relationship
                Row(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 20,
                      color: Colors.purple[600],
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Relationship',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          fetcher.relationship,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Contact
                Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: Colors.green[600]),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Number',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          fetcher.contact,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // method for fetcher image handling
  Widget _buildFetcherImageContent(String? imageUrl) {
    // Check if we have a valid image URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildFetcherPlaceholderImage();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildFetcherLoadingImage();
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading fetcher image: $error');
        return _buildFetcherPlaceholderImage();
      },
    );
  }

  Widget _buildFetcherPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.person, size: 30, color: Colors.grey[500]),
    );
  }

  Widget _buildFetcherLoadingImage() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }

  // Add this method to show temporary fetcher PIN dialog
  void _showTemporaryFetcherDialog() {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.pin, color: Colors.blue, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Verify Temporary Fetcher PIN'),
                            if (scannedStudent != null)
                              Text(
                                'for ${scannedStudent!.fullName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter the PIN provided by the temporary fetcher:',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: pinController,
                        decoration: InputDecoration(
                          labelText: 'PIN Code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Enter PIN (e.g., 696991)',
                          errorText: errorMessage,
                          prefixIcon: Icon(Icons.security),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, letterSpacing: 2),
                        onChanged: (value) {
                          // Clear error when user types
                          if (errorMessage != null) {
                            setState(() {
                              errorMessage = null;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[600], size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PIN is valid only for today and can be used once.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final pin = pinController.text.trim();

                        if (pin.isEmpty) {
                          setState(() {
                            errorMessage = 'Please enter a PIN';
                          });
                          return;
                        }

                        if (pin.length < 1 || pin.length > 6) {
                          setState(() {
                            errorMessage = 'PIN must be 1-6 digits';
                          });
                          return;
                        }

                        if (!RegExp(r'^\d+$').hasMatch(pin)) {
                          setState(() {
                            errorMessage = 'PIN must contain only numbers';
                          });
                          return;
                        }

                        if (scannedStudent != null) {
                          Navigator.pop(context);
                          await _verifyAndProcessTemporaryFetcher(pin);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Verify PIN'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Override Mode Layout
  Widget _buildOverrideModeLayout() {
    if (scannedStudent != null) {
      // Student selected - show normal entry/exit flow
      if (currentAction == 'entry') {
        return _buildEntryModeLayout();
      } else {
        return _buildExitModeLayout();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Override Mode Header
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange[50]!, Colors.red[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange[200]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.security,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GUARD OVERRIDE MODE ACTIVE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Search and select a student to process manually',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[700],
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Override mode active - Close manually when done',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exitOverrideMode('Manual exit by guard'),
                icon: Icon(Icons.close, size: 20),
                label: Text('Exit Override'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Search Section
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left - Search Panel
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STUDENT SEARCH',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Search by name, ID, or class',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Search Input
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Students',
                          hintText: 'Enter student name, class, or grade...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchStudents('');
                                  },
                                )
                              : null,
                        ),
                        style: TextStyle(fontSize: 16),
                        onChanged: (value) {
                          _searchStudents(value);
                        },
                      ),

                      SizedBox(height: 24),

                      // Search Results
                      Expanded(
                        child: _buildSearchResults(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 24),

              // Right - Instructions Panel
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructions Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'OVERRIDE INSTRUCTIONS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Instructions List
                      _buildInstructionItem(
                        Icons.credit_card,
                        'Guard RFID Scanned',
                        'Your guard RFID card activated override mode',
                        Colors.orange,
                      ),
                      SizedBox(height: 16),

                      _buildInstructionItem(
                        Icons.search,
                        'Search Student',
                        'Type student name, class, or grade in search box',
                        Colors.blue,
                      ),
                      SizedBox(height: 16),

                      _buildInstructionItem(
                        Icons.touch_app,
                        'Select Student',
                        'Tap on a student from search results to select',
                        Colors.green,
                      ),
                      SizedBox(height: 16),

                      _buildInstructionItem(
                        Icons.verified,
                        'Process Manually',
                        'Entry/exit will be processed without RFID card',
                        Colors.purple,
                      ),
                      SizedBox(height: 16),

                      _buildInstructionItem(
                        Icons.timer,
                        'Auto-Timeout',
                        'Mode automatically exits after 30 seconds',
                        Colors.red,
                      ),

                      Spacer(),

                      // Emergency Note
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              size: 20,
                              color: Colors.red[600],
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Override Usage',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Use only for lost RFID cards or emergency situations. All actions are logged.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Searching students...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Start typing to search',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter student name, grade, or class',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults == null || _searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.orange[400],
            ),
            SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.orange[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _searchResults!.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = _searchResults![index];
        return _buildStudentSearchCard(student);
      },
    );
  }

  Widget _buildStudentSearchCard(Student student) {
    return InkWell(
      onTap: () => _selectStudentInOverrideMode(student),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Student Photo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildImageContent(student.imageUrl),
              ),
            ),

            SizedBox(width: 16),

            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    student.classSection,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    student.studentId,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Select Button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SELECT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Floating notification widget
  Widget _buildFloatingNotification() {
    final formattedDate =
        actionTimestamp != null
            ? "${actionTimestamp!.year}-${actionTimestamp!.month.toString().padLeft(2, '0')}-${actionTimestamp!.day.toString().padLeft(2, '0')}"
            : '';

    final formattedTime =
        actionTimestamp != null
            ? "${actionTimestamp!.hour.toString().padLeft(2, '0')}:${actionTimestamp!.minute.toString().padLeft(2, '0')}:${actionTimestamp!.second.toString().padLeft(2, '0')}"
            : '';

    return Positioned(
      top: 80, // Positioned below the debug controls
      right: 24,
      child: AnimatedOpacity(
        opacity: showNotification ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          constraints: BoxConstraints(maxWidth: 350),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notificationColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                notificationColor == Colors.red
                    ? Icons.error
                    : (fetchStatus == 'approved'
                        ? Icons.check_circle
                        : (fetchStatus == 'denied'
                            ? Icons.cancel
                            : Icons.info)),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notificationMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (notificationColor != Colors.red &&
                        formattedDate.isNotEmpty)
                      const SizedBox(height: 4),
                    if (notificationColor != Colors.red &&
                        formattedDate.isNotEmpty)
                      Text(
                        '$formattedDate $formattedTime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    if (notificationColor != Colors.red && fetchStatus != null)
                      Text(
                        'Record saved to database',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    showNotification = false;
                  });
                },
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
