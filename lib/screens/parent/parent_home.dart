import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/parent_models.dart';
import '../../services/notification_service.dart';
import 'parent_dashboard_tab.dart';
import 'pickup_dropoff_tab.dart';
import 'fetchers_tab.dart';
import 'confirmation_logs.dart';
import 'notifications.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  _NavItem(this.label, this.icon, this.route);
}

// Add Student model for the selector
class Student {
  final int id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String gradeLevel;
  final String section; // This will hold the section name or id
  final String? profileImageUrl;

  Student({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gradeLevel,
  required this.section,
  this.profileImageUrl,
  });

  String get fullName {
    String name = firstName;
    if (middleName.isNotEmpty) name += ' $middleName';
    if (lastName.isNotEmpty) name += ' $lastName';
    return name.trim();
  }

  String get initials {
    String initials = firstName.isNotEmpty ? firstName[0] : '';
    if (lastName.isNotEmpty) initials += lastName[0];
    return initials.toUpperCase();
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'] ?? json['id'],
      firstName: json['students']?['fname'] ?? json['fname'] ?? '',
      middleName: json['students']?['mname'] ?? json['mname'] ?? '',
      lastName: json['students']?['lname'] ?? json['lname'] ?? '',
      gradeLevel: json['students']?['grade_level'] ?? json['grade_level'] ?? '',
    // Prefer the joined section name if available, otherwise fall back to id
    section:
      json['students']?['sections']?['name'] ??
      json['students']?['section_id']?.toString() ??
      json['section_id']?.toString() ??
      '',
  profileImageUrl: json['students']?['profile_image_url'] ?? json['profile_image_url'],
    );
  }
}

class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Fetchers', Icons.group, 'fetchers'),
      _NavItem('Confirmation Logs', Icons.history, 'logs'),
    ];
    return _ParentHomeTabs(
      navItems: navItems,
      primaryColor: primaryGreen,
      secondaryText: black.withOpacity(0.7),
      logout: _logout,
    );
  }
}

class _ParentHomeTabs extends StatefulWidget {
  final List<_NavItem> navItems;
  final Color primaryColor;
  final Color secondaryText;
  final Future<void> Function(BuildContext) logout;

  const _ParentHomeTabs({
    required this.navItems,
    required this.primaryColor,
    required this.secondaryText,
    required this.logout,
    Key? key,
  }) : super(key: key);

  @override
  State<_ParentHomeTabs> createState() => _ParentHomeTabsState();
}

