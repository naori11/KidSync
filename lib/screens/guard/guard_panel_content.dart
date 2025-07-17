import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';

final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;
final userName = user?.userMetadata?['full_name'] ?? 'User';
late HtmlWebSocketChannel channel;

// Updated Student model to match your database structure
class Student {
  final int id;
  final String fname;
  final String? mname;
  final String lname;
  final String address;
  final String? birthday;
  final String? gradeLevel;
  final String? sectionId;
  final String? gender;
  final String? status;
  final String? rfidUid;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.fname,
    this.mname,
    required this.lname,
    required this.address,
    this.birthday,
    this.gradeLevel,
    this.sectionId,
    this.gender,
    this.status,
    this.rfidUid,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      fname: json['fname'],
      mname: json['mname'],
      lname: json['lname'],
      address: json['address'],
      birthday: json['birthday'],
      gradeLevel: json['grade_level']?.toString(),
      sectionId: json['section_id'],
      gender: json['gender'],
      status: json['status'],
      rfidUid: json['rfid_uid'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Helper getters for display
  String get fullName {
    if (mname != null && mname!.isNotEmpty) {
      return '$fname $mname $lname';
    }
    return '$fname $lname';
  }

  String get studentId => 'STU${id.toString().padLeft(3, '0')}';

  String get classSection {
    if (gradeLevel != null && sectionId != null) {
      return 'Grade $gradeLevel - Section $sectionId';
    } else if (gradeLevel != null) {
      return 'Grade $gradeLevel';
    }
    return 'No class assigned';
  }

  // Generate placeholder image URL (you can replace this with actual student photos later)
  String get imageUrl => 'https://i.pravatar.cc/150?u=$id';
}

// Updated Fetcher class to include database fields
class Fetcher {
  final int id;
  final String name;
  final String imageUrl;
  final String relationship;
  final String contact;
  final String email;
  final bool authorized;
  final bool isPrimary;

  Fetcher({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.relationship,
    required this.contact,
    required this.email,
    this.authorized = true,
    this.isPrimary = false,
  });

  factory Fetcher.fromParentData(Map<String, dynamic> parentData, Map<String, dynamic> relationshipData) {
    final parentInfo = parentData;
    final fullName = '${parentInfo['fname']} ${parentInfo['lname']}';
    
    return Fetcher(
      id: parentInfo['id'],
      name: fullName,
      imageUrl: 'https://i.pravatar.cc/150?u=${parentInfo['id']}', // Placeholder image
      relationship: relationshipData['relationship_type'] ?? 'Parent',
      contact: parentInfo['phone'] ?? 'No phone',
      email: parentInfo['email'] ?? 'No email',
      authorized: true, // All parents in database are considered authorized
      isPrimary: relationshipData['is_primary'] ?? false,
    );
  }
}

// Activity model for Recent Activity page
class Activity {
  final String time;
  final String studentName;
  final String gradeClass;
  final String status;
  final String verifiedBy;
  final DateTime timestamp;

  Activity({
    required this.time,
    required this.studentName,
    required this.gradeClass,
    required this.status,
    required this.verifiedBy,
    required this.timestamp,
  });
}

class GuardPanelContent extends StatefulWidget {
  const GuardPanelContent({super.key});

  @override
  State<GuardPanelContent> createState() => _GuardPanelContentState();
}

class _GuardPanelContentState extends State<GuardPanelContent> {
  int selectedIndex = 0;
  Student? scannedStudent;
  List<Fetcher>? fetchers;
  String? fetchStatus; // "approved", "denied", or null
  bool showNotification = false;
  String notificationMessage = '';
  Color notificationColor = Colors.green;
  DateTime? actionTimestamp;
  bool isLoadingStudent = false;
  bool isLoadingFetchers = false;

  // Recent Activity page state
  String searchQuery = '';
  String selectedTimePeriod = 'Today';
  final TextEditingController searchController = TextEditingController();

