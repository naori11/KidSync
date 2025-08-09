import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/guard_models.dart';
import 'guard_dashboard_page.dart';
import 'student_verification_page.dart';
import 'recent_activity_page.dart';

final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;
final userName = user?.userMetadata?['full_name'] ?? 'User';

class GuardPanelContent extends StatefulWidget {
  const GuardPanelContent({super.key});

  @override
  State<GuardPanelContent> createState() => _GuardPanelContentState();
}

class _GuardPanelContentState extends State<GuardPanelContent> {
  int selectedIndex = 0;

  // Recent Activity page state
  String searchQuery = '';
  String selectedTimePeriod = 'Today';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  // Function to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await supabase.auth.signOut();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  // Define navigation items
  List<NavItem> get navItems => [
    NavItem("Dashboard", Icons.dashboard_outlined),
    NavItem("Student Verification", Icons.verified_outlined),
    NavItem("Recent Activity", Icons.history),
  ];

  // Helper method to get content based on selected index
  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0:
        return DashboardPage();
      case 1:
        return StudentVerificationPage();
      case 2:
        return RecentActivityPage(
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

  Widget _buildNavItem(NavItem item, int index) {
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
                      child: Text('Logout'),
                    ),
                  ],
                ),
          );
          if (shouldLogout == true) {
            _handleLogout(context);
          }
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 180,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Text(
                    "KidSync",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Navigation items
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      // Add extra spacing before logout
                      if (item.label == "Logout" && index > 0) {
                        return Column(
                          children: [
                            SizedBox(height: 16),
                            _buildNavItem(item, index),
                          ],
                        );
                      }
                      return _buildNavItem(item, index);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildNavItem(
                    NavItem("Logout", Icons.logout),
                    navItems.length,
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(child: _getContentForIndex(selectedIndex)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
