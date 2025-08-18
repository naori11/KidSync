import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../models/parent_models.dart';
import '../../models/driver_models.dart';
import 'parent_dashboard_tab.dart';
import 'pickup_dropoff_tab.dart';
import 'fetchers_tab.dart';
import 'confirmation_logs.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  _NavItem(this.label, this.icon, this.route);
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

    // Load dashboard data and user profile
    _loadDashboardFetchers();
    _loadUserProfile();
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
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final parentResponse =
          await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

      if (parentResponse == null) {
        setState(() => isDashboardLoading = false);
        return;
      }

      final parentId = parentResponse['id'];
      final studentResponse = await supabase
          .from('parent_student')
          .select('student_id')
          .eq('parent_id', parentId)
          .eq('is_primary', true);

      if (studentResponse.isNotEmpty) {
        final studentId = studentResponse.first['student_id'];
        final fetchersResponse = await supabase
            .from('parent_student')
            .select('''
              relationship_type,
              is_primary,
              parents!inner(
                id, fname, mname, lname, phone, email, status
              )
            ''')
            .eq('student_id', studentId)
            .limit(3); // Only show first 3 in dashboard

        final List<AuthorizedFetcher> fetchers =
            fetchersResponse
                .map((data) => AuthorizedFetcher.fromJson(data))
                .toList();

        setState(() {
          dashboardFetchers = fetchers;
          isDashboardLoading = false;
        });
      } else {
        setState(() => isDashboardLoading = false);
      }
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
                    Spacer(),
                    // Notification Bell
                    GestureDetector(
                      onTap: _toggleNotifications,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              showNotifications
                                  ? greenWithOpacity
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              color: const Color(0xFF000000),
                              size: 28,
                            ),
                            // Example badge
                            Positioned(
                              right: 0,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  shape: BoxShape.circle,
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
    switch (index) {
      case 0:
        // Use the separated ParentDashboardTab but with your existing dashboard content
        return ParentDashboardTab(
          primaryColor: primaryColor,
          isMobile: isMobile,
        );
      case 1:
        // Use the separated PickupDropoffScreen
        return PickupDropoffScreen(
          primaryColor: primaryColor,
          isMobile: isMobile,
        );
      case 2:
        // Use the separated FetchersScreen
        return FetchersScreen(primaryColor: primaryColor, isMobile: isMobile);
      case 3:
        // Use the separated ConfirmationLogsScreen
        return ConfirmationLogsScreen(
          primaryColor: primaryColor,
          isMobile: isMobile,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
