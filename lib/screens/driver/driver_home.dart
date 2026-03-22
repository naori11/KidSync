import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_dashboard_tab.dart';
import 'driver_pickup_tab.dart';
import 'driver_students_tab.dart';
import 'driver_recent_activity.dart';
import 'driver_notifications.dart';
import 'driver_profile_tab.dart';
import '../../services/driver_audit_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/in_app_notification_widget.dart';

class DriverHomeScreen extends StatelessWidget {
  DriverHomeScreen({Key? key}) : super(key: key);

  final DriverAuditService _driverAuditService = DriverAuditService();

  Future<void> _logout(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Log logout activity (HIGH PRIORITY - Driver Authentication)
      if (user != null) {
        try {
          await _driverAuditService.logDriverAuthActivity(
            activity: 'logout',
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            isSuccessful: true,
          );
        } catch (auditError) {
          print('Error logging logout activity: $auditError');
        }
      }

      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      // Log logout failure
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await _driverAuditService.logDriverAuthActivity(
            activity: 'logout',
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            isSuccessful: false,
            failureReason: error.toString(),
          );
        } catch (auditError) {
          print('Error logging logout failure: $auditError');
        }
      }

      if (context.mounted) {
        _showErrorDialog(
          context,
          'Logout Error',
          'An error occurred while logging out: $error',
          'Retry',
          () => _logout(context),
        );
      }
    }
  }

  void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
    String retryText,
    VoidCallback? onRetry,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF19AE61),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(retryText, style: const TextStyle(fontSize: 16)),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Students', Icons.group, 'students'),
      _NavItem('Recent Activity', Icons.update, 'activity'),
    ];
    return InAppNotificationWidget(
      userRole: 'driver',
      primaryColor: primaryGreen,
      child: _DriverHomeTabs(
        navItems: navItems,
        primaryColor: primaryGreen,
        secondaryText: black.withOpacity(0.7),
        logout: _logout,
        showErrorDialog: _showErrorDialog,
      ),
    );
  }
}

class _DriverHomeTabs extends StatefulWidget {
  final List<_NavItem> navItems;
  final Color primaryColor;
  final Color secondaryText;
  final Future<void> Function(BuildContext) logout;
  final Function(BuildContext, String, String, String, VoidCallback?)
  showErrorDialog;

  const _DriverHomeTabs({
    required this.navItems,
    required this.primaryColor,
    required this.secondaryText,
    required this.logout,
    required this.showErrorDialog,
    Key? key,
  }) : super(key: key);

  @override
  State<_DriverHomeTabs> createState() => _DriverHomeTabsState();
}

class _DriverHomeTabsState extends State<_DriverHomeTabs> {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;
  int unreadNotificationCount = 0;
  late PageController _pageController;
  final DriverAuditService _driverAuditService = DriverAuditService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeNotifications();
    _setupAuthListener();
    _logDashboardAccess();
    _loadNotificationCount();
    // Set up periodic refresh for notification count
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotificationCount();
      }
    });
  }

  /// Initialize push notifications for driver
  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initializePushNotifications();
      print('✅ Notifications initialized for driver');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Load unread notification count for the driver
  Future<void> _loadNotificationCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final count = await _notificationService
            .getUnreadDriverNotificationCount(user.id);
        if (mounted) {
          setState(() {
            unreadNotificationCount = count;
          });
        }
      }
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  /// Get driver profile image URL
  Future<String?> _getDriverProfileImage() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response =
          await Supabase.instance.client
              .from('users')
              .select('profile_image_url')
              .eq('id', user.id)
              .maybeSingle();

      return response?['profile_image_url'];
    } catch (e) {
      print('Error getting driver profile image: $e');
      return null;
    }
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      AuthState data,
    ) {
      if (data.event == AuthChangeEvent.signedOut) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  /// Log dashboard access for driver authentication tracking
  Future<void> _logDashboardAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _driverAuditService.logDashboardAccess(
          driverId: user.id,
          driverName: user.userMetadata?['fname'] ?? 'Driver',
          dashboardMetrics: {
            'initial_tab': 'dashboard',
            'session_start': DateTime.now().toIso8601String(),
            'platform': 'mobile_app',
          },
        );
      }
    } catch (auditError) {
      print('Error logging dashboard access: $auditError');
    }
  }

  void _toggleNotifications() {
    setState(() {
      showNotifications = !showNotifications;
      if (showNotifications) {
        showProfile = false;
        // Refresh notification count when opening
        _loadNotificationCount();
      }
    });
  }

  void _toggleProfile() {
    setState(() {
      showProfile = !showProfile;
      if (showProfile) showNotifications = false;
    });
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _onNavItemTapped(int index) {
    if (index != selectedIndex && _pageController.hasClients) {
      setState(() {
        selectedIndex = index;
        showNotifications = false;
        showProfile = false;
      });

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (index != selectedIndex) {
      setState(() {
        selectedIndex = index;
      });
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _authSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(
                        Icons.local_shipping,
                        color: Color(0xFF19AE61),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Panel Name
                    Text(
                      widget.navItems[selectedIndex].label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const Spacer(),
                    // Notification Bell
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Color(0xFF000000),
                            size: 28,
                          ),
                          onPressed: _toggleNotifications,
                        ),
                        if (unreadNotificationCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF19AE61),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadNotificationCount > 9
                                    ? '9+'
                                    : unreadNotificationCount.toString(),
                                style: const TextStyle(
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
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleProfile,
                      child: FutureBuilder<String?>(
                        future: _getDriverProfileImage(),
                        builder: (context, snapshot) {
                          final profileImageUrl = snapshot.data;
                          return CircleAvatar(
                            backgroundColor: Color.fromRGBO(25, 174, 97, 0.171),
                            radius: 16,
                            backgroundImage:
                                profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                            child:
                                profileImageUrl == null ||
                                        profileImageUrl.isEmpty
                                    ? Icon(
                                      Icons.person,
                                      color: Color(0xFF19AE61),
                                      size: 18,
                                    )
                                    : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.navItems.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: _buildTabContent(index, isMobile),
                    );
                  },
                ),
              ),
              // Bottom Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
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
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(widget.navItems.length, (i) {
                    final item = widget.navItems[i];
                    final bool selected = i == selectedIndex;
                    return IconButton(
                      icon: Icon(
                        item.icon,
                        color:
                            selected
                                ? widget.primaryColor
                                : widget.secondaryText,
                        size: 28,
                      ),
                      onPressed: () => _onNavItemTapped(i),
                    );
                  }),
                ),
              ),
            ],
          ),
          // Notifications Popover
          if (showNotifications)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 400,
                height: 500,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DriverNotificationsTab(
                  primaryColor: widget.primaryColor,
                  isMobile: isMobile,
                ),
              ),
            ),
          // Profile Popover
          if (showProfile)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DriverProfileTab(
                  logout: () => _showLogoutConfirmation(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index, bool isMobile) {
    switch (index) {
      case 0:
        return DriverDashboardTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 1:
        return DriverPickupTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 2:
        return DriverStudentsTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 3:
        return DriverRecentActivity(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
