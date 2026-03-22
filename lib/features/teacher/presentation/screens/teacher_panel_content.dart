import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../widgets/in_app_notification_widget.dart';
import '../../../../services/notification_service.dart';
import '../../../../screens/teacher/teacher_dashboard_page.dart';
import '../../../../screens/teacher/class_list_page.dart';
import '../../../../screens/teacher/attendance_taking_page.dart';
import '../../../../screens/teacher/student_attendance_calendar_page.dart';
import '../../../../screens/teacher/section_attendance_summary_page.dart';

class TeacherPanelContent extends ConsumerStatefulWidget {
  final String userName;
  const TeacherPanelContent({Key? key, required this.userName}) : super(key: key);

  @override
  ConsumerState<TeacherPanelContent> createState() => _TeacherPanelContentState();
}

class _TeacherPanelContentState extends ConsumerState<TeacherPanelContent> {
  int selectedIndex = 0;
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
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initializePushNotifications();
      debugPrint('✅ Notifications initialized for teacher');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
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
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF19AE61);

    if (subPage == "attendance" && selectedSectionId != null) {
      return TeacherSectionAttendancePage(
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName ?? '',
        onBack: _goBackToClassList,
      );
    }

    if (subPage == "summary" && selectedSectionId != null) {
      return TeacherSectionAttendanceSummaryPage(
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName ?? '',
        onBack: _goBackToClassList,
        onViewStudentCalendar: _showStudentCalendarPage,
      );
    }

    if (subPage == "calendar" && selectedStudentId != null) {
      return TeacherStudentAttendanceCalendarPage(
        studentId: selectedStudentId!,
        studentName: selectedStudentName ?? '',
        sectionId: selectedSectionId!,
        sectionName: selectedSectionName ?? '',
        onBack: _goBackToClassList,
      );
    }

    return InAppNotificationWidget(
      userRole: 'teacher',
      primaryColor: primaryColor,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(10, 78, 241, 157),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          title: Row(
            children: [
              const Icon(Icons.school, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Text(
                navItems[selectedIndex].label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        body: _buildContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
              subPage = null;
              selectedSectionId = null;
              selectedSectionName = null;
            });
          },
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          items: navItems
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedIndex) {
      case 0:
        return TeacherDashboardPage(
          onOpenClassList: () => setState(() => selectedIndex = 1),
          onOpenAttendance: _showAttendancePage,
        );
      case 1:
        return TeacherClassListPage(
          onViewAttendance: _showAttendancePage,
          onViewSummary: _showSummaryPage,
        );
      default:
        return const Center(child: Text('Unknown page'));
    }
  }
}

class _TeacherNavItem {
  final String label;
  final IconData icon;
  _TeacherNavItem(this.label, this.icon);
}
