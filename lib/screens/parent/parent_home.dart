import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    final Color primaryColor = const Color(0xFF2ECC71); // Match admin UI
    final Color highlightGreen = const Color.fromARGB(
      255,
      76,
      175,
      80,
    ); // For highlights, match admin
    final Color cardBackground = Colors.white;
    final Color mainText = Colors.black87;
    final Color secondaryText =
        Colors.grey[600] ?? Colors.grey; // Ensure non-nullable
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Fetchers', Icons.group, 'fetchers'),
      // Removed Notifications from bottom nav
    ];
    return _ParentHomeTabs(
      navItems: navItems,
      primaryColor: primaryColor,
      secondaryText: secondaryText,
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

  Widget _fetcherRow(
    String name,
    String role,
    bool active,
    Color primaryColor, [
    bool isMobile = false,
  ]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            radius: isMobile ? 16 : 20,
            child: Icon(
              Icons.person,
              color: Colors.grey[700],
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
                ),
              ),
              Text(
                role,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.circle,
            color: active ? primaryColor : Colors.grey[400],
            size: isMobile ? 10 : 12,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    final Color blue = const Color(0xFF007AFF);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                color: Colors.white,
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
                            color: Colors.grey[700],
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
                                color: Colors.red,
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
                        backgroundColor: Colors.grey[200],
                        radius: 16,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[700],
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
                color: Colors.white,
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
                    color: Colors.white,
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
                                        : Colors.grey[400],
                                size: 10,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Notification message # {i + 1}',
                                  style: TextStyle(fontSize: 14),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            radius: 20,
                            child: Icon(
                              Icons.person,
                              color: Colors.grey[700],
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
                                ),
                              ),
                              Text(
                                'parent@email.com',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(Icons.logout),
                          label: Text('Logout'),
                          onPressed: () {
                            widget.logout(context);
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for Pick-up',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                            fontSize: isMobile ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today, 3:30 PM',
                          style: TextStyle(
                            color: Colors.grey[700],
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
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '8:00 AM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Drop-off',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 13 : 15,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '3:30 PM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pick-up',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.orange,
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
                    Row(
                      children: [
                        Text(
                          'Authorized Fetchers',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 15 : 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.add, size: isMobile ? 18 : 20),
                          color: primaryColor,
                          onPressed: () {},
                          tooltip: 'Add Fetcher',
                        ),
                      ],
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
        return Center(
          child: Text(
            'Pick-up/Drop-off content here',
            style: TextStyle(fontSize: 18),
          ),
        );
      case 2:
        return Center(
          child: Text('Fetchers content here', style: TextStyle(fontSize: 18)),
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
            color: Colors.grey[400],
            size: isMobile ? 18 : 22,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: isMobile ? 13 : 15),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Text(
            time,
            style: TextStyle(color: Colors.grey, fontSize: isMobile ? 10 : 12),
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
