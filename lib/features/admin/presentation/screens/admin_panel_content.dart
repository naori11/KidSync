import 'package:flutter/material.dart';
import '../../../../screens/admin/student_management.dart';
import '../../../../screens/admin/user_management.dart';
import '../../../../screens/admin/parent_guardian.dart';
import '../../../../screens/admin/audit_logs.dart';
import '../../../../screens/admin/section_management.dart';
import '../../../../screens/admin/driver_assignment.dart';
import '../../../../screens/admin/bulk_import.dart';

class AdminPanelContent extends StatefulWidget {
  final String userName;
  const AdminPanelContent({Key? key, required this.userName}) : super(key: key);

  @override
  State<AdminPanelContent> createState() => _AdminPanelContentState();
}

class _AdminPanelContentState extends State<AdminPanelContent> {
  int selectedIndex = 0;
  late final List<_NavItem> navItems;

  @override
  void initState() {
    super.initState();
    navItems = [
      _NavItem("Dashboard", Icons.dashboard_outlined, const SizedBox()),
      _NavItem("Student Management", Icons.school_outlined, StudentManagementPage()),
      _NavItem("Section Management", Icons.class_outlined, SectionManagementPage()),
      _NavItem("User Management", Icons.person_outline, UserManagementPage()),
      _NavItem("Parent/Guardian", Icons.family_restroom, ParentGuardianPage()),
      _NavItem("Driver Assignment", Icons.drive_eta, DriverAssignmentPage()),
      _NavItem("Audit Logs", Icons.description_outlined, AuditLogsPage()),
      _NavItem("Bulk Import", Icons.upload_file, BulkImportPage()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF19AE61);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: primaryColor, size: 28),
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
      ),
      body: navItems[selectedIndex].page,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    widget.userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Administrator',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ...List.generate(navItems.length, (index) {
              final item = navItems[index];
              return ListTile(
                leading: Icon(item.icon, color: selectedIndex == index ? primaryColor : Colors.grey),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: selectedIndex == index ? primaryColor : Colors.black,
                    fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: selectedIndex == index,
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  _NavItem(this.label, this.icon, this.page);
}
