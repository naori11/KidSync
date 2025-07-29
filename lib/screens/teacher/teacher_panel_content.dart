import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_dashboard_page.dart';
import 'teacher_class_list_page.dart';
import 'teacher_class_management_page.dart';
import 'teacher_student_attendance_calendar_page.dart';

class TeacherPanelContent extends StatefulWidget {
  final String userName;
  const TeacherPanelContent({Key? key, required this.userName}) : super(key: key);

  @override
  State<TeacherPanelContent> createState() => _TeacherPanelContentState();
}

class _TeacherPanelContentState extends State<TeacherPanelContent> {
  int selectedIndex = 0;

  // Subpage navigation state
  String? subPage; // "attendance", "calendar"
  int? selectedSectionId;
  String? selectedSectionName;
  int? selectedStudentId;
  String? selectedStudentName;

  late final List<_TeacherNavItem> navItems;

  @override
  void initState() {
    super.initState();
    navItems = [
      _TeacherNavItem("Dashboard", Icons.dashboard),
      _TeacherNavItem("Class list", Icons.list_alt),
      _TeacherNavItem("Logout", Icons.logout),
    ];
  }

  void _showAttendancePage(int sectionId, String sectionName) {
    setState(() {
      subPage = "attendance";
      selectedSectionId = sectionId;
      selectedSectionName = sectionName;
      selectedStudentId = null;
      selectedStudentName = null;
    });
  }

  void _showStudentCalendarPage(int studentId, String studentName) {
    setState(() {
      subPage = "calendar";
      selectedStudentId = studentId;
      selectedStudentName = studentName;
    });
  }

  void _goBackToClassList() {
    setState(() {
      subPage = null;
      selectedSectionId = null;
      selectedSectionName = null;
      selectedStudentId = null;
      selectedStudentName = null;
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildNavItem(_TeacherNavItem item, int index) {
    final bool isSelected = selectedIndex == index && subPage == null;
    return InkWell(
      onTap: () {
        if (item.label == "Logout") {
          _handleLogout(context);
        } else {
          setState(() {
            selectedIndex = index;
            subPage = null;
            selectedSectionId = null;
            selectedSectionName = null;
            selectedStudentId = null;
            selectedStudentName = null;
          });
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
            Icon(item.icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
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
    if (subPage == "attendance" &&
        selectedSectionId != null &&
        selectedSectionName != null) {
      return TeacherClassManagementPage(
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName!,
        onStudentView: _showStudentCalendarPage,
        onBack: _goBackToClassList,
      );
    }
    if (subPage == "calendar" &&
        selectedStudentId != null &&
        selectedStudentName != null &&
        selectedSectionId != null &&
        selectedSectionName != null) {
      return TeacherStudentAttendanceCalendarPage(
        studentId: selectedStudentId!,
        studentName: selectedStudentName!,
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName!,
        onBack: _goBackToClassList,
      );
    }
    switch (index) {
      case 0:
        return const TeacherDashboardPage();
      case 1:
        return TeacherClassListPage(
          onViewAttendance: _showAttendancePage,
        );
      case 2:
        // Attendance is handled via subPage logic
        return const SizedBox();
      default:
        return const SizedBox();
    }
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
                  child: const Text(
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
  _TeacherNavItem(this.label, this.icon);
}