  // Sample activities data
  List<Activity> get sampleActivities => [
    Activity(
      time: '09:45 AM',
      studentName: 'Sarah Johnson',
      gradeClass: 'Kinder',
      status: 'Checked In',
      verifiedBy: 'Guardian',
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
    ),
    Activity(
      time: '09:30 AM',
      studentName: 'Michael Chen',
      gradeClass: 'Grade 6',
      status: 'Denied',
      verifiedBy: 'Fetcher',
      timestamp: DateTime.now().subtract(Duration(hours: 3)),
    ),
    Activity(
      time: '09:15 AM',
      studentName: 'Emily Brown',
      gradeClass: 'Grade 1',
      status: 'Checked Out',
      verifiedBy: 'Parent',
      timestamp: DateTime.now().subtract(Duration(hours: 4)),
    ),
    Activity(
      time: '08:45 AM',
      studentName: 'David Wilson',
      gradeClass: 'Grade 3',
      status: 'Checked In',
      verifiedBy: 'Guardian',
      timestamp: DateTime.now().subtract(Duration(hours: 5)),
    ),
    Activity(
      time: '08:30 AM',
      studentName: 'Lisa Garcia',
      gradeClass: 'Grade 2',
      status: 'Checked In',
      verifiedBy: 'Parent',
      timestamp: DateTime.now().subtract(Duration(hours: 6)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket channel
    channel = HtmlWebSocketChannel.connect('wss://rfid-websocket-server.onrender.com');

    // Listen for incoming RFID data
    channel.stream.listen((message) {
      print("RFID received: $message");
      
      try {
        String? uid;
        
        // Try to parse as JSON first
        try {
          final Map<String, dynamic> parsedMessage = json.decode(message);
          if (parsedMessage['type'] == 'rfid_scan' && parsedMessage['uid'] != null) {
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
      print('Fetching student with RFID UID: $rfidUid');
      
      final response = await supabase
          .from('students')
          .select()
          .eq('rfid_uid', rfidUid)
          .neq('status', 'deleted') // Include active and null status students
          .maybeSingle();

      if (response != null) {
        final student = Student.fromJson(response);
        
        setState(() {
          scannedStudent = student;
          isLoadingStudent = false;
          selectedIndex = 1; // Switch to verification tab
        });
        
        print('Student found: ${student.fullName}');
        
        // Fetch authorized fetchers for this student
        await _fetchAuthorizedFetchers(student.id);
      } else {
        setState(() {
          isLoadingStudent = false;
        });
        _showErrorNotification('Student not found or inactive');
        print('No student found with RFID UID: $rfidUid');
      }
    } catch (e) {
      setState(() {
        isLoadingStudent = false;
      });
      _showErrorNotification('Error fetching student data: ${e.toString()}');
      print('Error fetching student: $e');
    }
  }

  // New function to fetch authorized fetchers from database
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
          if (parentData != null && (parentData['status'] == null || parentData['status'] == 'active')) {
            final fetcher = Fetcher.fromParentData(parentData, relationshipData);
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
      _showErrorNotification('Error fetching authorized fetchers: ${e.toString()}');
      print('Error fetching authorized fetchers: $e');
    }
  }

  // Show error notification
  void _showErrorNotification(String message) {
    setState(() {
      showNotification = true;
      notificationMessage = message;
      notificationColor = Colors.red;
    });

    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });
  }

  // Define navigation items (removed Scan RFID tab)
  List<_NavItem> get navItems => [
    _NavItem("Dashboard", Icons.dashboard_outlined),
    _NavItem("Student Verification", Icons.verified_outlined),
    _NavItem("Recent Activity", Icons.history),
    _NavItem("Logout", Icons.logout),
  ];

  void simulateRFIDScan() {
    // Use one of your test RFID UIDs
    _fetchStudentByRFID('d9e0c801'); // Using the RFID UID from your sample data
  }

  void clearScan() {
    setState(() {
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
      isLoadingStudent = false;
      isLoadingFetchers = false;
    });
  }

  void handleApproval(bool approved) {
    final now = DateTime.now();
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      fetchStatus = approved ? 'approved' : 'denied';

      // Show notification
      showNotification = true;
      notificationMessage = approved
          ? 'Pickup approved at $formattedTime'
          : 'Pickup denied at $formattedTime';
      notificationColor = approved ? Colors.green : Colors.red;
      actionTimestamp = now;
    });

    // TODO: Save the approval/denial to database
    _savePickupRecord(approved);

    // Hide notification after a few seconds
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });

