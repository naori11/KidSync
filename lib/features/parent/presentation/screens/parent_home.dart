import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../screens/parent/parent_dashboard_tab.dart';
import '../../../../screens/parent/pickup_dropoff_tab.dart';
import '../../../../screens/parent/fetchers_tab.dart';
import '../../../../screens/parent/confirmation_logs.dart';
import '../../../../services/notification_service.dart';
import '../../../../widgets/in_app_notification_widget.dart';
import '../../data/parent_repository.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  _NavItem(this.label, this.icon, this.route);
}

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Fetchers', Icons.group, 'fetchers'),
      _NavItem('Confirmation Logs', Icons.history, 'logs'),
    ];

    return InAppNotificationWidget(
      userRole: 'parent',
      primaryColor: primaryGreen,
      child: _ParentHomeTabs(
        navItems: navItems,
        primaryColor: primaryGreen,
        secondaryText: black.withOpacity(0.7),
        logout: (context) => _logout(context, ref),
      ),
    );
  }
}

class _ParentHomeTabs extends ConsumerStatefulWidget {
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
  ConsumerState<_ParentHomeTabs> createState() => _ParentHomeTabsState();
}

class _ParentHomeTabsState extends ConsumerState<_ParentHomeTabs> {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;
  int unreadNotificationCount = 0;
  late PageController _pageController;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final repository = ref.read(parentRepositoryProvider);
      final user = repository.currentUser;
      if (user != null) {
        // Placeholder - notification count loading not yet implemented
        if (mounted) {
          setState(() {
            unreadNotificationCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    }
  }

  void _toggleNotifications() {
    setState(() {
      showNotifications = !showNotifications;
      if (showNotifications) {
        showProfile = false;
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Column(
        children: [
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
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.family_restroom, color: Color(0xFF19AE61), size: 28),
                const SizedBox(width: 12),
                Text(
                  widget.navItems[selectedIndex].label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Color(0xFF000000), size: 28),
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
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadNotificationCount > 9 ? '9+' : unreadNotificationCount.toString(),
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
                  child: CircleAvatar(
                    backgroundColor: Color.fromRGBO(25, 174, 97, 0.171),
                    radius: 16,
                    child: Icon(Icons.person, color: Color(0xFF19AE61), size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.navItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: _buildTabContent(index, isMobile),
                );
              },
            ),
          ),
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
                    color: selected ? widget.primaryColor : widget.secondaryText,
                    size: 28,
                  ),
                  onPressed: () => _onNavItemTapped(i),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index, bool isMobile) {
    switch (index) {
      case 0:
        return ParentDashboardTab(primaryColor: widget.primaryColor, isMobile: isMobile);
      case 1:
        return PickupDropoffScreen(primaryColor: widget.primaryColor, isMobile: isMobile);
      case 2:
        return FetchersScreen(primaryColor: widget.primaryColor, isMobile: isMobile);
      case 3:
        return ConfirmationLogsScreen(primaryColor: widget.primaryColor, isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }
}
