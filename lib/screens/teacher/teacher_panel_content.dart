import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_dashboard_page.dart';
import 'teacher_class_list_page.dart';
import 'teacher_class_management_page.dart';
import 'teacher_student_attendance_calendar_page.dart';

class TeacherPanelContent extends StatefulWidget {
  final String userName;
  const TeacherPanelContent({Key? key, required this.userName})
    : super(key: key);

  @override
  State<TeacherPanelContent> createState() => _TeacherPanelContentState();
}

class _TeacherPanelContentState extends State<TeacherPanelContent> {
  int selectedIndex = 0;

  late final List<_TeacherNavItem> navItems;

  @override
  void initState() {
    super.initState();
    navItems = [
      _TeacherNavItem("Dashboard", Icons.dashboard, TeacherDashboardPage()),
      _TeacherNavItem("Class list", Icons.list_alt, TeacherClassListPage()),
      _TeacherNavItem(
        "Attendance",
        Icons.fact_check,
        TeacherClassManagementPage(),
      ),
      _TeacherNavItem("Logout", Icons.logout, null),
    ];
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
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

  Widget _buildNavItem(_TeacherNavItem item, int index) {
    final bool isSelected = selectedIndex == index;
    return InkWell(
      onTap: () {
        if (item.label == "Logout") {
          _handleLogout(context);
        } else {
          setState(() => selectedIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getContentForIndex(int index) {
    if (navItems[index].page != null) {
      return navItems[index].page!;
    }
    return const SizedBox();
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
                    style: const TextStyle(
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
                            const SizedBox(height: 16),
                            _buildNavItem(item, index),
                          ],
                        );
                      }
                      return _buildNavItem(item, index);
                    },
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
}

class _TeacherNavItem {
  final String label;
  final IconData icon;
  final Widget? page;

  _TeacherNavItem(this.label, this.icon, this.page);
}
