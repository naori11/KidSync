import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';
import '../../models/guard_models.dart';
import '../../services/notification_service.dart';

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

  // Remove isEntryMode and isAwaitingDecision - replaced with auto detection
  String? currentAction; // 'entry' or 'exit'
  bool isScheduleValidationEnabled = true;
  bool isOverrideMode = false;
  String? scheduleValidationMessage;
  TimeOfDay? lastClassEndTime;

  late HtmlWebSocketChannel channel;
  final NotificationService _notificationService = NotificationService();

  // Make cooldown tracking static so it persists across page navigations
  static Map<String, DateTime> rfidCooldowns = {};
  static const int cooldownSeconds = 30; // 30 second cooldown

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket channel
    channel = HtmlWebSocketChannel.connect(
      'wss://rfid-websocket-server.onrender.com',
    );

    // Listen for incoming RFID data
    channel.stream.listen((message) {
      print("RFID received: $message");

      try {
        String? uid;

        // Try to parse as JSON first
        try {
          final Map<String, dynamic> parsedMessage = json.decode(message);
          if (parsedMessage['type'] == 'rfid_scan' &&
              parsedMessage['uid'] != null) {
            uid = parsedMessage['uid'];
          }
        } catch (jsonError) {
          // If JSON parsing fails, treat the message as a raw UID string
          String rawData = message.toString().trim();
          if (rawData.isNotEmpty && rawData.length > 4) {
            uid = rawData;
          }
        }

        if (uid != null) {
          // Fetch real student data from database
          _fetchStudentByRFID(uid);
        }
      } catch (e) {
        print('Error processing WebSocket message: $e');
        _showErrorNotification('Error processing RFID scan');
      }
    });
  }

  @override
  void dispose() {
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

      // Query the section_teachers table for today's classes
      if (student.sectionId == null) {
        return {'canExit': true, 'message': null, 'exitType': 'regular'};
      }

      final response = await supabase
          .from('section_teachers')
          .select('end_time, subject, start_time')
          .eq('section_id', student.sectionId!)
          .contains('days', [today])
          .order('end_time', ascending: false);

      print('Schedule response: $response');

      if (response.isNotEmpty) {
        // Get the last class of the day
        final lastClass = response.first;
        final endTimeStr = lastClass['end_time']; // Format: "HH:MM:SS"
        final subjectName = lastClass['subject'];

        if (endTimeStr != null) {
          final endTime = _parseTimeString(endTimeStr);
          final minutesUntilEnd = _getMinutesDifference(currentTime, endTime);

          print('Current time: ${_formatTime(currentTime)}');
          print('Last class ends: ${_formatTime(endTime)}');
          print('Minutes until end: $minutesUntilEnd');

          // Exit validation logic based on your requirements
          if (minutesUntilEnd > 120) {
            // Very Early Exit (2+ hours before last class)
            return {
              'canExit': false,
              'message':
                  'Very early dismissal requested. Last class ($subjectName) ends at ${_formatTime(endTime)}',
              'lastClassEndTime': endTime,
              'subject': subjectName,
              'exitType': 'very_early',
              'requiresReason': true,
            };
          } else if (minutesUntilEnd > 30) {
            // Early Exit (30+ minutes before last class)
            return {
              'canExit': false,
              'message':
                  'Early dismissal requested. Last class ($subjectName) ends at ${_formatTime(endTime)}',
              'lastClassEndTime': endTime,
              'subject': subjectName,
              'exitType': 'early',
              'requiresReason': false,
            };
          } else if (minutesUntilEnd > 15) {
            // Near End Time (15-30 minutes before last class)
            return {
              'canExit': true,
              'message':
                  'Approved near-end dismissal. Last class ($subjectName) ends at ${_formatTime(endTime)}',
              'exitType': 'near_end',
              'subject': subjectName,
            };
          } else if (minutesUntilEnd > 0) {
            // Within 15 minutes of last class
            return {
              'canExit': true,
              'message':
                  'Approved dismissal. Last class ($subjectName) ends soon at ${_formatTime(endTime)}',
              'exitType': 'within_15min',
              'subject': subjectName,
            };
          }
        }
      }

      // Regular dismissal (after last class or no classes today)
      return {'canExit': true, 'message': null, 'exitType': 'regular'};
    } catch (e) {
      print('Error checking schedule: $e');
      return {'canExit': true, 'message': null, 'exitType': 'error'};
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
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return dayNames[now.weekday % 7];
  }

  // Modified fetch student method - simplified entry handling
  Future<void> _fetchStudentByRFID(String rfidUid) async {
    _cleanupCooldowns();

    // Check cooldown
    final now = DateTime.now();
    if (rfidCooldowns.containsKey(rfidUid)) {
      final lastScan = rfidCooldowns[rfidUid]!;
      final timeDiff = now.difference(lastScan).inSeconds;

      if (timeDiff < cooldownSeconds) {
        final remainingTime = cooldownSeconds - timeDiff;
        _showErrorNotification(
          'Please wait ${remainingTime}s before scanning again',
        );
        return;
      }
    }

    // Set cooldown for this RFID
    rfidCooldowns[rfidUid] = now;

    setState(() {
      isLoadingStudent = true;
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
      currentAction = null;
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

        // Determine if this should be entry or exit
        final action = await _checkTodayAttendanceStatus(student.id);

        setState(() {
          scannedStudent = student;
          currentAction = action;
          isLoadingStudent = false;
        });

        if (action == 'entry') {
          // Entry: Always allow for elementary students
          await _processEntry(student);
        } else {
          // Exit: Apply schedule validation
          if (isScheduleValidationEnabled && !isOverrideMode) {
            final scheduleCheck = await _checkClassSchedule(student);

            if (!scheduleCheck['canExit']) {
              setState(() {
                scheduleValidationMessage = scheduleCheck['message'];
                lastClassEndTime = scheduleCheck['lastClassEndTime'];
              });

              // Show different UI based on exit type
              final exitType = scheduleCheck['exitType'];
              if (exitType == 'very_early') {
                // Very early exit requires reason selection
                _showVeryEarlyExitDialog(scheduleCheck);
              } else {
                // Regular early exit just needs override confirmation
                return; // This will show the schedule blocked layout
              }
              return;
            }
          }
          await _processExit(student);
        }
      } else {
        setState(() {
          isLoadingStudent = false;
        });
        _showErrorNotification('Student not found or inactive');
      }
    } catch (e) {
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
  }

  // Process entry (immediate check-in)
  Future<void> _processEntry(Student student) async {
    try {
      await supabase.from('scan_records').insert({
        'student_id': student.id,
        'guard_id': user?.id,
        'rfid_uid': student.rfidUid ?? '',
        'scan_time': DateTime.now().toIso8601String(),
        'action': 'entry',
        'verified_by': 'RFID Entry',
        'status': 'Checked In',
        'notes': 'Automatic entry via RFID scan',
      });

      // Send RFID entry notification to parents
      print('DEBUG: About to send RFID entry notification for student ${student.id}');
      final notificationSent = await _notificationService.sendRfidTapNotification(
        studentId: student.id,
        action: 'entry',
        studentName: '${student.fname} ${student.lname}',
      );
      print('DEBUG: RFID entry notification sent: $notificationSent');

      _showSuccessNotification('Student checked in successfully');

      // Auto-hide after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) clearScan();
      });
    } catch (e) {
      _showErrorNotification('Error recording entry: ${e.toString()}');
    }
  }

  // Process exit (show fetchers and require approval)
  Future<void> _processExit(Student student) async {
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
        setState(() {
          verifiedTempFetcher = tempFetcher;
          isShowingTempFetcher = true;
        });

        _showSuccessNotification(
          'PIN verified successfully! Please review fetcher details.',
        );
      } else {
        await _showDetailedPinErrorNotification(pin, scannedStudent!.id);
      }
    } catch (e) {
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
        });

        // Send RFID exit notification to parents
        print('DEBUG: About to send RFID exit notification for student ${scannedStudent!.id}');
        final notificationSent = await _notificationService.sendRfidTapNotification(
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
        });

        // Send pickup denial notification to parents
        print('DEBUG: About to send temporary fetcher pickup denial notification for student ${scannedStudent!.id}');
        
        // Get guard name for the notification
        String? guardName;
        if (user?.id != null) {
          try {
            final guardResponse = await supabase
                .from('users')
                .select('fname, lname')
                .eq('id', user!.id)
                .maybeSingle();
            if (guardResponse != null) {
              guardName = '${guardResponse['fname'] ?? ''} ${guardResponse['lname'] ?? ''}'.trim();
            }
          } catch (e) {
            print('Error getting guard name: $e');
          }
        }
        
        final notificationSent = await _notificationService.sendPickupDenialNotification(
          studentId: scannedStudent!.id,
          studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
          denyReason: denyReason ?? 'No reason provided',
          guardName: guardName,
          fetcherName: verifiedTempFetcher!['fetcher_name'],
          fetcherType: 'temporary',
        );
        print('DEBUG: Temporary fetcher pickup denial notification sent: $notificationSent');

        _showErrorNotification(
          'Pickup denied: ${denyReason ?? 'Access denied'}',
        );
      }

      // Auto-clear after success/denial
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) clearScan();
      });
    } catch (e) {
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

  // Show override dialog for early dismissal
  void _showOverrideDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text(
                  'Early Dismissal Override',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Schedule Conflict',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        scheduleValidationMessage ??
                            'Classes are still in session.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Student Information:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(scannedStudent!.imageUrl),
                      onBackgroundImageError: (_, __) {},
                      child:
                          scannedStudent!.imageUrl.isEmpty
                              ? Icon(Icons.person)
                              : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scannedStudent!.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            scannedStudent!.classSection,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.red[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will log an early dismissal override in the system.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
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
                onPressed: () {
                  Navigator.pop(context);
                  clearScan();
                },
                child: Text('Cancel'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isOverrideMode = true;
                  });
                  _processExit(scannedStudent!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Allow Early Exit'),
              ),
            ],
          ),
    );
  }

  // New dialog for very early exits that require a reason
  void _showVeryEarlyExitDialog(Map<String, dynamic> scheduleCheck) {
    final reasons = [
      'Medical appointment',
      'Family emergency',
      'Early pickup requested by parent',
      'Student illness',
      'Other',
    ];
    String? selectedReason;
    TextEditingController customReasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Very Early Dismissal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: Colors.red[700],
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Schedule Alert',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              scheduleValidationMessage ??
                                  'Very early dismissal (2+ hours before last class)',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),

                      Text(
                        'Reason for Early Dismissal:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        hint: Text('Select a reason'),
                        items:
                            reasons.map((reason) {
                              return DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedReason = value;
                            if (value != 'Other') {
                              customReasonController.text = '';
                            }
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
                      ),

                      if (selectedReason == 'Other') ...[
                        SizedBox(height: 16),
                        TextField(
                          controller: customReasonController,
                          decoration: InputDecoration(
                            labelText: 'Please specify reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        clearScan();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        String reasonToSave = '';
                        if (selectedReason == null) {
                          // Show error
                          return;
                        } else if (selectedReason == 'Other') {
                          if (customReasonController.text.trim().isEmpty) {
                            // Show error
                            return;
                          }
                          reasonToSave = customReasonController.text.trim();
                        } else {
                          reasonToSave = selectedReason!;
                        }

                        Navigator.pop(context);
                        setState(() {
                          isOverrideMode = true;
                          scheduleValidationMessage =
                              reasonToSave; // Store the reason
                        });
                        _processExit(scannedStudent!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Allow Very Early Exit'),
                    ),
                  ],
                ),
          ),
    );
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
      if (!approved) {
        notes = denyReason ?? "Denied by guard";
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
          notes = "Early dismissal override - Schedule validation bypassed";
        }
      } else {
        notes = "Regular exit after class hours";
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
      });

      // Send RFID exit notification to parents only if approved
      if (approved) {
        print('DEBUG: About to send RFID exit notification for student ${scannedStudent!.id} (regular pickup)');
        final notificationSent = await _notificationService.sendRfidTapNotification(
          studentId: scannedStudent!.id,
          action: 'exit',
          studentName: '${scannedStudent!.fname} ${scannedStudent!.lname}',
        );
        print('DEBUG: RFID exit notification sent (regular pickup): $notificationSent');
      } else {
        // Send pickup denial notification to parents
        print('DEBUG: About to send pickup denial notification for student ${scannedStudent!.id}');
        
        // Get guard name for the notification
        String? guardName;
        if (user?.id != null) {
          try {
            final guardResponse = await supabase
                .from('users')
                .select('fname, lname')
                .eq('id', user!.id)
                .maybeSingle();
            if (guardResponse != null) {
              guardName = '${guardResponse['fname'] ?? ''} ${guardResponse['lname'] ?? ''}'.trim();
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
        
        final notificationSent = await _notificationService.sendPickupDenialNotification(
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
      scheduleValidationMessage = null;
      isOverrideMode = false;
      lastClassEndTime = null;
      verifiedTempFetcher = null;
      isShowingTempFetcher = false;
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
    _fetchStudentByRFID('d9e0c801');
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
                    setState(() {
                      isScheduleValidationEnabled =
                          !isScheduleValidationEnabled;
                    });
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

              // Test RFID Scan Button
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
                  onPressed: simulateRFIDScan,
                  icon: Icon(Icons.credit_card, size: 16),
                  label: Text('Test RFID Scan', style: TextStyle(fontSize: 14)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
    if (currentAction == 'entry') {
      return _buildEntryModeLayout();
    } else if (currentAction == 'exit') {
      if (isShowingTempFetcher && verifiedTempFetcher != null) {
        return _buildTempFetcherVerificationLayout();
      } else if (scheduleValidationMessage != null) {
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
                colors: [
                  Colors.blue[50]!,
                  Colors.indigo[50]!,
                ],
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

  // New layout for schedule-blocked exits
  Widget _buildScheduleBlockedLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 700),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 40, color: Colors.orange[600]),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Early Dismissal Required',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Classes are still in session',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Schedule info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Schedule Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    scheduleValidationMessage ??
                        'Classes are still in session.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Student info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        scannedStudent!.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[500],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scannedStudent!.fullName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          scannedStudent!.classSection,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            'Requesting Early Exit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: clearScan,
                    icon: Icon(Icons.cancel),
                    label: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showOverrideDialog,
                    icon: Icon(Icons.exit_to_app),
                    label: Text(
                      'Allow Early Exit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
            CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 6,
            ),
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
                colors: [
                  Colors.green[50]!,
                  Colors.blue[50]!,
                ],
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
                                    border: Border.all(color: Colors.purple[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        scannedStudent!.gender ?? 'Not specified',
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

                            if (scannedStudent!.gender != null && scannedStudent!.birthday != null) 
                              SizedBox(width: 16),

                            // Birthday
                            if (scannedStudent!.birthday != null)
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.pink[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.pink[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
            CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 6,
            ),
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
                      colors: [
                        Colors.orange[50]!,
                        Colors.red[50]!,
                      ],
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
                              child: _buildImageContent(scannedStudent!.imageUrl),
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
                                    border: Border.all(color: Colors.blue[200]!),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    border: Border.all(color: Colors.orange[200]!),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
            CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 4,
            ),
            SizedBox(height: 20),
            Text(
              'Loading authorized fetchers...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
                    Icon(
                      Icons.phone,
                      size: 20,
                      color: Colors.green[600],
                    ),
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
