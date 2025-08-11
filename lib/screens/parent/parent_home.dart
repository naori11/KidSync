import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../models/driver_models.dart';

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

class _ParentHomeTabsState extends State<_ParentHomeTabs>
    with TickerProviderStateMixin {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
                color: white,
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
                          child: Icon(
                            Icons.person,
                            color: widget.primaryColor,
                            size: 18,
                          ),
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
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(3, (i) {
                    // Only 3 icons now
                    final item = widget.navItems[i];
                    final bool selected = i == selectedIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                          size: 28,
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
          // Notification Popover
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
                                  const SizedBox(width: 8),
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
              ),
            ),
          // Profile Popover
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
                                child: Icon(
                                  Icons.person,
                                  color: widget.primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
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
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    switch (index) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notification Card (larger, responsive)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: primaryColor.withOpacity(0.3),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      isMobile ? 16 : 32,
                    ), // Responsive padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: greenWithOpacity,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: widget.primaryColor,
                                size: isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: isMobile ? 8 : 12),
                            Text(
                              'Pick-up Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 15 : 16,
                                color: const Color(0xFF000000),
                              ),
                            ),
                          ],
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
                                  elevation: 2,
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
                                icon: const Icon(
                                  Icons.directions_car,
                                  size: 18,
                                ),
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
              ),
            ),
            SizedBox(height: isMobile ? 10 : 14),
            // Driver Information Card
            _buildDriverInfoCard(primaryColor, isMobile),
            SizedBox(height: isMobile ? 10 : 14),
            // Pickup Summary Card
            _buildPickupSummaryCard(primaryColor, isMobile),
            SizedBox(height: isMobile ? 10 : 14),
            // Today's Schedule Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: primaryColor.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: greenWithOpacity,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: widget.primaryColor,
                                size: isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: isMobile ? 8 : 12),
                            Text(
                              "Today's Schedule",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 15 : 16,
                                color: const Color(0xFF000000),
                              ),
                            ),
                          ],
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
              ),
            ),
            SizedBox(height: isMobile ? 10 : 14),
            // Authorized Fetchers Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: primaryColor.withOpacity(0.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: greenWithOpacity,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.verified_user,
                                color: widget.primaryColor,
                                size: isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: isMobile ? 8 : 12),
                            Text(
                              'Authorized Fetchers',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 15 : 16,
                                color: const Color(0xFF000000),
                              ),
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
      elevation: 6,
      shadowColor: primaryColor.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
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

class _PickupDropoffTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const _PickupDropoffTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<_PickupDropoffTab> createState() => _PickupDropoffTabState();
}

class _PickupDropoffTabState extends State<_PickupDropoffTab> {
  String _selectedDropoffMode = 'driver'; // 'driver' or 'parent'
  String _selectedPickupMode = 'driver'; // 'driver' or 'parent'
  bool _hasDroppedOff = false;
  bool _hasPickedUp = false;

  // Advanced scheduling variables
  bool _showAdvancedScheduling = false;
  Map<String, Map<String, String>> _weeklySchedule = {
    'Monday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Tuesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Wednesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Thursday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Friday': {'dropoff': 'driver', 'pickup': 'driver'},
  };
  bool _hasUnassignedDays = false;

  @override
  void initState() {
    super.initState();
    _checkForUnassignedDays();
  }

