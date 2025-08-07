import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'notifications.dart';

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
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);
    const Color white = Color(0xFFFFFFFF);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Fetchers', Icons.group, 'fetchers'),
      // Removed Notifications from bottom nav
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

class _ParentHomeTabsState extends State<_ParentHomeTabs> {
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

  Widget _fetcherRow(
    String name,
    String role,
    bool active,
    Color primaryColor, [
    bool isMobile = false,
  ]) {
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
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
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.171);
    return Scaffold(
      backgroundColor: greenWithOpacity,
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                color: white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Spacer(),
                    // Notification Bell
                    GestureDetector(
                      onTap: _toggleNotifications,
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
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleProfile,
                      child: CircleAvatar(
                        backgroundColor: greenWithOpacity,
                        radius: 16,
                        child: Icon(
                          Icons.person,
                          color: widget.primaryColor,
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
                color: white,
                padding: EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(3, (i) {
                    // Only 3 icons now
                    final item = widget.navItems[i];
                    final bool selected = i == selectedIndex;
                    return IconButton(
                      icon: Icon(
                        item.icon,
                        color:
                            selected
                                ? widget.primaryColor
                                : const Color(0xFF000000).withOpacity(0.6),
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
          // Notification Popover
          if (showNotifications)
            Positioned(
              top: 56,
              right: 56,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 280,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
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
                      SizedBox(height: 12),
                      // Example notifications
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
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Notification message # {i + 1}',
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
                      SizedBox(width: isMobile ? 4 : 8),
                    ],
                  ),
                ),
              ),
            ),
          // Profile Popover
          if (showProfile)
            Positioned(
              top: 56,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 240,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
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
                            child: Icon(
                              Icons.person,
                              color: widget.primaryColor,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parent Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF000000),
                                ),
                              ),
                              Text(
                                'parent@email.com',
                                style: TextStyle(
                                  color: const Color(
                                    0xFF000000,
                                  ).withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(color: const Color(0xFF000000).withOpacity(0.2)),
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
        ],
      ),
    );
  }

  Widget _buildTabContent(int index, Color primaryColor, bool isMobile) {
    switch (index) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notification Card (larger, responsive)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(
                  isMobile ? 16 : 32,
                ), // Responsive padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick-up Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: widget.primaryColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for Pick-up',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: widget.primaryColor,
                            fontSize: isMobile ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today, 3:30 PM',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.7),
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 12 : 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  primaryColor, // Green for primary button
                              foregroundColor: Colors.white, // White text
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 10 : 16,
                              ),
                              textStyle: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Confirm Pick-up'),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  primaryColor, // Green for outlined button text
                              side: BorderSide(
                                color: primaryColor,
                              ), // Green border
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 10 : 16,
                              ),
                              textStyle: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                              ),
                            ),
                            icon: const Icon(Icons.directions_car, size: 18),
                            label: const Text('Confirm Drop-off'),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isMobile ? 10 : 14),
            // Today's Schedule Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Row(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '8:00 AM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 15,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Drop-off',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.6),
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 13 : 15,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Row(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '3:30 PM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 15,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pick-up',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.6),
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 13 : 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isMobile ? 10 : 14),
            // Authorized Fetchers Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authorized Fetchers',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 10),
                    _fetcherRow(
                      'John Smith',
                      'Father',
                      true,
                      primaryColor,
                      isMobile,
                    ),
                    _fetcherRow(
                      'Sarah Johnson',
                      'Grandmother',
                      true,
                      primaryColor,
                      isMobile,
                    ),
                    _fetcherRow(
                      'Mike Wilson',
                      'Driver',
                      false,
                      primaryColor,
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 1:
        return _PickupDropoffTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 2:
        return _FetchersTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 3:
        return _NotificationsTab(primaryColor: widget.primaryColor);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NotificationsTab extends StatelessWidget {
  final Color primaryColor;
  const _NotificationsTab({required this.primaryColor, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: primaryColor,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 16 : 18,
                    color: const Color(0xFF000000),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 24),
            _notificationRow(
              'Student arrived safely at school',
              '2h ago',
              isMobile,
            ),
            _notificationRow(
              'Pick-up will be at 3:30 PM today',
              '1h ago',
              isMobile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationRow(String message, String time, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 10),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color: const Color(0xFF000000).withOpacity(0.3),
            size: isMobile ? 18 : 22,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isMobile ? 13 : 15,
                color: const Color(0xFF000000),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Text(
            time,
            style: TextStyle(
              color: const Color(0xFF000000).withOpacity(0.6),
              fontSize: isMobile ? 10 : 12,
            ),
          ),
        ],
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
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Today's Pickup/Dropoff Status
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: primaryColor,
                      size: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Today\'s Schedule',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 16 : 18,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 20),
                _buildScheduleItem(
                  '8:00 AM',
                  'Drop-off',
                  'Completed',
                  true,
                  isMobile,
                  primaryColor,
                  black,
                ),
                SizedBox(height: isMobile ? 8 : 12),
                _buildScheduleItem(
                  '3:30 PM',
                  'Pick-up',
                  'Pending',
                  false,
                  isMobile,
                  primaryColor,
                  black,
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: isMobile ? 12 : 16),

        // Confirmation Actions
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 16 : 18,
                    color: black,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          Icons.check_circle,
                          size: isMobile ? 18 : 20,
                        ),
                        label: Text(
                          'Confirm Pick-up',
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pick-up confirmed for today'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          Icons.directions_car,
                          size: isMobile ? 18 : 20,
                        ),
                        label: Text(
                          'Confirm Drop-off',
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Drop-off confirmed for today'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: isMobile ? 12 : 16),

        // Date Selection
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Date',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 16 : 18,
                    color: black,
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: primaryColor,
                        size: isMobile ? 18 : 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Today, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                        onPressed: () {
                          // TODO: Implement date picker
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Date picker functionality'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(
    String time,
    String action,
    String status,
    bool completed,
    bool isMobile,
    Color primaryColor,
    Color black,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.schedule,
            color: completed ? primaryColor : black.withOpacity(0.6),
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time - $action',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchersTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const _FetchersTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<_FetchersTab> createState() => _FetchersTabState();
}

class _FetchersTabState extends State<_FetchersTab> {
  final TextEditingController _fetcherNameController = TextEditingController();
  String _currentPin = '8472';
  String? _currentFetcherName;

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Temporary Fetcher
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: widget.primaryColor,
                      size: widget.isMobile ? 20 : 24,
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Add Temporary Fetcher',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isMobile ? 16 : 18,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                TextField(
                  controller: _fetcherNameController,
                  decoration: InputDecoration(
                    labelText: 'Fetcher Name',
                    hintText: 'Enter fetcher name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: white,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.qr_code, size: widget.isMobile ? 18 : 20),
                  label: Text(
                    'Generate PIN',
                    style: TextStyle(fontSize: widget.isMobile ? 14 : 16),
                  ),
                  onPressed: () {
                    if (_fetcherNameController.text.trim().isNotEmpty) {
                      setState(() {
                        _currentFetcherName =
                            _fetcherNameController.text.trim();
                        _currentPin = _generatePin();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'PIN generated for ${_currentFetcherName}',
                          ),
                          backgroundColor: widget.primaryColor,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a fetcher name'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: widget.isMobile ? 12 : 16),

        // Current Temporary Fetcher PIN
        if (_currentFetcherName != null)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 20 : 24,
                      ),
                      SizedBox(width: widget.isMobile ? 8 : 12),
                      Text(
                        'Current Temporary Fetcher',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: widget.isMobile ? 16 : 18,
                          color: black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: widget.isMobile ? 16 : 20),
                  Container(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: greenWithOpacity,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.primaryColor, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentFetcherName!,
                          style: TextStyle(
                            fontSize: widget.isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: black,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'PIN Code',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: black,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isMobile ? 20 : 24,
                            vertical: widget.isMobile ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.primaryColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _currentPin,
                            style: TextStyle(
                              fontSize: widget.isMobile ? 24 : 32,
                              fontWeight: FontWeight.bold,
                              color: widget.primaryColor,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Valid for today only',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 12 : 14,
                            color: black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: widget.isMobile ? 16 : 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            foregroundColor: white,
                            padding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.copy,
                            size: widget.isMobile ? 18 : 20,
                          ),
                          label: Text(
                            'Copy PIN',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('PIN copied to clipboard'),
                                backgroundColor: widget.primaryColor,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.primaryColor,
                            side: BorderSide(color: widget.primaryColor),
                            padding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            Icons.refresh,
                            size: widget.isMobile ? 18 : 20,
                          ),
                          label: Text(
                            'Regenerate',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _currentPin = _generatePin();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('New PIN generated'),
                                backgroundColor: widget.primaryColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        SizedBox(height: widget.isMobile ? 12 : 16),

        // Authorized Fetchers List
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authorized Fetchers',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: widget.isMobile ? 16 : 18,
                    color: black,
                  ),
                ),
                SizedBox(height: widget.isMobile ? 12 : 16),
                _buildFetcherItem(
                  'John Smith',
                  'Father',
                  true,
                  widget.isMobile,
                  widget.primaryColor,
                  black,
                  greenWithOpacity,
                ),
                SizedBox(height: 8),
                _buildFetcherItem(
                  'Sarah Johnson',
                  'Grandmother',
                  true,
                  widget.isMobile,
                  widget.primaryColor,
                  black,
                  greenWithOpacity,
                ),
                SizedBox(height: 8),
                _buildFetcherItem(
                  'Mike Wilson',
                  'Driver',
                  false,
                  widget.isMobile,
                  widget.primaryColor,
                  black,
                  greenWithOpacity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  Widget _buildFetcherItem(
    String name,
    String role,
    bool active,
    bool isMobile,
    Color primaryColor,
    Color black,
    Color greenWithOpacity,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor, width: 1),
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.circle,
            color: active ? primaryColor : black.withOpacity(0.3),
            size: isMobile ? 12 : 14,
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  _NavItem(this.label, this.icon, this.route);
}