    // Clear scan after some time
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        clearScan();
      }
    });
  }

  // Placeholder for saving pickup records (implement when you create pickup_records table)
  Future<void> _savePickupRecord(bool approved) async {
    if (scannedStudent == null) return;

    try {
      // TODO: When you create a pickup_records table, save the record here
      print('Saving pickup record: ${approved ? 'approved' : 'denied'} for student ${scannedStudent!.fullName}');
      
      // Example of what the table structure might look like:
      /*
      final record = {
        'student_id': scannedStudent!.id,
        'guard_id': user?.id,
        'action': approved ? 'approved' : 'denied',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': null,
      };
      
      await supabase.from('pickup_records').insert(record);
      */
    } catch (e) {
      print('Error saving pickup record: $e');
    }
  }

  // Function to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await supabase.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  // Dashboard content (keeping the same)
  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Header Section
          Text(
            "Guard Dashboard",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // Summary stats
                Row(
                  children: [
                    _statCard(
                      "Students Checked In",
                      "42",
                      Icons.login,
                      Colors.blue,
                    ),
                    const SizedBox(width: 16),
                    _statCard(
                      "Students Checked Out",
                      "38",
                      Icons.logout,
                      Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _statCard(
                      "Pending Pickups",
                      "4",
                      Icons.people_outline,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activities
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recent Activities",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Activity list
                _activityItem(
                  "RFID Tag",
                  "Checked out by guardian",
                  "10:15 AM",
                  Icons.logout,
                  Colors.green,
                ),
                _divider(),
                _activityItem(
                  "RFID Card",
                  "Checked in by parent",
                  "8:30 AM",
                  Icons.login,
                  Colors.blue,
                ),
                _divider(),
                _activityItem(
                  "Test Student",
                  "Pickup denied - unauthorized fetcher",
                  "3:45 PM",
                  Icons.block,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for stat cards in dashboard
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // Helper widget for activity items
  Widget _activityItem(
    String name,
    String action,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  action,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Divider for list items
  Widget _divider() {
    return Divider(color: Colors.grey[200], height: 1);
  }

  // Updated Student verification content
  Widget _buildVerificationContent() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Student info
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student Verification',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        // Simulate button for testing
                        if (scannedStudent == null && !isLoadingStudent)
                          TextButton.icon(
                            onPressed: simulateRFIDScan,
                            icon: Icon(Icons.developer_mode, size: 16),
                            label: Text(
                              'Test with Sample',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              backgroundColor: Colors.grey[100],
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan RFID card to verify student',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 24),

                    // RFID Card box or Student info or Loading
                    if (isLoadingStudent)
                      _buildLoadingBox()
                    else if (scannedStudent == null)
                      _buildRfidScanBox()
                    else
                      _buildStudentInfoBox(),
                  ],
                ),
              ),

              SizedBox(width: 24),

              // Right side - Fetchers list
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Authorized Fetchers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (fetchers != null && !isLoadingFetchers)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${fetchers!.length} authorized',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    if (isLoadingFetchers)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.blue),
                              SizedBox(height: 16),
                              Text(
                                'Loading authorized fetchers...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (fetchers != null && fetchers!.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          itemCount: fetchers!.length,
                          itemBuilder: (context, index) {
                            final fetcher = fetchers![index];
                            return _buildFetcherCard(fetcher);
                          },
                        ),
                      )
                    else if (fetchers != null && fetchers!.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.orange[300],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No authorized fetchers found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'This student has no registered parents or guardians.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Text(
                            'No student scanned',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 16),

                    if (scannedStudent != null && !isLoadingStudent && !isLoadingFetchers)
                      Column(
                        children: [
                          _buildActionButton(
                            onPressed: (fetchers != null && fetchers!.isNotEmpty) 
                                ? () => handleApproval(true)
                                : null,
                            icon: Icons.check_circle_outline,
                            label: "Approve Pick-up",
                            color: Colors.green,
                          ),
                          SizedBox(height: 12),
                          _buildActionButton(
                            onPressed: () => handleApproval(false),
                            icon: Icons.cancel_outlined,
                            label: "Deny Pick-up",
                            color: Colors.red,
                          ),
                        ],
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

  // New Recent Activity content
  Widget _buildRecentActivityContent() {
    // Filter activities based on search query
    List<Activity> filteredActivities = sampleActivities.where((activity) {
      return activity.studentName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 24),

          // Search and Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search activities...',
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Container(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Filter functionality
                  },
                  icon: Icon(Icons.filter_list, size: 16),
                  label: Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey[700],
                    elevation: 1,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Time Period Tabs
          Row(
            children: [
              _buildTimePeriodTab('Today', selectedTimePeriod == 'Today'),
              _buildTimePeriodTab('This Week', selectedTimePeriod == 'This Week'),
              _buildTimePeriodTab('This Month', selectedTimePeriod == 'This Month'),
            ],
          ),

          SizedBox(height: 24),

          // Activities Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _tableHeader('Time')),
                        Expanded(flex: 3, child: _tableHeader('Student Name')),
                        Expanded(flex: 2, child: _tableHeader('Grade/Class')),
                        Expanded(flex: 2, child: _tableHeader('Status')),
                        Expanded(flex: 2, child: _tableHeader('Verified By')),
                        Expanded(flex: 1, child: _tableHeader('Actions')),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = filteredActivities[index];
                        return _buildActivityRow(activity, index);
                      },
                    ),
                  ),

                  // Table Footer
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${filteredActivities.length} of ${sampleActivities.length} entries',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: null,
                              icon: Icon(Icons.chevron_left, color: Colors.grey[400]),
                              iconSize: 20,
                            ),
                            IconButton(
                              onPressed: null,
                              icon: Icon(Icons.chevron_right, color: Colors.grey[400]),
                              iconSize: 20,
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

          SizedBox(height: 24),

          // RFID Scanner Status
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCANNERS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by ID or Name...',
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'RFID Scanner Status',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodTab(String title, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedTimePeriod = title;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey[300]!,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildActivityRow(Activity activity, int index) {
    Color statusColor;
    Color statusBgColor;
    
    switch (activity.status) {
      case 'Checked In':
        statusColor = Colors.green[700]!;
        statusBgColor = Colors.green[50]!;
        break;
      case 'Checked Out':
        statusColor = Colors.blue[700]!;
        statusBgColor = Colors.blue[50]!;
        break;
      case 'Denied':
        statusColor = Colors.red[700]!;
        statusBgColor = Colors.red[50]!;
        break;
      default:
        statusColor = Colors.grey[700]!;
        statusBgColor = Colors.grey[50]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey[25],
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  activity.time,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              activity.studentName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              activity.gradeClass,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activity.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              activity.verifiedBy,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              onPressed: () {
                // Actions menu
              },
              icon: Icon(Icons.more_horiz, color: Colors.grey[600]),
              iconSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Loading widget
  Widget _buildLoadingBox() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[100]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Loading Student Data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 320,
          alignment: Alignment.center,
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      ],
    );
  }

  // Floating notification widget
  Widget _buildFloatingNotification() {
    final formattedDate = actionTimestamp != null
        ? "${actionTimestamp!.year}-${actionTimestamp!.month.toString().padLeft(2, '0')}-${actionTimestamp!.day.toString().padLeft(2, '0')}"
        : '2025-07-15';

    final formattedTime = actionTimestamp != null
        ? "${actionTimestamp!.hour.toString().padLeft(2, '0')}:${actionTimestamp!.minute.toString().padLeft(2, '0')}:${actionTimestamp!.second.toString().padLeft(2, '0')}"
        : '12:33:55';

    return Positioned(
      top: 24,
      right: 24,
      child: AnimatedOpacity(
        opacity: showNotification ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notificationColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fetchStatus == 'approved' ? Icons.check_circle : 
                (fetchStatus == 'denied' ? Icons.cancel : Icons.error),
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fetchStatus == 'approved'
                        ? 'Pickup Approved'
                        : fetchStatus == 'denied' 
                          ? 'Pickup Denied'
                          : 'Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '$formattedDate $formattedTime',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    fetchStatus != null ? 'Record saved to database' : '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              InkWell(
                onTap: () {
                  setState(() {
                    showNotification = false;
                  });
                },
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRfidScanBox() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[100]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contact_page, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Tap RFID Card',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        // Empty student placeholder
        Container(
          height: 320,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 150,
                  height: 150,
                  color: Colors.grey[200],
                  child: Icon(Icons.person, size: 80, color: Colors.grey[400]),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: 120,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student ID',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),

            SizedBox(height: 16),
            Text(
              'Emergency Contact',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentInfoBox() {
    // Get emergency contact from first primary parent, or first parent if no primary
    String emergencyContact = '—';
    if (fetchers != null && fetchers!.isNotEmpty) {
      final primaryParent = fetchers!.firstWhere(
        (f) => f.isPrimary,
        orElse: () => fetchers!.first,
      );
      emergencyContact = primaryParent.contact;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  scannedStudent!.imageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 150,
                      height: 150,
                      color: Colors.grey[300],
                      child: Icon(Icons.person, size: 80, color: Colors.grey[600]),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              Text(
                scannedStudent!.fullName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                scannedStudent!.classSection,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Student ID
        Text(
          'Student ID',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Text(
            scannedStudent!.studentId,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        SizedBox(height: 16),

        // Emergency Contact
        Text(
          'Emergency Contact',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Text(
            emergencyContact,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        // Reset button
        SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: clearScan,
            icon: Icon(Icons.refresh, size: 14),
            label: Text('Reset', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              backgroundColor: Colors.grey[100],
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFetcherCard(Fetcher fetcher) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                fetcher.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey[300],
                    child: Icon(Icons.person, size: 32, color: Colors.grey[600]),
                  );
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fetcher.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (fetcher.isPrimary)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRIMARY',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Relationship: ${fetcher.relationship}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Contact: ${fetcher.contact}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Email: ${fetcher.email}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'AUTHORIZED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey[300],
          foregroundColor: onPressed != null ? Colors.white : Colors.grey[600],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 180,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Text(
                    "KidSync",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Navigation items
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final item = navItems[index];

                      // Add extra spacing before logout
                      if (item.label == "Logout" && index > 0) {
                        return Column(
                          children: [
                            SizedBox(height: 16),
                            _buildNavItem(item, index),
                          ],
                        );
                      }

                      return _buildNavItem(item, index);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(child: _getContentForIndex(selectedIndex)),
        ],
      ),
    );
  }

  // Helper method to get content based on selected index
  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildVerificationContent();
      case 2:
        return _buildRecentActivityContent();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavItem(_NavItem item, int index) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () {
        if (item.label == "Logout") {
          _handleLogout(context);
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    channel.sink.close();
    super.dispose();
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  _NavItem(this.label, this.icon);
}