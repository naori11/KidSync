import 'package:flutter/material.dart';
import 'student_management.dart';
import 'user_management.dart';
import 'parent_guardian.dart';
import 'audit_logs.dart';
import 'section_management.dart';
import 'driver_assignment.dart';
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
  String? profileImageUrl;
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
      _NavItem("Driver Assignment", Icons.drive_eta, DriverAssignmentPage()),
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
            .select('fname, lname, profile_image_url')
            .eq('id', adminId!)
            .maybeSingle();

    adminName =
        adminData != null
            ? '${adminData['fname'] ?? ''} ${adminData['lname'] ?? ''}'.trim()
            : user?.email ?? 'Admin';

    profileImageUrl = adminData?['profile_image_url'];

    if (adminId == null) {
      setState(() => isLoading = false);
      return;
    }
    setState(() => isLoading = false);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : (isTablet ? 20 : 24), 
            isMobile ? 12 : 16, 
            isMobile ? 16 : (isTablet ? 20 : 24), 
            isMobile ? 12 : 16
          ),
          margin: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                radius: isMobile ? 18 : 22,
                backgroundImage:
                    profileImageUrl != null && profileImageUrl!.isNotEmpty
                        ? NetworkImage(profileImageUrl!)
                        : null,
                child:
                    profileImageUrl == null || profileImageUrl!.isEmpty
                        ? Text(
                          (adminName != null && adminName!.isNotEmpty)
                              ? adminName![0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 16 : 20,
                            color: const Color(0xFF2563EB),
                          ),
                        )
                        : null,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Good day, ${adminName ?? 'Admin'}!",
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222B45),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: isMobile ? 12 : 14,
                          color: const Color(0xFF8F9BB3),
                        ),
                        SizedBox(width: isMobile ? 3 : 4),
                        Text(
                          getTodayLabel(),
                          style: TextStyle(
                            color: const Color(0xFF8F9BB3),
                            fontWeight: FontWeight.w400,
                            fontSize: isMobile ? 11 : 13,
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
      },
    );
  }

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1200;
        final isDesktop = constraints.maxWidth >= 1200;
        
        return Column(
          children: [
            // Profile greeting with top spacing
            Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 8 : (isTablet ? 12 : 16), // Left margin from sidebar
                isMobile ? 8 : 12, // Top margin
                isMobile ? 8 : (isTablet ? 12 : 16), // Right margin
                0, // No bottom margin
              ),
              child: _buildDashboardHeader(),
            ),
            
            // Scrollable content below
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : (isTablet ? 12 : 16)),
                child: Column(
                  children: [
                    // Quick Stats Row - Responsive
                    _buildResponsiveStatsGrid(isMobile, isTablet),

                    SizedBox(height: isMobile ? 16 : 24),

                    // Main Content - Responsive Layout
                    _buildResponsiveMainContent(isMobile, isTablet, isDesktop),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildResponsiveStatsGrid(bool isMobile, bool isTablet) {
    final stats = [
      {"title": "Total Students", "value": "243", "icon": Icons.people, "color": Colors.blue, "subtitle": "+12 this month"},
      {"title": "Total Users", "value": "156", "icon": Icons.person, "color": Colors.green, "subtitle": "+8 this month"},
      {"title": "Active Sections", "value": "18", "icon": Icons.class_, "color": Colors.orange, "subtitle": "2 new sections"},
      {"title": "Today's Attendance", "value": "92.6%", "icon": Icons.check_circle, "color": Colors.purple, "subtitle": "+0.2% from yesterday"},
    ];
    
    if (isMobile) {
      // Stack cards vertically on mobile
      return Column(
        children: stats.map((stat) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildQuickStatCard(
              stat["title"] as String,
              stat["value"] as String,
              stat["icon"] as IconData,
              stat["color"] as Color,
              stat["subtitle"] as String,
            ),
          ),
        ).toList(),
      );
    } else if (isTablet) {
      // 2x2 grid on tablet
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  stats[0]["title"] as String,
                  stats[0]["value"] as String,
                  stats[0]["icon"] as IconData,
                  stats[0]["color"] as Color,
                  stats[0]["subtitle"] as String,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  stats[1]["title"] as String,
                  stats[1]["value"] as String,
                  stats[1]["icon"] as IconData,
                  stats[1]["color"] as Color,
                  stats[1]["subtitle"] as String,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  stats[2]["title"] as String,
                  stats[2]["value"] as String,
                  stats[2]["icon"] as IconData,
                  stats[2]["color"] as Color,
                  stats[2]["subtitle"] as String,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  stats[3]["title"] as String,
                  stats[3]["value"] as String,
                  stats[3]["icon"] as IconData,
                  stats[3]["color"] as Color,
                  stats[3]["subtitle"] as String,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Single row on desktop
      return Row(
        children: stats.map((stat) => 
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildQuickStatCard(
                stat["title"] as String,
                stat["value"] as String,
                stat["icon"] as IconData,
                stat["color"] as Color,
                stat["subtitle"] as String,
              ),
            ),
          ),
        ).toList(),
      );
    }
  }
  
  Widget _buildResponsiveMainContent(bool isMobile, bool isTablet, bool isDesktop) {
    final systemOverview = Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Overview",
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
          _overviewItem("Active Students", 96, Colors.blue),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Present Today", 86, Colors.green),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Absent Today", 14, Colors.orange),
          SizedBox(height: isMobile ? 8 : (isTablet ? 12 : 16)),
          _overviewItem("Late Students", 24, Colors.red),
        ],
      ),
    );
    
    final recentActivity = Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : (isTablet ? 16 : 20)),
          _buildActivityItem(
            "New student enrolled",
            "2 minutes ago",
            Icons.person_add,
            Colors.green,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          _buildActivityItem(
            "Attendance marked",
            "15 minutes ago",
            Icons.check_circle,
            Colors.blue,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          _buildActivityItem(
            "Section updated",
            "1 hour ago",
            Icons.edit,
            Colors.orange,
          ),
        ],
      ),
    );
    
    if (isMobile || isTablet) {
      // Stack vertically on mobile and tablet
      return Column(
        children: [
          systemOverview,
          SizedBox(height: isMobile ? 16 : 24),
          recentActivity,
        ],
      );
    } else {
      // Side by side on desktop
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: systemOverview),
          const SizedBox(width: 24),
          Expanded(child: recentActivity),
        ],
      );
    }
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

  // Quick stat card for dashboard summary
  Widget _buildQuickStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Attendance stat item
  Widget _buildAttendanceStat(
    String label,
    String value,
    String change,
    Color changeColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: changeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                change,
                style: TextStyle(
                  fontSize: 11,
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Grade distribution widget
  Widget _buildGradeDistribution() {
    final grades = [
      {"name": "Preschool", "count": 42, "color": Colors.blue},
      {"name": "Kindergarten", "count": 56, "color": Colors.green},
      {"name": "Grade 1", "count": 48, "color": Colors.orange},
      {"name": "Grade 2", "count": 52, "color": Colors.purple},
      {"name": "Grade 3", "count": 45, "color": Colors.red},
    ];

    return Column(
      children:
          grades.map((grade) {
            final index = grades.indexOf(grade);
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: grade["color"] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        grade["name"] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      "${grade["count"]}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (index < grades.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Divider(color: Colors.grey[200], height: 1),
                  ),
              ],
            );
          }).toList(),
    );
  }

  // Activity item widget
  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
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
          final isTablet = constraints.maxWidth >= 768;
          final isMobile = constraints.maxWidth < 768;
          final isLargeScreen = constraints.maxWidth >= 1200;
          
          return Row(
            children: [
              // Sidebar Navigation
              LayoutBuilder(
                builder: (context, sidebarConstraints) {
                  double sidebarWidth;
                  if (isMobile) {
                    sidebarWidth = constraints.maxWidth * 0.25; // 25% on mobile
                    sidebarWidth = sidebarWidth.clamp(60.0, 120.0);
                  } else if (isTablet) {
                    sidebarWidth = constraints.maxWidth * 0.2; // 20% on tablet
                    sidebarWidth = sidebarWidth.clamp(150.0, 200.0);
                  } else {
                    sidebarWidth = constraints.maxWidth * 0.15; // 15% on desktop
                    sidebarWidth = sidebarWidth.clamp(180.0, 250.0);
                  }
                  
                  return Container(
                    width: sidebarWidth,
                    color: const Color.fromARGB(255, 255, 255, 255),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App title
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
                                      SizedBox(height: isMobile ? 8 : 16),
                                      _buildNavItem(item, index, isMobile),
                                    ],
                                  );
                                }
                                return _buildNavItem(item, index, isMobile);
                              },
                            ),
                          ),
                          // Logout button at the bottom
                          Padding(
                            padding: EdgeInsets.only(bottom: isMobile ? 12.0 : 24.0),
                            child: _buildNavItem(
                              _NavItem("Logout", Icons.logout, null),
                              navItems.length,
                              isMobile,
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

  Widget _buildNavItem(_NavItem item, int index, bool isMobile) {
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
        child: isMobile
            ? Icon(
                item.icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 18,
              )
            : Row(
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
