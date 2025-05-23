import 'package:flutter/material.dart';
import 'student_management.dart'; // adjust path as needed
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;
final userName = user?.userMetadata?['full_name'] ?? 'User';

// Dummy Analytics Data Model
class AnalyticsData {
  final int totalStudents;
  final int studentsPickedUpToday;
  final int totalGuardians;
  final int attendanceToday;
  final int auditLogEvents;

  AnalyticsData({
    required this.totalStudents,
    required this.studentsPickedUpToday,
    required this.totalGuardians,
    required this.attendanceToday,
    required this.auditLogEvents,
  });
}

class AdminPanelContent extends StatefulWidget {
  final String userName;

  const AdminPanelContent({super.key, required this.userName});

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
      _NavItem("Dashboard", Icons.dashboard, const SizedBox()), // Placeholder
      _NavItem(
        "Student Management",
        Icons.person_outline,
        StudentManagementPage(),
      ),
      _NavItem(
        "User Management",
        Icons.supervised_user_circle_outlined,
        Container(child: Text("User Management Page")),
      ),
      _NavItem(
        "Parent/Guardian",
        Icons.directions_car_outlined,
        Container(child: Text("Parent/Guardian Page")),
      ),
      _NavItem(
        "Attendance",
        Icons.calendar_today_outlined,
        Container(child: Text("Attendance Page")),
      ),
      _NavItem(
        "Audit Logs",
        Icons.access_time,
        Container(child: Text("Audit Logs Page")),
      ),
      _NavItem("Logout", Icons.logout, Container(child: Text("Logout Page"))),
    ];
  }

  Widget _buildDashboard() {
    final analytics = AnalyticsData(
      totalStudents: 320,
      studentsPickedUpToday: 290,
      totalGuardians: 215,
      attendanceToday: 303,
      auditLogEvents: 48,
    );

    return ListView(
      children: [
        Text(
          "Admin Dashboard",
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Spacer(),
        Row(
          children: [
            Icon(
              Icons.account_circle_rounded,
              size: 30,
              color: Colors.grey[700],
            ),
            SizedBox(width: 8),
            Text(
              widget.userName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _AnalyticsCard(
              title: "Total Students",
              value: analytics.totalStudents.toString(),
              icon: Icons.school,
              color: Colors.blue,
            ),
            _AnalyticsCard(
              title: "Picked Up Today",
              value: analytics.studentsPickedUpToday.toString(),
              icon: Icons.directions_walk,
              color: Colors.green,
            ),
            _AnalyticsCard(
              title: "Total Guardians",
              value: analytics.totalGuardians.toString(),
              icon: Icons.people_outline,
              color: Colors.teal,
            ),
            _AnalyticsCard(
              title: "Attendance Today",
              value: analytics.attendanceToday.toString(),
              icon: Icons.event_available_outlined,
              color: Colors.orange,
            ),
            _AnalyticsCard(
              title: "Audit Log Events",
              value: analytics.auditLogEvents.toString(),
              icon: Icons.access_time,
              color: Colors.grey,
            ),
          ],
        ),
        SizedBox(height: 32),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            height: 280,
            alignment: Alignment.center,
            child: Text(
              "Analytics Charts/Graphs Here",
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 240,
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(height: 40),
                ...List.generate(navItems.length, (index) {
                  return _NavTile(
                    item: navItems[index],
                    isSelected: selectedIndex == index,
                    onTap: () => setState(() => selectedIndex = index),
                  );
                }),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child:
                  selectedIndex == 0
                      ? _buildDashboard()
                      : navItems[selectedIndex].page,
            ),
          ),
        ],
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

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12),
      child: Material(
        color: isSelected ? Color(0xFF1BC47D) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? Colors.black : Colors.grey[800],
                  size: 22,
                ),
                SizedBox(width: 16),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.black : Colors.grey[800],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Analytics summary card
class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 220,
        height: 110,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