  void _checkForUnassignedDays() {
    DateTime now = DateTime.now();

    // Check if tomorrow or next few days are unassigned
    bool hasUnassigned = false;
    for (int i = 1; i <= 3; i++) {
      DateTime futureDate = now.add(Duration(days: i));
      String dayName = _getDayName(futureDate.weekday);
      if (_weeklySchedule[dayName] == null ||
          _weeklySchedule[dayName]!['dropoff'] == null ||
          _weeklySchedule[dayName]!['pickup'] == null) {
        hasUnassigned = true;
        break;
      }
    }

    setState(() {
      _hasUnassignedDays = hasUnassigned;
    });
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      default:
        return '';
    }
  }

  Widget _buildDayScheduler(String day) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    return Container(
      margin: EdgeInsets.only(bottom: widget.isMobile ? 12 : 16),
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: widget.isMobile ? 15 : 17,
              color: black,
            ),
          ),
          SizedBox(height: widget.isMobile ? 12 : 16),

          // Drop-off Options
          Text(
            'Drop-off (8:00 AM)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: widget.isMobile ? 13 : 15,
              color: black.withOpacity(0.8),
            ),
          ),
          SizedBox(height: widget.isMobile ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['dropoff'] = 'driver';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['dropoff'] == 'driver'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['dropoff'] == 'driver'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['dropoff'] == 'driver'
                                ? 2
                                : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color:
                              _weeklySchedule[day]!['dropoff'] == 'driver'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['dropoff'] == 'driver'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['dropoff'] = 'parent';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['dropoff'] == 'parent'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['dropoff'] == 'parent'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['dropoff'] == 'parent'
                                ? 2
                                : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color:
                              _weeklySchedule[day]!['dropoff'] == 'parent'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Parent',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['dropoff'] == 'parent'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Pick-up Options
          Text(
            'Pick-up (3:30 PM)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: widget.isMobile ? 13 : 15,
              color: black.withOpacity(0.8),
            ),
          ),
          SizedBox(height: widget.isMobile ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['pickup'] = 'driver';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['pickup'] == 'driver'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['pickup'] == 'driver'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['pickup'] == 'driver' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color:
                              _weeklySchedule[day]!['pickup'] == 'driver'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['pickup'] == 'driver'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['pickup'] = 'parent';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['pickup'] == 'parent'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['pickup'] == 'parent'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['pickup'] == 'parent' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color:
                              _weeklySchedule[day]!['pickup'] == 'parent'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Parent',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['pickup'] == 'parent'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Today's Pickup/Dropoff Status
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: widget.primaryColor.withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          'Today\'s Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 16 : 20),
                    _buildScheduleItem(
                      '8:00 AM',
                      'Drop-off',
                      _hasDroppedOff
                          ? 'Completed by ${_selectedDropoffMode == 'driver' ? 'Driver' : 'Parent'}'
                          : 'Pending',
                      _hasDroppedOff,
                      widget.isMobile,
                      widget.primaryColor,
                      black,
                    ),
                    SizedBox(height: widget.isMobile ? 8 : 12),
                    _buildScheduleItem(
                      '3:30 PM',
                      'Pick-up',
                      _hasPickedUp
                          ? 'Completed by ${_selectedPickupMode == 'driver' ? 'Driver' : 'Parent'}'
                          : 'Pending',
                      _hasPickedUp,
                      widget.isMobile,
                      widget.primaryColor,
                      black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: widget.isMobile ? 12 : 16),

        // Unassigned Days Alert
        if (_hasUnassignedDays)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.orange.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Expanded(
                            child: Text(
                              'Upcoming Days Need Assignment',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 15 : 16,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      Text(
                        'You have upcoming school days without pickup/dropoff assignments. Please schedule them to avoid last-minute confusion.',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 15,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: white,
                            padding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          icon: Icon(
                            Icons.calendar_month,
                            size: widget.isMobile ? 18 : 20,
                          ),
                          label: Text(
                            'Schedule Future Days',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _showAdvancedScheduling = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (_hasUnassignedDays) SizedBox(height: widget.isMobile ? 12 : 16),

        // Advanced Scheduling Panel
        if (_showAdvancedScheduling)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: widget.primaryColor.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.event_note,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Expanded(
                            child: Text(
                              'Weekly Schedule Planner',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 15 : 16,
                                color: black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: black.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _showAdvancedScheduling = false;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      Text(
                        'Set default arrangements for each day of the week:',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 15,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      ..._weeklySchedule.keys
                          .map((day) => _buildDayScheduler(day))
                          .toList(),
                      SizedBox(height: widget.isMobile ? 20 : 24),
                      Row(
                        children: [
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
                                Icons.auto_awesome,
                                size: widget.isMobile ? 18 : 20,
                              ),
                              label: Text(
                                'Set All to Driver',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  for (String day in _weeklySchedule.keys) {
                                    _weeklySchedule[day] = {
                                      'dropoff': 'driver',
                                      'pickup': 'driver',
                                    };
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 12),
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
                                elevation: 2,
                              ),
                              icon: Icon(
                                Icons.save,
                                size: widget.isMobile ? 18 : 20,
                              ),
                              label: Text(
                                'Save Schedule',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showAdvancedScheduling = false;
                                  _hasUnassignedDays = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Weekly schedule saved successfully!',
                                    ),
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
            ),
          ),

        if (_showAdvancedScheduling)
          SizedBox(height: widget.isMobile ? 12 : 16),

        // Quick Schedule Button
        if (!_showAdvancedScheduling && !_hasUnassignedDays)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _showAdvancedScheduling = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.schedule,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: widget.isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced Scheduling',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 15 : 16,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plan your weekly pickup & dropoff schedule',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 12 : 14,
                                color: black.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (!_showAdvancedScheduling && !_hasUnassignedDays)
          SizedBox(height: widget.isMobile ? 12 : 16),

        // Drop-off Selection and Action
        if (!_hasDroppedOff)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.school,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Morning Drop-off Options',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 15 : 16,
                              color: black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      Text(
                        'Who will drop off your child today?',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 15,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDropoffMode = 'driver';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                  widget.isMobile ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedDropoffMode == 'driver'
                                          ? widget.primaryColor.withOpacity(0.1)
                                          : white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedDropoffMode == 'driver'
                                            ? widget.primaryColor
                                            : black.withOpacity(0.2),
                                    width:
                                        _selectedDropoffMode == 'driver'
                                            ? 2
                                            : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      color:
                                          _selectedDropoffMode == 'driver'
                                              ? widget.primaryColor
                                              : black.withOpacity(0.6),
                                      size: widget.isMobile ? 24 : 30,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Driver Drop-off',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: widget.isMobile ? 13 : 15,
                                        color:
                                            _selectedDropoffMode == 'driver'
                                                ? widget.primaryColor
                                                : black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDropoffMode = 'parent';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                  widget.isMobile ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedDropoffMode == 'parent'
                                          ? widget.primaryColor.withOpacity(0.1)
                                          : white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedDropoffMode == 'parent'
                                            ? widget.primaryColor
                                            : black.withOpacity(0.2),
                                    width:
                                        _selectedDropoffMode == 'parent'
                                            ? 2
                                            : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color:
                                          _selectedDropoffMode == 'parent'
                                              ? widget.primaryColor
                                              : black.withOpacity(0.6),
                                      size: widget.isMobile ? 24 : 30,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Parent Drop-off',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: widget.isMobile ? 13 : 15,
                                        color:
                                            _selectedDropoffMode == 'parent'
                                                ? widget.primaryColor
                                                : black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      SizedBox(
                        width: double.infinity,
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
                            elevation: 2,
                          ),
                          icon: Icon(
                            Icons.check_circle,
                            size: widget.isMobile ? 18 : 20,
                          ),
                          label: Text(
                            'Confirm Drop-off by ${_selectedDropoffMode == 'driver' ? 'Driver' : 'Me'}',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _hasDroppedOff = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Drop-off confirmed! ${_selectedDropoffMode == 'driver' ? 'Driver will handle the drop-off' : 'You will drop off your child'}',
                                ),
                                backgroundColor: widget.primaryColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (!_hasDroppedOff) SizedBox(height: widget.isMobile ? 12 : 16),

        // Pick-up Selection and Action
        if (!_hasPickedUp)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.home,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Afternoon Pick-up Options',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 15 : 16,
                              color: black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      Text(
                        'Who will pick up your child today?',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 15,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPickupMode = 'driver';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                  widget.isMobile ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPickupMode == 'driver'
                                          ? widget.primaryColor.withOpacity(0.1)
                                          : white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedPickupMode == 'driver'
                                            ? widget.primaryColor
                                            : black.withOpacity(0.2),
                                    width:
                                        _selectedPickupMode == 'driver' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_shipping,
                                      color:
                                          _selectedPickupMode == 'driver'
                                              ? widget.primaryColor
                                              : black.withOpacity(0.6),
                                      size: widget.isMobile ? 24 : 30,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Driver Pick-up',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: widget.isMobile ? 13 : 15,
                                        color:
                                            _selectedPickupMode == 'driver'
                                                ? widget.primaryColor
                                                : black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPickupMode = 'parent';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                  widget.isMobile ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPickupMode == 'parent'
                                          ? widget.primaryColor.withOpacity(0.1)
                                          : white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _selectedPickupMode == 'parent'
                                            ? widget.primaryColor
                                            : black.withOpacity(0.2),
                                    width:
                                        _selectedPickupMode == 'parent' ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color:
                                          _selectedPickupMode == 'parent'
                                              ? widget.primaryColor
                                              : black.withOpacity(0.6),
                                      size: widget.isMobile ? 24 : 30,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Parent Pick-up',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: widget.isMobile ? 13 : 15,
                                        color:
                                            _selectedPickupMode == 'parent'
                                                ? widget.primaryColor
                                                : black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      SizedBox(
                        width: double.infinity,
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
                            elevation: 2,
                          ),
                          icon: Icon(
                            Icons.check_circle,
                            size: widget.isMobile ? 18 : 20,
                          ),
                          label: Text(
                            'Confirm Pick-up by ${_selectedPickupMode == 'driver' ? 'Driver' : 'Me'}',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _hasPickedUp = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Pick-up confirmed! ${_selectedPickupMode == 'driver' ? 'Driver will handle the pick-up' : 'You will pick up your child'}',
                                ),
                                backgroundColor: widget.primaryColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (!_hasPickedUp) SizedBox(height: widget.isMobile ? 12 : 16),

        // Reset Options (if both completed)
        if (_hasDroppedOff && _hasPickedUp)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 32 : 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'All Done for Today!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.isMobile ? 16 : 18,
                          color: widget.primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Both drop-off and pick-up have been completed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: widget.isMobile ? 13 : 15,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.primaryColor,
                          side: BorderSide(color: widget.primaryColor),
                          padding: EdgeInsets.symmetric(
                            vertical: widget.isMobile ? 12 : 16,
                            horizontal: widget.isMobile ? 16 : 20,
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
                          'Reset for Tomorrow',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _hasDroppedOff = false;
                            _hasPickedUp = false;
                            _selectedDropoffMode = 'driver';
                            _selectedPickupMode = 'driver';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Schedule reset for tomorrow'),
                              backgroundColor: widget.primaryColor,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? primaryColor : primaryColor.withOpacity(0.3),
          width: completed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: completed ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check_circle : Icons.schedule,
              color:
                  completed ? const Color(0xFFFFFFFF) : black.withOpacity(0.6),
              size: isMobile ? 16 : 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time - $action',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
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

  String _generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Temporary Fetcher
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: widget.primaryColor.withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          'Add Temporary Fetcher',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 16 : 20),
                    Container(
                      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temporary Access',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 14 : 16,
                              color: widget.primaryColor,
                            ),
                          ),
                          SizedBox(height: widget.isMobile ? 8 : 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fetcher Name',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 13 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: black,
                                ),
                              ),
                              SizedBox(height: widget.isMobile ? 6 : 8),
                              TextField(
                                controller: _fetcherNameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter full name',
                                  filled: true,
                                  fillColor: white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: widget.primaryColor.withOpacity(
                                        0.2,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: widget.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: widget.isMobile ? 12 : 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: widget.isMobile ? 12 : 16),
                          SizedBox(
                            width: double.infinity,
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
                                elevation: 2,
                              ),
                              icon: Icon(
                                Icons.security,
                                size: widget.isMobile ? 18 : 20,
                              ),
                              label: Text(
                                'Generate Secure PIN',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                if (_fetcherNameController.text
                                    .trim()
                                    .isNotEmpty) {
                                  setState(() {
                                    _currentFetcherName =
                                        _fetcherNameController.text.trim();
                                    _currentPin = _generatePin();
                                  });
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: widget.primaryColor,
                                              size: 24,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'PIN Generated',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: black,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          'PIN generated successfully for ${_currentFetcherName}',
                                          style: TextStyle(
                                            color: black.withOpacity(0.7),
                                          ),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  widget.primaryColor,
                                              foregroundColor: white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  // Show error in center with better styling
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 24,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Input Required',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: black,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          'Please enter a fetcher name to generate a PIN.',
                                          style: TextStyle(
                                            color: black.withOpacity(0.7),
                                          ),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  widget.primaryColor,
                                              foregroundColor: white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: widget.isMobile ? 12 : 16),

        // Current Temporary Fetcher PIN
        if (_currentFetcherName != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: widget.primaryColor.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.person_pin,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Active Temporary Access',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 15 : 16,
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
                          border: Border.all(
                            color: widget.primaryColor,
                            width: 2,
                          ),
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
                            const SizedBox(height: 8),
                            Text(
                              'PIN Code',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 8),
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
                          const SizedBox(width: 12),
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
            ),
          ),

        SizedBox(height: widget.isMobile ? 12 : 16),

        // Authorized Fetchers List
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: widget.primaryColor.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.verified_user,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          'Authorized Fetchers',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: black,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 8),
                    _buildFetcherItem(
                      'Sarah Johnson',
                      'Grandmother',
                      true,
                      widget.isMobile,
                      widget.primaryColor,
                      black,
                      greenWithOpacity,
                    ),
                    const SizedBox(height: 8),
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
          ),
        ),
      ],
    );
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
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              backgroundColor: greenWithOpacity,
              radius: isMobile ? 16 : 20,
              child: Icon(
                Icons.person,
                color: primaryColor,
                size: isMobile ? 18 : 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 15 : 17,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      active ? Icons.check_circle : Icons.circle_outlined,
                      color: active ? primaryColor : black.withOpacity(0.4),
                      size: isMobile ? 14 : 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: active ? primaryColor : black.withOpacity(0.6),
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  active
                      ? primaryColor.withOpacity(0.1)
                      : black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              active ? Icons.security : Icons.security_outlined,
              color: active ? primaryColor : black.withOpacity(0.4),
              size: isMobile ? 16 : 18,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension methods for _ParentHomeTabsState
extension ParentHomeTabsExtension on _ParentHomeTabsState {
  Widget _buildDriverInfoCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    final driverInfo = StaticDriverData.driverInfo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Your Driver',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: greenWithOpacity,
                        radius: isMobile ? 24 : 30,
                        child: Icon(
                          Icons.person,
                          color: primaryColor,
                          size: isMobile ? 24 : 30,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverInfo.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vehicle: ${driverInfo.vehicleNumber}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  driverInfo.phoneNumber,
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(Icons.phone, size: isMobile ? 16 : 18),
                        label: Text(
                          'Call Driver',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Calling ${driverInfo.name}...'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.message, size: isMobile ? 16 : 18),
                        label: Text(
                          'Message',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opening message to ${driverInfo.name}...',
                              ),
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
      ),
    );
  }

  Widget _buildPickupSummaryCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.assignment_turned_in,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Today\'s Pickup Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                _buildSummaryItem(
                  Icons.school,
                  'Drop-off',
                  '8:00 AM - Arrived safely at school',
                  'Driver: John Smith verified arrival',
                  true,
                  primaryColor,
                  black,
                  isMobile,
                ),
                const SizedBox(height: 8),
                _buildSummaryItem(
                  Icons.schedule,
                  'Current Status',
                  '2:15 PM - Present in Story Time class',
                  'Last scanned at classroom entrance',
                  true,
                  primaryColor,
                  black,
                  isMobile,
                ),
                const SizedBox(height: 8),
                _buildSummaryItem(
                  Icons.directions_car,
                  'Pickup',
                  '3:30 PM - Scheduled pickup time',
                  'Driver: John Smith will pick up',
                  false,
                  primaryColor,
                  black,
                  isMobile,
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Real-time updates will appear here when your child is picked up',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: black.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String title,
    String time,
    String description,
    bool completed,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    const Color white = Color(0xFFFFFFFF);

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: completed ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : icon,
              color: completed ? white : black.withOpacity(0.6),
              size: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 15,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: black.withOpacity(0.6),
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
