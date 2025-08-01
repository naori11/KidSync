import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';
import '../../models/guard_models.dart';

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
  String? fetchStatus; // "approved", "denied", or null
  bool showNotification = false;
  String notificationMessage = '';
  Color notificationColor = Colors.green;
  DateTime? actionTimestamp;
  bool isLoadingStudent = false;
  bool isLoadingFetchers = false;
  bool isEntryMode = false;
  bool isAwaitingDecision = false;

  late HtmlWebSocketChannel channel;

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

      // BLOCK SCANS if a decision is pending in Exit Mode
      if (!isEntryMode && isAwaitingDecision) {
        _showErrorNotification(
          'Please approve or deny the current pick-up before scanning another student.',
        );
        return; // Ignore new scans until decision is made or reset
      }

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

  // Function to fetch student data from Supabase
  Future<void> _fetchStudentByRFID(String rfidUid) async {
    setState(() {
      isLoadingStudent = true;
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
    });

    try {
      final response =
          await supabase
              .from('students')
              .select()
              .eq('rfid_uid', rfidUid)
              .neq('status', 'deleted')
              .maybeSingle();

      if (response != null) {
        final student = Student.fromJson(response);
        setState(() {
          scannedStudent = student;
          isLoadingStudent = false;
          // Only set block in EXIT mode
          if (!isEntryMode) isAwaitingDecision = true;
        });

        // Only fetch fetchers in exit mode
        if (!isEntryMode) {
          await _fetchAuthorizedFetchers(student.id);
        }

        // ENTRY MODE: Log "Checked In" immediately and auto-hide
        if (isEntryMode) {
          await supabase.from('scan_records').insert({
            'student_id': student.id,
            'guard_id': user?.id,
            'rfid_uid': student.rfidUid ?? '',
            'scan_time': DateTime.now().toIso8601String(),
            'action': 'entry',
            'verified_by': 'RFID Entry',
            'status': 'Checked In',
            'notes': '',
          });

          // Show success notification for entry mode
          _showSuccessNotification('Student checked in successfully');

          // Auto-hide scanned student after 3 seconds
          Future.delayed(Duration(seconds: 3), () {
            if (mounted && isEntryMode) clearScan();
          });
        }
      } else {
        setState(() {
          isLoadingStudent = false;
          // Reset block if student not found in EXIT mode
          if (!isEntryMode) isAwaitingDecision = false;
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

  // Function to fetch authorized fetchers from database
  Future<void> _fetchAuthorizedFetchers(int studentId) async {
    setState(() {
      isLoadingFetchers = true;
      fetchers = null;
    });

    try {
      print('Fetching authorized fetchers for student ID: $studentId');

      // Fetch parent-student relationships with parent information
      final response = await supabase
          .from('parent_student')
          .select('''
            relationship_type,
            is_primary,
            parents!inner(
              id, fname, mname, lname, phone, email, address, status
            )
          ''')
          .eq('student_id', studentId);

      print('Fetchers response: $response');

      if (response.isNotEmpty) {
        final List<Fetcher> fetchersList = [];

        for (final relationshipData in response) {
          final parentData = relationshipData['parents'];

          // Only include active parents
          if (parentData != null &&
              (parentData['status'] == null ||
                  parentData['status'] == 'active')) {
            final fetcher = Fetcher.fromParentData(
              parentData,
              relationshipData,
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
        print('No authorized fetchers found for student ID: $studentId');
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
      isAwaitingDecision = false;
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
              ? 'Pickup approved at $formattedTime'
              : 'Pickup denied at $formattedTime';
      notificationColor = approved ? Colors.green : Colors.red;
      actionTimestamp = now;
      isAwaitingDecision = false;
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

  // Save approval/denial to scan_records
  Future<void> _savePickupRecord(bool approved, {String? denyReason}) async {
    if (scannedStudent == null) return;
    try {
      final verifiedBy =
          fetchers?.isNotEmpty == true
              ? fetchers!.first.relationship
              : "Unknown";
      final action = approved ? "approved" : "denied";
      final status = approved ? "Checked Out" : "Denied";
      await supabase.from('scan_records').insert({
        'student_id': scannedStudent!.id,
        'guard_id': user?.id,
        'rfid_uid': scannedStudent!.rfidUid ?? '',
        'scan_time': DateTime.now().toIso8601String(),
        'action': action,
        'verified_by': verifiedBy,
        'status': status,
        'notes': !approved ? (denyReason ?? "Denied by guard") : "",
      });
    } catch (e) {
      print('Error saving pickup record: $e');
    }
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
          child: isEntryMode ? _buildEntryModeLayout() : _buildExitModeLayout(),
        ),

        // Debug controls in upper right corner
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mode Switch Button
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
                      isEntryMode = !isEntryMode;
                      clearScan();
                    });
                  },
                  icon: Icon(
                    isEntryMode ? Icons.logout : Icons.login,
                    size: 16,
                  ),
                  label: Text(
                    isEntryMode
                        ? 'Switch to Exit Mode'
                        : 'Switch to Entry Mode',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isEntryMode ? Colors.green : Colors.blue,
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

  // Consistent "before scan" widget for both modes
  Widget _buildBeforeScanWidget() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left side - RFID scan prompt
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!, width: 1),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isEntryMode ? Colors.blue[50] : Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.contact_page,
                    size: 48,
                    color: isEntryMode ? Colors.blue : Colors.green,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Tap RFID Card',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  isEntryMode
                      ? 'Students can tap their card to check in'
                      : 'Students can tap their card for pickup verification',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEntryMode ? Colors.blue[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEntryMode ? Icons.login : Icons.logout,
                        size: 16,
                        color:
                            isEntryMode ? Colors.blue[700] : Colors.green[700],
                      ),
                      SizedBox(width: 8),
                      Text(
                        isEntryMode ? 'ENTRY MODE' : 'EXIT MODE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isEntryMode
                                  ? Colors.blue[700]
                                  : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 24),

        // Right side - Information panel
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!, width: 1),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEntryMode ? 'Entry Information' : 'Exit Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),

                  if (isEntryMode) ...[
                    _buildInfoItem(
                      Icons.schedule,
                      'Quick Check-in',
                      'Students scan and are immediately checked in',
                      Colors.blue,
                    ),
                    SizedBox(height: 16),
                    _buildInfoItem(
                      Icons.verified,
                      'Automatic Recording',
                      'Entry time is automatically logged in the system',
                      Colors.blue,
                    ),
                    SizedBox(height: 16),
                    _buildInfoItem(
                      Icons.notifications,
                      'Instant Confirmation',
                      'Students see immediate confirmation of check-in',
                      Colors.blue,
                    ),
                  ] else ...[
                    _buildInfoItem(
                      Icons.people,
                      'Fetcher Verification',
                      'System will show authorized pickup persons',
                      Colors.green,
                    ),
                    SizedBox(height: 16),
                    _buildInfoItem(
                      Icons.security,
                      'Manual Approval',
                      'Guard must approve or deny each pickup request',
                      Colors.green,
                    ),
                    SizedBox(height: 16),
                    _buildInfoItem(
                      Icons.assignment,
                      'Record Keeping',
                      'All pickup decisions are logged with reasons',
                      Colors.green,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Entry mode layout - full page with complete student information
  Widget _buildEntryModeLayout() {
    if (isLoadingStudent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Loading Student Data...',
              style: TextStyle(
                fontSize: 18,
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

    // Full page entry mode layout
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
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
                    child: Icon(
                      Icons.check_circle,
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
                          'Student Successfully Checked In',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Entry recorded automatically at ${_formatCurrentTime()}',
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

            // Main Student Information Card
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Photo Section
                    Column(
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              scannedStudent!.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.person,
                                    size: 100,
                                    color: Colors.grey[500],
                                  ),
                                );
                              },
                            ),
                          ),
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

                    SizedBox(width: 40),

                    // Student Information Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Name
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
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),

                          Text(
                            scannedStudent!.classSection,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 32),

                          // Information Grid
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
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoCard(
                                  'Check-in Time',
                                  _formatCurrentTime(),
                                  Icons.access_time,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'RFID Status',
                                  'Active',
                                  Icons.nfc,
                                  Colors.orange,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoCard(
                                  'Attendance Status',
                                  'Present',
                                  Icons.how_to_reg,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),

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
                                if (scannedStudent!.birthday != null) ...[
                                  SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date of Birth',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        scannedStudent!.birthday!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

            SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: clearScan,
                icon: Icon(Icons.refresh, size: 24),
                label: Text(
                  'Scan Another Student',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  // Exit mode layout - responsive design based on screenshot
  Widget _buildExitModeLayout() {
    if (isLoadingStudent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 24),
            Text(
              'Loading Student Data...',
              style: TextStyle(
                fontSize: 18,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column - Student Verification
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Verification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Scan RFID card to verify student',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),

              // Student Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Student Photo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            scannedStudent!.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[500],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Student Name
                      Text(
                        scannedStudent!.fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),

                      // Grade & Section
                      Text(
                        scannedStudent!.classSection,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),

                      // Verified Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
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
                              'Verified',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Spacer(),

                      // Student Details
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              scannedStudent!.studentId,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Emergency Contact',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _getEmergencyContact(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
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

        SizedBox(width: 24),

        // Right Column - Authorized Fetchers
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authorized Fetcher',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 20),

              // Fetchers List
              Expanded(child: _buildFetchersList()),

              SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  String _getEmergencyContact() {
    if (fetchers != null && fetchers!.isNotEmpty) {
      final primaryParent = fetchers!.firstWhere(
        (f) => f.isPrimary,
        orElse: () => fetchers!.first,
      );
      return primaryParent.contact;
    }
    return '+1 (555) 123-4567';
  }

  Widget _buildFetchersList() {
    if (isLoadingFetchers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Loading authorized fetchers...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
              size: 48,
              color: Colors.orange[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Authorized Fetchers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This student has no registered\nparents or guardians.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
        return _buildFetcherCard(fetcher);
      },
    );
  }

  Widget _buildFetcherCard(Fetcher fetcher) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fetcher Photo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fetcher.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey[500],
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 16),

          // Fetcher Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  fetcher.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),

                // Relationship
                Text(
                  'Relationship: ${fetcher.relationship}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),

                // Contact
                Text(
                  'Contact: ${fetcher.contact}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),

                // Authorized Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'AUTHORIZED',
                        style: TextStyle(
                          fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Approve Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed:
                (fetchers != null && fetchers!.isNotEmpty)
                    ? () => handleApproval(true)
                    : null,
            icon: Icon(Icons.check_circle, size: 20),
            label: Text(
              'Approve Pick-up',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  (fetchers != null && fetchers!.isNotEmpty)
                      ? Colors.green
                      : Colors.grey[300],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: (fetchers != null && fetchers!.isNotEmpty) ? 2 : 0,
            ),
          ),
        ),
        SizedBox(height: 12),

        // Deny Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _showDenyReasonDialog,
            icon: Icon(Icons.block, size: 20),
            label: Text(
              'Deny Pick-up',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
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
