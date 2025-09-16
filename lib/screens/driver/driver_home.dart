import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_dashboard_tab.dart';
import 'driver_pickup_tab.dart';
import 'driver_students_tab.dart';
import 'driver_notifications_tab.dart';
import 'driver_profile_tab.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
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
    return _DriverHomeTabs(
      navItems: navItems,
      primaryColor: primaryGreen,
      secondaryText: black.withOpacity(0.7),
      logout: _logout,
      showErrorDialog: _showErrorDialog,
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
  late PageController _pageController;

  void _toggleNotifications() {
    setState(() {
      showNotifications = !showNotifications;
      if (showNotifications) showProfile = false;
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
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
                        if (showNotifications)
                          Positioned(
                            right: 0,
                            top: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF19AE61),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleProfile,
                      child: const CircleAvatar(
                        backgroundColor: Color.fromRGBO(25, 174, 97, 0.171),
                        radius: 16,
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF19AE61),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => selectedIndex = index);
                  },
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
                      onPressed: () {
                        setState(() => selectedIndex = i);
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
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
                width: 300,
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
        return DriverNotificationsTab(
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
