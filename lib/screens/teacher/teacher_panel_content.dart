import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'teacher_dashboard_page.dart';
import 'class_list_page.dart';
import 'attendance_taking_page.dart';
import 'student_attendance_calendar_page.dart';
import 'section_attendance_summary_page.dart';

class TeacherPanelContent extends StatefulWidget {
  final String userName;
  const TeacherPanelContent({Key? key, required this.userName})
    : super(key: key);

  @override
  State<TeacherPanelContent> createState() => _TeacherPanelContentState();
}

class _TeacherPanelContentState extends State<TeacherPanelContent> {
  int selectedIndex = 0;

  // Subpage navigation state
  // subPage: "attendance" (daily attendance marking), "calendar" (student attendance history), "summary" (attendance statistics)
  String? subPage;
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

  void _showSummaryPage(int sectionId, String sectionName) {
    setState(() {
      subPage = "summary";
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
      // section info should be retained
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

  Widget _getContentForIndex(int index) {
    // Subpages first
    if (subPage == "attendance" &&
        selectedSectionId != null &&
        selectedSectionName != null) {
      return TeacherSectionAttendancePage(
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName!,
        onBack: _goBackToClassList,
      );
    }
    if (subPage == "summary" &&
        selectedSectionId != null &&
        selectedSectionName != null) {
      return TeacherSectionAttendanceSummaryPage(
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName!,
        onBack: _goBackToClassList,
        onViewStudentCalendar: _showStudentCalendarPage,
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
    // Main nav items
    switch (index) {
      case 0:
        return const TeacherDashboardPage();
      case 1:
        return TeacherClassListPage(
          onViewAttendance: _showAttendancePage,
          onViewSummary: _showSummaryPage,
        );
      case 2:
        // Management or other pages
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildNavItem(
                    _TeacherNavItem("Logout", Icons.logout),
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
}

class _TeacherNavItem {
  final String label;
  final IconData icon;
  _TeacherNavItem(this.label, this.icon);
}
