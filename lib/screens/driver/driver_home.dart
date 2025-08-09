import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);
    const Color white = Color(0xFFFFFFFF);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Students', Icons.group, 'students'),
    ];
    return _DriverHomeTabs(
      navItems: navItems,
      primaryColor: primaryGreen,
      secondaryText: black.withOpacity(0.7),
      logout: _logout,
    );
  }
}

class _DriverHomeTabs extends StatefulWidget {
  final List<_NavItem> navItems;
  final Color primaryColor;
  final Color secondaryText;
  final Future<void> Function(BuildContext) logout;

  const _DriverHomeTabs({
    required this.navItems,
    required this.primaryColor,
    required this.secondaryText,
    required this.logout,
    Key? key,
  }) : super(key: key);

  @override
  State<_DriverHomeTabs> createState() => _DriverHomeTabsState();
}

class _DriverHomeTabsState extends State<_DriverHomeTabs> {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;

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
                color: const Color(0xFFFFFFFF),
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: _buildTabContent(selectedIndex, isMobile),
                  ),
                ),
              ),
              // Bottom Navigation Bar
              Container(
                color: const Color(0xFFFFFFFF),
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
                child: _NotificationsTab(
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
                child: _ProfileTab(
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
        return _DashboardTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 1:
        return _PickupDropoffTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 2:
        return _StudentsTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DashboardTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _DashboardTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Text(
        'Driver Dashboard (empty)',
        style: const TextStyle(fontSize: 20, color: Color(0xFF000000)),
      ),
    );
  }
}

class _PickupDropoffTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _PickupDropoffTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Text(
        'Pick-up/Drop-off (empty)',
        style: const TextStyle(fontSize: 20, color: Color(0xFF000000)),
      ),
    );
  }
}

class _StudentsTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _StudentsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Text(
        'Students (empty)',
        style: const TextStyle(fontSize: 20, color: Color(0xFF000000)),
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _NotificationsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Text(
        'Notifications (empty)',
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final VoidCallback logout;

  const _ProfileTab({required this.logout, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        'Profile (empty)',
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
