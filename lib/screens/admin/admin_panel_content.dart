import 'package:flutter/material.dart';
import 'student_management.dart';
import 'user_management.dart';
import 'parent_guardian.dart';
import 'audit_logs.dart';
import 'section_management.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanelContent extends StatefulWidget {
  final String userName;

  const AdminPanelContent({super.key, required this.userName});

  @override
  State<AdminPanelContent> createState() => _AdminPanelContentState();
}

class _AdminPanelContentState extends State<AdminPanelContent> {
  final supabase = Supabase.instance.client;
  String? adminId;
  String? adminName;
  bool isLoading = false;

  int selectedIndex = 0;
  late final List<_NavItem> navItems;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    navItems = [
      _NavItem("Dashboard", Icons.dashboard_outlined, const SizedBox()),
      _NavItem(
        "Section Management",
        Icons.list_alt_outlined,
        const SectionManagementPage(),
      ),
      _NavItem(
        "Student Management",
        Icons.people_outline,
        StudentManagementPage(),
      ),
      _NavItem("User Management", Icons.person_outline, UserManagementPage()),
      _NavItem("Parent/Guardian", Icons.family_restroom, ParentGuardianPage()),
      _NavItem("Audit Logs", Icons.description_outlined, AuditLogsPage()),
    ];
  }

  Future<void> _loadAdminData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    adminId = user?.id;
    // Fetch admin's first and last name from the users table
    final adminData =
        await supabase
            .from('users')
            .select('fname, lname')
            .eq('id', adminId!)
            .maybeSingle();

    adminName =
        adminData != null
            ? '${adminData['fname'] ?? ''} ${adminData['lname'] ?? ''}'.trim()
            : user?.email ?? 'Admin';

    if (adminId == null) {
      setState(() => isLoading = false);
      return;
    }
  }

  // Function to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      // Navigate to login screen or home screen after logout
      if (context.mounted) {
        // Replace this with your login route navigation
        Navigator.of(context).pushReplacementNamed('/login');

        // Alternatively, you can use Navigator.pushAndRemoveUntil to clear the navigation stack
        // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  String getTodayLabel() {
    final now = DateTime.now();
    final date =
        "${["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][now.weekday - 1]}, "
        "${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.month - 1]} ${now.day}";
    return date;
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 23,
            child: Text(
              (adminName != null && adminName!.isNotEmpty)
                  ? adminName![0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Good day, ${adminName ?? 'Admin'}!",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF8F9BB3),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      getTodayLabel(),
                      style: const TextStyle(
                        color: Color(0xFF8F9BB3),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add the header here
          _buildDashboardHeader(),
          const SizedBox(height: 24),

          // Expanded wrapper to take remaining space
          Expanded(
            child: Column(
              children: [
                // Monthly Attendance Stats with Line Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Monthly Attendance Stats for November 2023",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          // Tab buttons for Today, Weekly, Monthly
                          Row(
                            children: [
                              _periodButton("Today", false),
                              const SizedBox(width: 8),
                              _periodButton("Weekly", false),
                              const SizedBox(width: 8),
                              _periodButton("Monthly", true),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Line Chart - This is a placeholder for the actual chart
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomPaint(
                          size: const Size(double.infinity, 180),
                          painter: LineChartPainter(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Attendance Stats Comparison
                      Row(
                        children: [
                          // This Month Stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "This Month",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "92.6%",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_upward,
                                            size: 12,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "0.2%",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Previous Month Stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Previous Month",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  "89.4%",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Two Column Layout for Grades and Overview - wrapped in Expanded
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Students by Grade
                      Expanded(
                        flex: 7,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Students according to grades",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Grade List
                              _gradeListItem("Preschool", 42),
                              _divider(),
                              _gradeListItem("Kindergarten", 56),
                              _divider(),
                              _gradeListItem("Grade 1", 48),
                              _divider(),
                              _gradeListItem("Grade 2", 52),
                              _divider(),
                              _gradeListItem("Grade 3", 45),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Right Column - Overview Stats
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Overview",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Overview Stats with Progress Bars
                              _overviewItem("Active Students", 96, Colors.blue),
                              const SizedBox(height: 16),
                              _overviewItem("Present Today", 86, Colors.green),
                              const SizedBox(height: 16),
                              _overviewItem("Absent Today", 65, Colors.orange),
                              const SizedBox(height: 16),
                              _overviewItem("Late Students", 24, Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for period buttons (Today, Weekly, Monthly)
  Widget _periodButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }

  // Helper widget for grade list items
  Widget _gradeListItem(String grade, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(grade, style: TextStyle(fontSize: 15, color: Colors.black87)),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Divider for grade list
  Widget _divider() {
    return Divider(color: Colors.grey[200], height: 1);
  }

  // Helper widget for overview items with progress bar
  Widget _overviewItem(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: Colors.black87)),
            Text(
              "$percentage%",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // Sidebar Navigation
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width:
                        constraints.maxWidth < 400
                            ? 80
                            : 180, // Responsive width
                    color: const Color.fromARGB(255, 255, 255, 255),
                    child: SafeArea(
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
                              shrinkWrap: true,
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
                          // Logout button at the bottom
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: _buildNavItem(
                              _NavItem("Logout", Icons.logout, null),
                              navItems.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Main Content
              Expanded(
                child:
                    selectedIndex == 0
                        ? _buildDashboard()
                        : navItems[selectedIndex].page ?? const SizedBox(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () async {
        // If it's the logout button
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
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget? page; // Changed to nullable

  _NavItem(this.label, this.icon, this.page);
}

// Custom painter for the line chart
class LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Chart area
    final double chartWidth = size.width;
    final double chartHeight = size.height * 0.8;
    final double bottomPadding = size.height * 0.2;

    // Define months for x-axis
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Define point coordinates for the line graph (sample wave pattern)
    final List<double> points = [7, 14, 21, 14, 21, 14, 28, 21, 14, 7, 14, 7];

    // Draw horizontal lines (grid)
    Paint gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight / 4 * i);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Draw x-axis labels (months)
    TextStyle labelStyle = TextStyle(color: Colors.grey[600], fontSize: 10);

    for (int i = 0; i < months.length; i++) {
      final textSpan = TextSpan(text: months[i], style: labelStyle);

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final x =
          (chartWidth / (months.length - 1) * i) - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(x, chartHeight + 10));
    }

    // Draw the line graph
    Paint linePaint =
        Paint()
          ..color = const Color(0xFF2ECC71)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    Path path = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (chartWidth / (points.length - 1) * i);
      final y =
          chartHeight -
          (chartHeight / 28 * points[i]); // Assuming max value is 28

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