class _ParentHomeTabsState extends State<_ParentHomeTabs>
    with TickerProviderStateMixin {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<AuthorizedFetcher> dashboardFetchers = [];
  bool isDashboardLoading = true;
  final supabase = Supabase.instance.client;

  // Add these new properties for user data
  String userName = 'Loading...';
  String userEmail = 'Loading...';
  String? profileImageUrl;
  bool isLoadingProfile = true;

  // Add student selector properties
  List<Student> parentStudents = [];
  Student? selectedStudent;
  bool isLoadingStudents = true;

  // Add notification properties
  final NotificationService _notificationService = NotificationService();
  int unreadNotificationCount = 0;
  bool isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Load all data
    _loadUserProfile();
    _loadStudents();
  }

  // Add method to load all students for this parent
  Future<void> _loadStudents() async {
    try {
      setState(() => isLoadingStudents = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoadingStudents = false);
        return;
      }

      final parentResponse =
          await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

      if (parentResponse == null) {
        setState(() => isLoadingStudents = false);
        return;
      }

      final parentId = parentResponse['id'];

      // Get all students for this parent - FIXED QUERY
      final studentResponse = await supabase
          .from('parent_student')
          .select('''
          student_id,
          students!inner(
            id, fname, mname, lname, grade_level, section_id,
            profile_image_url,
            sections!inner(name)
          )
        ''')
          .eq('parent_id', parentId);

      if (studentResponse.isNotEmpty) {
        final students =
            studentResponse.map((data) => Student.fromJson(data)).toList();

        setState(() {
          parentStudents = students;
          selectedStudent = students.isNotEmpty ? students.first : null;
          isLoadingStudents = false;
        });

        // Load dashboard data for the selected student
        if (selectedStudent != null) {
          _loadDashboardFetchers();
          _loadNotificationCount();
        }
      } else {
        setState(() => isLoadingStudents = false);
      }
    } catch (error) {
      print('Error loading students: $error');
      setState(() => isLoadingStudents = false);
    }
  }

  // Add method to switch students
  void _switchToStudent(Student student) {
    setState(() {
      selectedStudent = student;
    });
    // Reload dashboard data for the new student
    _loadDashboardFetchers();
    _loadNotificationCount();
  }

  // Add method to load notification count
  Future<void> _loadNotificationCount() async {
    if (selectedStudent == null) return;

    try {
      setState(() => isLoadingNotifications = true);

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final parentResponse = await supabase
          .from('parents')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (parentResponse != null) {
        final parentId = parentResponse['id'];
        final count = await _notificationService.getUnreadNotificationCount(
          parentId,
          studentId: selectedStudent!.id,
        );
        
        setState(() {
          unreadNotificationCount = count;
        });
      }
    } catch (e) {
      print('Error loading notification count: $e');
    } finally {
      setState(() => isLoadingNotifications = false);
    }
  }

  // Add this new method to load user profile
  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoadingProfile = false);
        return;
      }

      final response =
          await supabase
              .from('users')
              .select('fname, mname, lname, email, profile_image_url')
              .eq('id', user.id)
              .maybeSingle();

      if (response != null) {
        String firstName = response['fname'] ?? '';
        String middleName = response['mname'] ?? '';
        String lastName = response['lname'] ?? '';

        // Construct full name
        String fullName = '';
        if (firstName.isNotEmpty) fullName += firstName;
        if (middleName.isNotEmpty) fullName += ' $middleName';
        if (lastName.isNotEmpty) fullName += ' $lastName';

        // Fallback to email username if no name is available
        if (fullName.trim().isEmpty) {
          final emailParts = (response['email'] ?? user.email ?? '').split('@');
          fullName = emailParts.isNotEmpty ? emailParts[0] : 'User';
        }

        setState(() {
          userName = fullName.trim();
          userEmail = response['email'] ?? user.email ?? '';
          profileImageUrl = response['profile_image_url'];
          isLoadingProfile = false;
        });
      } else {
        // Fallback to auth user data if no record in users table
        setState(() {
          userName =
              user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'User';
          userEmail = user.email ?? '';
          isLoadingProfile = false;
        });
      }
    } catch (error) {
      print('Error loading user profile: $error');
      // Fallback to auth user data on error
      final user = supabase.auth.currentUser;
      setState(() {
        userName =
            user?.userMetadata?['full_name'] ??
            user?.email?.split('@')[0] ??
            'User';
        userEmail = user?.email ?? '';
        isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadDashboardFetchers() async {
    if (selectedStudent == null) return;

    try {
      setState(() => isDashboardLoading = true);

      // Updated query to include profile images and remove role filter if needed
      final fetchersResponse = await supabase
          .from('parent_student')
          .select('''
            relationship_type,
            is_primary,
            parents!inner(
              id, fname, mname, lname, phone, email, status, user_id,
              users!inner(
                profile_image_url, role
              )
            )
          ''')
          .eq('student_id', selectedStudent!.id)
          .eq('parents.status', 'active')
          .eq(
            'parents.users.role',
            'Parent',
          ) // Only get parents with Parent role
          .limit(3);

      final List<AuthorizedFetcher> fetchers =
          fetchersResponse
              .map((data) => AuthorizedFetcher.fromJson(data))
              .toList();

      setState(() {
        dashboardFetchers = fetchers;
        isDashboardLoading = false;
      });
    } catch (error) {
      print('Error loading dashboard fetchers: $error');
      setState(() => isDashboardLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToNotifications() async {
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a student first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show notifications as modal overlay
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return ParentNotificationsModal(
          selectedStudent: selectedStudent!,
        );
      },
    );

    // Always refresh notification count when modal is closed
    _loadNotificationCount();
  }

  void _toggleNotifications() {
    setState(() {
      showNotifications = !showNotifications;
      if (showNotifications) {
        showProfile = false;
        _fadeController.forward();
        _animationController.forward();
      } else {
        _fadeController.reverse();
        _animationController.reverse();
      }
    });
  }

  void _toggleProfile() {
    setState(() {
      showProfile = !showProfile;
      if (showProfile) {
        showNotifications = false;
        _fadeController.forward();
        _animationController.forward();
      } else {
        _fadeController.reverse();
        _animationController.reverse();
      }
    });
  }

  // Add method to show student selector
  void _showStudentSelector() {
    if (parentStudents.length <= 1) return; // Don't show if only one student

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Student',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000000),
                  ),
                ),
                SizedBox(height: 16),
                ...parentStudents.map(
                  (student) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      child: (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                student.profileImageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Color.fromRGBO(25, 174, 97, 0.1),
                                  alignment: Alignment.center,
                                  child: Text(
                                    student.initials,
                                    style: TextStyle(
                                      color: widget.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: Color.fromRGBO(25, 174, 97, 0.1),
                              child: Text(
                                student.initials,
                                style: TextStyle(
                                  color: widget.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    title: Text(student.fullName),
                    subtitle: Text(
                      '${student.gradeLevel} - ${student.section}',
                    ),
                    trailing:
                        selectedStudent?.id == student.id
                            ? Icon(
                              Icons.check_circle,
                              color: widget.primaryColor,
                            )
                            : null,
                    onTap: () {
                      _switchToStudent(student);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Add method to build student selector widget
  Widget _buildStudentSelector(bool isMobile) {
    if (isLoadingStudents) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.primaryColor,
          ),
        ),
      );
    }

    if (parentStudents.isEmpty || selectedStudent == null) {
      return SizedBox.shrink(); // Hide if no students
    }

    // Don't show selector if only one student
    if (parentStudents.length == 1) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              child: (selectedStudent!.profileImageUrl != null && selectedStudent!.profileImageUrl!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(
                        selectedStudent!.profileImageUrl!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => CircleAvatar(
                          radius: 12,
                          backgroundColor: widget.primaryColor.withOpacity(0.2),
                          child: Text(
                            selectedStudent!.initials,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 12,
                      backgroundColor: widget.primaryColor.withOpacity(0.2),
                      child: Text(
                        selectedStudent!.initials,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.primaryColor,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: 8),
            Text(
              isMobile ? selectedStudent!.firstName : selectedStudent!.fullName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : 16,
                color: Color(0xFF000000),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Show clickable selector for multiple students
    return GestureDetector(
      onTap: _showStudentSelector,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: widget.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: widget.primaryColor.withOpacity(0.2),
              child: Text(
                selectedStudent!.initials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
            ),
            SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? 100 : 150),
              child: Text(
                isMobile
                    ? selectedStudent!.firstName
                    : selectedStudent!.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 14 : 16,
                  color: Color(0xFF000000),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: widget.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: const Color(0xFFFFFFFF),
          title: Row(
            children: [
              Icon(Icons.logout, color: const Color(0xFF19AE61), size: 24),
              SizedBox(width: 8),
              Text(
                'Confirm Logout',
                style: TextStyle(
                  color: const Color(0xFF000000),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: const Color(0xFF000000).withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: const Color(0xFF000000).withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.logout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF19AE61),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _fetcherRow(
    String name,
    String role,
    bool active,
    Color primaryColor, [
    bool isMobile = false,
  ]) {
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: greenWithOpacity,
            radius: isMobile ? 16 : 20,
            child: Icon(
              Icons.person,
              color: primaryColor,
              size: isMobile ? 18 : 22,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 13 : 15,
                  color: black,
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  color: black.withOpacity(0.6),
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.circle,
            color: active ? primaryColor : black.withOpacity(0.3),
            size: isMobile ? 10 : 12,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                decoration: BoxDecoration(
                  color: white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) => Icon(
                              Icons.school,
                              color: widget.primaryColor,
                              size: 28,
                            ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Panel Name
                    Text(
                      widget.navItems[selectedIndex].label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),

                    SizedBox(width: 16),
                    // Student Selector
                    _buildStudentSelector(isMobile),

                    Spacer(),
                    // Notification Bell
                    GestureDetector(
                      onTap: () => _navigateToNotifications(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            Icon(
                              unreadNotificationCount > 0 
                                  ? Icons.notifications 
                                  : Icons.notifications_none,
                              color: const Color(0xFF000000),
                              size: 28,
                            ),
                            // Notification count badge
                            if (unreadNotificationCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    unreadNotificationCount > 99 
                                        ? '99+' 
                                        : unreadNotificationCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleProfile,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              showProfile
                                  ? greenWithOpacity
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: CircleAvatar(
                          backgroundColor: greenWithOpacity,
                          radius: 16,
                          backgroundImage:
                              profileImageUrl != null
                                  ? NetworkImage(profileImageUrl!)
                                  : null,
                          child:
                              profileImageUrl == null
                                  ? Icon(
                                    Icons.person,
                                    color: widget.primaryColor,
                                    size: 18,
                                  )
                                  : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: _buildTabContent(
                      selectedIndex,
                      widget.primaryColor,
                      isMobile,
                    ),
                  ),
                ),
              ),
              // Bottom Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (i) {
                    final item = widget.navItems[i];
                    final bool selected = i == selectedIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? greenWithOpacity : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          item.icon,
                          color:
                              selected
                                  ? widget.primaryColor
                                  : const Color(0xFF000000).withOpacity(0.6),
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() => selectedIndex = i);
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          // Notification and Profile Popovers
          if (showNotifications)
            Positioned(
              top: 56,
              right: 56,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: const Color(0xFF000000).withOpacity(0.2),
                    child: Container(
                      width: 280,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            3,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color:
                                        i == 0
                                            ? widget.primaryColor
                                            : const Color(
                                              0xFF000000,
                                            ).withOpacity(0.3),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Notification message ${i + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF000000),
                                      ),
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
                ),
              ),
            ),
          if (showProfile)
            Positioned(
              top: 56,
              right: 16,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    shadowColor: const Color(0xFF000000).withOpacity(0.2),
                    child: Container(
                      width: 240,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: greenWithOpacity,
                                radius: 20,
                                backgroundImage:
                                    profileImageUrl != null
                                        ? NetworkImage(profileImageUrl!)
                                        : null,
                                child:
                                    profileImageUrl == null
                                        ? Icon(
                                          Icons.person,
                                          color: widget.primaryColor,
                                          size: 22,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isLoadingProfile
                                          ? 'Loading...'
                                          : userName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF000000),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isLoadingProfile
                                          ? 'Loading...'
                                          : userEmail,
                                      style: TextStyle(
                                        color: const Color(
                                          0xFF000000,
                                        ).withOpacity(0.6),
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: const Color(0xFF000000).withOpacity(0.2),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              icon: Icon(Icons.logout),
                              label: Text('Logout'),
                              onPressed: () {
                                _showLogoutConfirmation(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index, Color primaryColor, bool isMobile) {
    // Don't render tab content if no student is selected
    if (selectedStudent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              isLoadingStudents ? 'Loading students...' : 'No students found',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF000000).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    switch (index) {
      case 0:
        // Pass selected student to ParentDashboardTab
        return ParentDashboardTab(
          primaryColor: primaryColor,
          isMobile: isMobile,
          selectedStudentId: selectedStudent!.id,
        );
      case 1:
        // Pass selected student to PickupDropoffScreen
        return PickupDropoffScreen(
          primaryColor: primaryColor,
          isMobile: isMobile,
          selectedStudentId: selectedStudent!.id,
        );
      case 2:
        // Pass selected student to FetchersScreen
        return FetchersScreen(
          primaryColor: primaryColor,
          isMobile: isMobile,
          selectedStudentId: selectedStudent!.id,
        );
      case 3:
        // Pass selected student to ConfirmationLogsScreen
        return ConfirmationLogsScreen(
          primaryColor: primaryColor,
          isMobile: isMobile,
          selectedStudentId: selectedStudent!.id,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
