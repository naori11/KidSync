import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/guard_models.dart';
import 'guard_dashboard_page.dart';
import '../../../../core/utils/logger.dart';
import '../../../../screens/guard/recent_activity_page.dart' as old_recent_activity;

class GuardPanelContent extends ConsumerStatefulWidget {
  const GuardPanelContent({super.key});

  @override
  ConsumerState<GuardPanelContent> createState() => _GuardPanelContentState();
}

class _GuardPanelContentState extends ConsumerState<GuardPanelContent> {
  int selectedIndex = 0;
  String selectedTimePeriod = 'Today';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      logger.e('Error signing out', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  List<NavItem> get navItems => [
    NavItem("Dashboard", Icons.dashboard_outlined),
    NavItem("Student Verification", Icons.verified_outlined),
    NavItem("Recent Activity", Icons.history),
  ];

  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0:
        return const GuardDashboardPage();
      case 1:
        return Center(
          child: Text('Student Verification - To be migrated'),
        );
      case 2:
        return old_recent_activity.RecentActivityPage(
          searchQuery: searchQuery,
          selectedTimePeriod: selectedTimePeriod,
          searchController: searchController,
          onSearchChanged: (value) => setState(() => searchQuery = value),
          onTimePeriodChanged: (period) {
            setState(() {
              selectedTimePeriod = period;
            });
          },
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavItem(NavItem item, int index, bool isMobile) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () async {
        if (item.label == "Logout") {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: Text(
                    'Confirm Logout',
                    style: TextStyle(color: Colors.black),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(color: Colors.black),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      style: ButtonStyle(
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.hovered)) {
                                return Color(0xFF19AE61);
                              }
                              return Colors.black;
                            }),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Logout',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
          );
          if (shouldLogout == true) {
            await _handleLogout(context);
          }
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(
          isMobile ? 4 : 8,
          isMobile ? 2 : 4,
          isMobile ? 4 : 8,
          isMobile ? 2 : 4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              isSelected
                  ? Border.all(color: Colors.blue.withOpacity(0.3))
                  : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.blue : Colors.black54,
              size: isMobile ? 18 : 20,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 768;
          final isMobile = constraints.maxWidth < 768;

          return Row(
            children: [
              LayoutBuilder(
                builder: (context, sidebarConstraints) {
                  double sidebarWidth;
                  if (isMobile) {
                    sidebarWidth = constraints.maxWidth * 0.25;
                    sidebarWidth = sidebarWidth.clamp(60.0, 120.0);
                  } else if (isTablet) {
                    sidebarWidth = constraints.maxWidth * 0.2;
                    sidebarWidth = sidebarWidth.clamp(150.0, 200.0);
                  } else {
                    sidebarWidth = constraints.maxWidth * 0.15;
                    sidebarWidth = sidebarWidth.clamp(180.0, 250.0);
                  }

                  return Container(
                    width: sidebarWidth,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isMobile ? 8 : 16,
                            isMobile ? 16 : 24,
                            isMobile ? 8 : 16,
                            isMobile ? 20 : 32,
                          ),
                          child: Text(
                            isMobile ? "KS" : "KidSync",
                            style: TextStyle(
                              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: navItems.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final item = navItems[index];
                              if (item.label == "Logout" && index > 0) {
                                return Column(
                                  children: [
                                    SizedBox(height: isMobile ? 8 : 16),
                                    _buildNavItem(item, index, isMobile),
                                  ],
                                );
                              }
                              return _buildNavItem(item, index, isMobile);
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isMobile ? 12.0 : 24.0,
                          ),
                          child: _buildNavItem(
                            NavItem("Logout", Icons.logout),
                            navItems.length,
                            isMobile,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(child: _getContentForIndex(selectedIndex)),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
