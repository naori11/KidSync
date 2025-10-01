import 'package:flutter/material.dart';
import 'student_management.dart';
import 'user_management.dart';
import 'parent_guardian.dart';
import 'audit_logs.dart';
import 'section_management.dart';
import 'driver_assignment.dart';
import 'bulk_import.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class AdminPanelContent extends StatefulWidget {
  final String userName;

  const AdminPanelContent({super.key, required this.userName});

  @override
  State<AdminPanelContent> createState() => _AdminPanelContentState();
}

class _AdminPanelContentState extends State<AdminPanelContent> {
  final supabase = Supabase.instance.client;
  String? adminId;
  String? adminName;
  String? profileImageUrl;
  bool isLoading = false;

  int selectedIndex = 0;
  late final List<_NavItem> navItems;
  
  // Dynamic dashboard data
  int totalStudents = 0;
  int totalParents = 0;
  int totalDrivers = 0;
  int totalGuards = 0;
  int totalTeachers = 0;
  List<Map<String, dynamic>> recentAuditLogs = [];
  List<Map<String, dynamic>> todaysClasses = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadDashboardData();
    
    // Set up periodic refresh for audit logs every 30 seconds
    Future.delayed(Duration.zero, () {
      _setupPeriodicRefresh();
    });
    
    navItems = [
      _NavItem("Dashboard", Icons.dashboard_outlined, const SizedBox()),
      _NavItem(
        "Section Management",
        Icons.list_alt_outlined,
        const SectionManagementPage(),
      ),
      _NavItem(
        "Student Management",
        Icons.people_outline,
        StudentManagementPage(),
      ),
      _NavItem("User Management", Icons.person_outline, UserManagementPage()),
      _NavItem("Parent/Guardian", Icons.family_restroom, ParentGuardianPage()),
      _NavItem("Driver Assignment", Icons.drive_eta, DriverAssignmentPage()),
      _NavItem("Audit Logs", Icons.description_outlined, AuditLogsPage()),
      _NavItem("Bulk Import", Icons.upload_file, BulkImportPage()),
    ];
  }

  Future<void> _loadAdminData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    adminId = user?.id;
    // Fetch admin's first and last name from the users table
    final adminData =
        await supabase
            .from('users')
            .select('fname, lname, profile_image_url')
            .eq('id', adminId!)
            .maybeSingle();

    adminName =
        adminData != null
            ? '${adminData['fname'] ?? ''} ${adminData['lname'] ?? ''}'.trim()
            : user?.email ?? 'Admin';

    profileImageUrl = adminData?['profile_image_url'];

    if (adminId == null) {
      setState(() => isLoading = false);
      return;
    }
    setState(() => isLoading = false);
  }

  void _setupPeriodicRefresh() {
    // Refresh audit logs and classes every 30 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted && selectedIndex == 0) {
        await _loadRecentAuditLogs();
        await _loadUpcomingClasses();
      }
      return mounted;
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      await Future.wait([
        _loadUserCounts(),
        _loadRecentAuditLogs(),
        _loadUpcomingClasses(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  Future<void> _loadUserCounts() async {
    try {
      // Load total students from students table first, fallback to users table
      var studentsResponse;
      try {
        studentsResponse = await supabase
            .from('students')
            .select('id');
      } catch (e) {
        // Fallback to users table if students table doesn't exist
        studentsResponse = await supabase
            .from('users')
            .select('id')
            .eq('role', 'Student');
      }
      
      // Load total parents from users table
      final parentsResponse = await supabase
          .from('users')
          .select('id')
          .eq('role', 'Parent');
      
      // Load total drivers from users table
      final driversResponse = await supabase
          .from('users')
          .select('id')
          .eq('role', 'Driver');

      // Load total guards from users table
      final guardsResponse = await supabase
          .from('users')
          .select('id')
          .eq('role', 'Guard');

      // Load total teachers from users table
      final teachersResponse = await supabase
          .from('users')
          .select('id')
          .eq('role', 'Teacher');

      setState(() {
        totalStudents = studentsResponse.length;
        totalParents = parentsResponse.length;
        totalDrivers = driversResponse.length;
        totalGuards = guardsResponse.length;
        totalTeachers = teachersResponse.length;
      });
    } catch (e) {
      print('Error loading user counts: $e');
    }
  }


  Future<void> _loadRecentAuditLogs() async {
    try {
      final response = await supabase
          .from('audit_logs')
          .select('action_type, action_description, created_at, user_id, user_name, module, target_type')
          .order('created_at', ascending: false)
          .limit(5);

      print('✅ Audit logs loaded: ${response.length} entries'); // Debug log
      
      if (response.isNotEmpty) {
        setState(() {
          recentAuditLogs = List<Map<String, dynamic>>.from(response);
        });
        print('✅ Recent audit logs updated in state');
      } else {
        print('⚠️ No audit logs found in database, using fallback data');
        _setFallbackAuditLogs();
      }
    } catch (e) {
      print('❌ Error loading audit logs: $e');
      _setFallbackAuditLogs();
    }
  }

  void _setFallbackAuditLogs() {
    setState(() {
      recentAuditLogs = [
        {
          'action_type': 'Update',
          'action_description': 'User profile updated',
          'module': 'User Management',
          'target_type': 'users',
          'user_name': 'Admin User',
          'created_at': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
        {
          'action_type': 'Create',
          'action_description': 'New student added',
          'module': 'Student Management',
          'target_type': 'students',
          'user_name': 'Admin User',
          'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        },
        {
          'action_type': 'Update',
          'action_description': 'Attendance marked',
          'module': 'Attendance',
          'target_type': 'section_attendance',
          'user_name': 'Teacher',
          'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        },
        {
          'action_type': 'Assign',
          'action_description': 'Driver assigned to student',
          'module': 'Driver Assignment',
          'target_type': 'driver_assignments',
          'user_name': 'Admin User',
          'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'action_type': 'Update',
          'action_description': 'Section information updated',
          'module': 'Section Management',
          'target_type': 'sections',
          'user_name': 'Admin User',
          'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        },
      ];
    });
  }

  Future<void> _loadUpcomingClasses() async {
    try {
      // Get current day of week (1 = Monday, 7 = Sunday)
      final now = DateTime.now();
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayAbbrev = weekDays[now.weekday - 1];
      
      print('🔍 Loading upcoming classes for: $todayAbbrev');
      print('🕐 Current time: ${now.hour}:${now.minute}');

      // Query section_teachers for today's classes
      final response = await supabase
          .from('section_teachers')
          .select('''
            subject,
            start_time,
            end_time,
            days,
            sections!inner(name, grade_level),
            users!inner(fname, lname)
          ''')
          .contains('days', [todayAbbrev])
          .order('start_time', ascending: true);

      print('📚 Total classes found for $todayAbbrev: ${(response as List).length}');

      // Filter for upcoming classes only (classes that haven't started yet)
      final upcomingClasses = (response as List).where((classData) {
        final startTimeStr = classData['start_time'] as String?;
        if (startTimeStr == null || startTimeStr.isEmpty) return false;

        final startTimeParts = startTimeStr.split(':');
        if (startTimeParts.length < 2) return false;

        final startTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(startTimeParts[0]),
          int.parse(startTimeParts[1]),
        );

        final isUpcoming = now.isBefore(startTime);
        print('⏰ Class: ${classData['subject']} at $startTimeStr - Upcoming: $isUpcoming');
        
        return isUpcoming;
      }).take(5).toList();

      print('✅ Upcoming classes filtered: ${upcomingClasses.length}');

      setState(() {
        todaysClasses = List<Map<String, dynamic>>.from(upcomingClasses);
      });
    } catch (e) {
      print('❌ Error loading upcoming classes: $e');
      // Fallback to sample data
      setState(() {
        todaysClasses = [
          {
            'subject': 'Mathematics',
            'start_time': '14:00:00',
            'end_time': '15:00:00',
            'sections': {'name': 'Grade 1-A', 'grade_level': 'Grade 1'},
            'users': {'fname': 'John', 'lname': 'Smith'},
          },
          {
            'subject': 'English',
            'start_time': '15:00:00',
            'end_time': '16:00:00',
            'sections': {'name': 'Grade 2-B', 'grade_level': 'Grade 2'},
            'users': {'fname': 'Sarah', 'lname': 'Johnson'},
          },
          {
            'subject': 'Science',
            'start_time': '16:00:00',
            'end_time': '17:00:00',
            'sections': {'name': 'Grade 3-A', 'grade_level': 'Grade 3'},
            'users': {'fname': 'Michael', 'lname': 'Brown'},
          },
        ];
      });
    }
  }


  // Function to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      // Navigate to login screen or home screen after logout
      if (context.mounted) {
        // Replace this with your login route navigation
        Navigator.of(context).pushReplacementNamed('/login');

        // Alternatively, you can use Navigator.pushAndRemoveUntil to clear the navigation stack
        // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  String getTodayLabel() {
    final now = DateTime.now();
    final date =
        "${["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][now.weekday - 1]}, "
        "${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.month - 1]} ${now.day}";
    return date;
  }

  Widget _buildDashboardHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : (isTablet ? 20 : 24), 
            isMobile ? 12 : 16, 
            isMobile ? 16 : (isTablet ? 20 : 24), 
            isMobile ? 12 : 16
          ),
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                radius: isMobile ? 18 : 22,
                backgroundImage:
                    profileImageUrl != null && profileImageUrl!.isNotEmpty
                        ? NetworkImage(profileImageUrl!)
                        : null,
                child:
                    profileImageUrl == null || profileImageUrl!.isEmpty
                        ? Text(
                          (adminName != null && adminName!.isNotEmpty)
                              ? adminName![0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 16 : 20,
                            color: const Color(0xFF2563EB),
                          ),
                        )
                        : null,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Good day, ${adminName ?? 'Admin'}!",
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222B45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: isMobile ? 12 : 14,
                          color: const Color(0xFF8F9BB3),
                        ),
                        SizedBox(width: isMobile ? 3 : 4),
                        Text(
                          getTodayLabel(),
                          style: TextStyle(
                            color: const Color(0xFF8F9BB3),
                            fontWeight: FontWeight.w400,
                            fontSize: isMobile ? 11 : 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        final isDesktop = constraints.maxWidth >= 1200;
        
        return Column(
          children: [
            // Profile greeting with top spacing
            Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 8 : (isTablet ? 12 : 16),
                isMobile ? 8 : 12,
                isMobile ? 8 : (isTablet ? 12 : 16),
                0,
              ),
              child: _buildDashboardHeader(),
            ),
            
            // Scrollable content below
            Expanded(
              child: Container(
                color: const Color.fromARGB(10, 78, 241, 157),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 8 : (isTablet ? 12 : 16)),
                  child: Column(
                    children: [
                      // Overview Section (inspired by image layout)
                      _buildOverviewSection(isMobile, isTablet),
                      
                      SizedBox(height: isMobile ? 16 : 24),
                      
                      // Main dashboard content grid
                      _buildDashboardGrid(isMobile, isTablet, isDesktop),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildOverviewSection(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OVERVIEW",
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Text(
                    "Click on a number to see the list",
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _loadDashboardData,
                    child: Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOverviewTable(isMobile, isTablet),
        ],
      ),
    );
  }
  
  Widget _buildOverviewTable(bool isMobile, bool isTablet) {
    // Format date as DD/MM/YYYY like in the image
    final now = DateTime.now();
    final formattedDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 12 : 16,
              horizontal: isMobile ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    "DATE",
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL STUDENTS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL PARENTS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL DRIVERS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL GUARDS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TOTAL TEACHERS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data row
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 12 : 16,
              horizontal: isMobile ? 8 : 12,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Navigate to student list
                      setState(() => selectedIndex = 2); // Student Management
                    },
                    child: Text(
                      totalStudents.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Navigate to parent list
                      setState(() => selectedIndex = 4); // Parent/Guardian
                    },
                    child: Text(
                      totalParents.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Navigate to driver list
                      setState(() => selectedIndex = 5); // Driver Assignment
                    },
                    child: Text(
                      totalDrivers.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Navigate to user management for guards
                      setState(() => selectedIndex = 3); // User Management
                    },
                    child: Text(
                      totalGuards.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B5CF6),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Navigate to user management for teachers
                      setState(() => selectedIndex = 3); // User Management
                    },
                    child: Text(
                      totalTeachers.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEC4899),
                        decoration: TextDecoration.underline,
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
  
  Widget _buildDashboardGrid(bool isMobile, bool isTablet, bool isDesktop) {
    return Column(
      children: [
        // Two column layout for Recent Activity and Recent Taps
        if (isMobile)
          Column(
            children: [
              _buildRecentActivitySection(isMobile, isTablet),
              const SizedBox(height: 16),
              _buildRecentTapsSection(isMobile, isTablet),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRecentActivitySection(isMobile, isTablet)),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentTapsSection(isMobile, isTablet)),
            ],
          ),
      ],
    );
  }
  
  
  
  Widget _buildRecentActivitySection(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RECENT ACTIVITY",
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "FROM AUDIT LOGS",
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            getTodayLabel().toUpperCase(),
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          if (recentAuditLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No recent activities',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...recentAuditLogs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value;
              final colors = [
                const Color(0xFF10B981),
                const Color(0xFF2563EB),
                const Color(0xFFF59E0B),
                const Color(0xFF8B5CF6),
                const Color(0xFFEC4899),
              ];
              
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  _buildActivityItem(
                    log['action_description'] ?? 'Activity',
                    log['action_type'] ?? 'Update',
                    '', // Remove time ago display
                    colors[index % colors.length],
                  ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildRecentTapsSection(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "UPCOMING CLASSES",
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            getTodayLabel().toUpperCase(),
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 20),
          if (todaysClasses.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No upcoming classes',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...todaysClasses.asMap().entries.map((entry) {
              final index = entry.key;
              final classData = entry.value;
              final section = classData['sections'] as Map<String, dynamic>?;
              final teacher = classData['users'] as Map<String, dynamic>?;
              
              // Format time to 12-hour AM/PM
              String formatTime(String? timeStr) {
                if (timeStr == null) return '';
                final parts = timeStr.split(':');
                if (parts.length < 2) return timeStr;
                final hour = int.parse(parts[0]);
                final minute = parts[1];
                final period = hour >= 12 ? 'PM' : 'AM';
                final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                return '$displayHour:$minute $period';
              }
              
              return Column(
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  _buildClassItem(
                    classData['subject'] ?? 'Unknown Subject',
                    section?['name'] ?? 'Unknown Section',
                    '${teacher?['fname'] ?? ''} ${teacher?['lname'] ?? ''}'.trim(),
                    '${formatTime(classData['start_time'])} - ${formatTime(classData['end_time'])}',
                  ),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }


  Widget _buildResponsiveMainContent(bool isMobile, bool isTablet, bool isDesktop) {
    final systemOverview = Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Overview",
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
          _overviewItem("Active Students", 96, Colors.blue),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Present Today", 86, Colors.green),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Absent Today", 14, Colors.orange),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Late Students", 24, Colors.red),
        ],
      ),
    );
    
    final recentActivity = Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
          // Old activity items removed - now using dynamic data from audit logs
        ],
      ),
    );
    
    if (isMobile || isTablet) {
      // Stack vertically on mobile and tablet
      return Column(
        children: [
          systemOverview,
          SizedBox(height: isMobile ? 16 : 24),
          recentActivity,
        ],
      );
    } else {
      // Side by side on desktop
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: systemOverview),
          const SizedBox(width: 24),
          Expanded(child: recentActivity),
        ],
      );
    }
  }

  // Helper widget for overview items with progress bar
  Widget _overviewItem(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: Colors.black87)),
            Text(
              "$percentage%",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // Quick stat card for dashboard summary
  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Attendance stat item
  Widget _buildAttendanceStat(
    String label,
    String value,
    String change,
    Color changeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: changeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                change,
                style: TextStyle(
                  fontSize: 11,
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Grade distribution widget
  Widget _buildGradeDistribution() {
    final grades = [
      {"name": "Preschool", "count": 42, "color": Colors.blue},
      {"name": "Kindergarten", "count": 56, "color": Colors.green},
      {"name": "Grade 1", "count": 48, "color": Colors.orange},
      {"name": "Grade 2", "count": 52, "color": Colors.purple},
      {"name": "Grade 3", "count": 45, "color": Colors.red},
    ];

    return Column(
      children:
          grades.map((grade) {
            final index = grades.indexOf(grade);
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: grade["color"] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        grade["name"] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      "${grade["count"]}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (index < grades.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),
              ],
            );
          }).toList(),
    );
  }

  // Simplified activity item for recent activity - Summary format
  Widget _buildActivityItem(String title, String type, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                title[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Tap item widget
  Widget _buildTapItem(String name, String status, String time, String? imageUrl) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[200],
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // Class item widget for Today's Classes
  Widget _buildClassItem(String subject, String section, String teacher, String time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.class_outlined,
              size: 20,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  section,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (teacher.isNotEmpty)
                  Text(
                    teacher,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  // Admin activity item widget (more square design)
  Widget _buildAdminActivityItem(String title, String type, String date, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                title[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return "${text[0].toUpperCase()}${text.substring(1).toLowerCase()}";
  }

  String _getActivityTitle(String action, String tableName) {
    switch (tableName.toLowerCase()) {
      case 'users':
        return action == 'INSERT' ? 'User Registration' : 'User Update';
      case 'attendance':
        return action == 'INSERT' ? 'Attendance Marked' : 'Attendance Updated';
      case 'driver_assignments':
        return action == 'INSERT' ? 'Driver Assignment' : 'Route Updated';
      case 'sections':
        return action == 'INSERT' ? 'Section Created' : 'Section Updated';
      default:
        return '${_capitalize(action.toLowerCase())} ${_capitalize(tableName.replaceAll('_', ' '))}';
    }
  }

  String _getActivityType(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
        return 'New Record';
      case 'UPDATE':
        return 'Modified';
      case 'DELETE':
        return 'Removed';
      default:
        return _capitalize(action);
    }
  }

  String _getActivityDetail(String tableName) {
    switch (tableName.toLowerCase()) {
      case 'users':
        return 'User Management';
      case 'attendance':
        return 'Daily Tracking';
      case 'driver_assignments':
        return 'Route Management';
      case 'sections':
        return 'Class Management';
      default:
        return _capitalize(tableName.replaceAll('_', ' '));
    }
  }

  String _getTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        // Convert to 12-hour format with AM/PM
        int hour = dateTime.hour;
        String period = hour >= 12 ? 'PM' : 'AM';
        hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        String minute = dateTime.minute.toString().padLeft(2, '0');
        return '$hour:$minute $period';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else {
        // For older dates, show the date
        return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 768;
          final isMobile = constraints.maxWidth < 768;
          final isLargeScreen = constraints.maxWidth >= 1200;
          
          return Row(
            children: [
              // Sidebar Navigation
              LayoutBuilder(
                builder: (context, sidebarConstraints) {
                  double sidebarWidth;
                  if (isMobile) {
                    sidebarWidth = constraints.maxWidth * 0.25; // 25% on mobile
                    sidebarWidth = sidebarWidth.clamp(60.0, 120.0);
                  } else if (isTablet) {
                    sidebarWidth = constraints.maxWidth * 0.2; // 20% on tablet
                    sidebarWidth = sidebarWidth.clamp(150.0, 200.0);
                  } else {
                    sidebarWidth = constraints.maxWidth * 0.15; // 15% on desktop
                    sidebarWidth = sidebarWidth.clamp(180.0, 250.0);
                  }
                  
                  return Container(
                    width: sidebarWidth,
                    color: const Color.fromARGB(255, 255, 255, 255),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App title
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 8 : 16,
                              isMobile ? 16 : 24,
                              isMobile ? 8 : 16,
                              isMobile ? 20 : 32,
                            ),
                            child: Text(
                              isMobile ? "KS" : "KidSync",
                              style: TextStyle(
                                fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
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
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                final item = navItems[index];
                                // Add extra spacing before logout
                                if (item.label == "Logout" && index > 0) {
                                  return Column(
                                    children: [
                                      SizedBox(height: isMobile ? 8 : 16),
                                      _buildNavItem(item, index, isMobile),
                                    ],
                                  );
                                }
                                return _buildNavItem(item, index, isMobile);
                              },
                            ),
                          ),
                          // Logout button at the bottom
                          Padding(
                            padding: EdgeInsets.only(bottom: isMobile ? 12.0 : 24.0),
                            child: _buildNavItem(
                              _NavItem("Logout", Icons.logout, null),
                              navItems.length,
                              isMobile,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Main Content
              Expanded(
                child:
                    selectedIndex == 0
                        ? _buildDashboard()
                        : navItems[selectedIndex].page ?? const SizedBox(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isMobile) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () async {
        // If it's the logout button
        if (item.label == "Logout") {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    'Confirm Logout',
                    style: TextStyle(color: Colors.black),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(color: Colors.black),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      style: ButtonStyle(
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return Color(0xFF19AE61);
                              }
                              return Colors.black;
                            }),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Logout'),
                    ),
                  ],
                ),
          );
          if (shouldLogout == true) {
            _handleLogout(context);
          }
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        margin: EdgeInsets.fromLTRB(
          isMobile ? 4 : 8,
          isMobile ? 2 : 4,
          isMobile ? 4 : 8,
          isMobile ? 2 : 4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: isMobile ? 8 : 12,
        ),
        child: isMobile
            ? Icon(
                item.icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget? page; // Changed to nullable

  _NavItem(this.label, this.icon, this.page);
}

// Custom painter for the line chart
class LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Chart area
    final double chartWidth = size.width;
    final double chartHeight = size.height * 0.8;
    final double bottomPadding = size.height * 0.2;

    // Define months for x-axis
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Define point coordinates for the line graph (sample wave pattern)
    final List<double> points = [7, 14, 21, 14, 21, 14, 28, 21, 14, 7, 14, 7];

    // Draw horizontal lines (grid)
    Paint gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight / 4 * i);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Draw x-axis labels (months)
    TextStyle labelStyle = TextStyle(color: Colors.grey[600], fontSize: 10);

    for (int i = 0; i < months.length; i++) {
      final textSpan = TextSpan(text: months[i], style: labelStyle);

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final x =
          (chartWidth / (months.length - 1) * i) - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(x, chartHeight + 10));
    }

    // Draw the line graph
    Paint linePaint =
        Paint()
          ..color = const Color(0xFF2ECC71)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    Path path = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (chartWidth / (points.length - 1) * i);
      final y =
          chartHeight -
          (chartHeight / 28 * points[i]); // Assuming max value is 28

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
