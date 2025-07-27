import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final Color primaryColor = const Color(0xFF19AE61);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Fetchers', Icons.group, 'fetchers'),
      _NavItem('Notifications', Icons.notifications_none, 'notifications'),
    ];
    return _ParentHomeTabs(navItems: navItems, primaryColor: primaryColor);
  }
}

class _ParentHomeTabs extends StatefulWidget {
  final List<_NavItem> navItems;
  final Color primaryColor;
  const _ParentHomeTabs({
    required this.navItems,
    required this.primaryColor,
    Key? key,
  }) : super(key: key);

  @override
  State<_ParentHomeTabs> createState() => _ParentHomeTabsState();
}

class _ParentHomeTabsState extends State<_ParentHomeTabs> {
  int selectedIndex = 0;

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isMobile ? 100 : 120),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double navBarHeight = isMobile ? 54 : 72;
            double navIconSize =
                constraints.maxWidth < 350 ? 18 : (isMobile ? 24 : 32);
            double navFontSize =
                constraints.maxWidth < 350 ? 11 : (isMobile ? 14 : 18);
            double navMinWidth =
                constraints.maxWidth < 350 ? 70 : (isMobile ? 90 : 140);
            double navPaddingH =
                constraints.maxWidth < 350 ? 8 : (isMobile ? 14 : 32);
            double navPaddingV =
                constraints.maxWidth < 350 ? 6 : (isMobile ? 10 : 18);
            double navUnderline =
                constraints.maxWidth < 350 ? 3 : (isMobile ? 4 : 6);
            double topRowHeight = isMobile ? 44 : 56;
            return Column(
              children: [
                Container(
                  color: Colors.white,
                  height: topRowHeight,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24),
                  child: Row(
                    children: [
                      SizedBox(
                        height: isMobile ? 24 : 32,
                        width: isMobile ? 24 : 32,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.school,
                                color: widget.primaryColor,
                                size: isMobile ? 18 : 28,
                              ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.notifications_none,
                          size: isMobile ? 20 : 26,
                        ),
                        color: Colors.grey[700],
                        onPressed: () {
                          setState(() => selectedIndex = 3);
                        },
                        tooltip: 'Notifications',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: isMobile ? 4 : 8),
                      CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: isMobile ? 12 : 16,
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[700],
                          size: isMobile ? 14 : 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  height: navBarHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(widget.navItems.length, (i) {
                        final item = widget.navItems[i];
                        final bool selected = i == selectedIndex;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => selectedIndex = i);
                            },
                            child: Container(
                              constraints: BoxConstraints(
                                minWidth: navMinWidth,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: navPaddingH,
                                vertical: navPaddingV,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color:
                                        selected
                                            ? widget.primaryColor
                                            : Colors.transparent,
                                    width: navUnderline,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.icon,
                                    color:
                                        selected
                                            ? widget.primaryColor
                                            : Colors.grey[700],
                                    size: navIconSize,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color:
                                          selected
                                              ? widget.primaryColor
                                              : Colors.grey[700],
                                      fontWeight:
                                          selected
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                      fontSize: navFontSize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 4 : 16,
            vertical: isMobile ? 6 : 12,
          ),
          child: _buildTabContent(selectedIndex, widget.primaryColor, isMobile),
        ),
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
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
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
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
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
