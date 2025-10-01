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

  List<Activity> activities = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentActivities();
  }

  // Fetch recent activities from scan_records
  Future<void> _fetchRecentActivities() async {
    try {
      // Filtering by time period (today/this week/this month)
      DateTime now = DateTime.now();
      DateTime start;
      DateTime end;
      switch (selectedTimePeriod) {
        case 'Today':
          start = DateTime(now.year, now.month, now.day);
          end = start.add(Duration(days: 1));
          break;
        case 'This Week':
          start = now.subtract(Duration(days: now.weekday - 1)); // Monday
          start = DateTime(start.year, start.month, start.day);
          end = start.add(Duration(days: 7));
          break;
        case 'This Month':
          start = DateTime(now.year, now.month, 1);
          end =
              (now.month < 12)
                  ? DateTime(now.year, now.month + 1, 1)
                  : DateTime(now.year + 1, 1, 1);
        default:
          start = DateTime(now.year, now.month, now.day);
          end = start.add(Duration(days: 1));
      }

      final response = await supabase
          .from('scan_records')
          .select('''
        scan_time, action, verified_by, status, notes,
        students(id, fname, mname, lname, grade_level, section_id)
      ''')
          .gte('scan_time', start.toIso8601String())
          .lt('scan_time', end.toIso8601String())
          .order('scan_time', ascending: false)
          .limit(50);

      List<Activity> fetched = [];
      for (var record in response) {
        final student = record['students'];
        final scanTime = DateTime.parse(record['scan_time']);
        final gradeClass =
            student != null
                ? (student['grade_level']?.toString() ?? "") +
                    (student['section_id'] != null
                        ? " - Section ${student['section_id']}"
                        : "")
                : "";

        String statusMessage;
        final action = (record['action'] ?? '').toString().toLowerCase();

        if (action == 'entry') {
          statusMessage = "Entry Recorded";
        } else if (action == 'approved') {
          statusMessage = "Pickup Approved";
        } else if (action == 'denied') {
          statusMessage = "Pickup Denied";
        } else if (action == 'checked out') {
          statusMessage = "Checked Out";
        } else {
          statusMessage = "Activity";
        }

        final reason = record['notes'] ?? '';

        final hour = scanTime.hour == 0 ? 12 : (scanTime.hour > 12 ? scanTime.hour - 12 : scanTime.hour);
        final period = scanTime.hour >= 12 ? 'PM' : 'AM';
        fetched.add(
          Activity(
            time:
                "${hour.toString()}:${scanTime.minute.toString().padLeft(2, '0')} $period",
            studentName:
                student != null
                    ? "${student['fname']} ${student['mname'] ?? ''} ${student['lname']}"
                    : "Unknown",
            gradeClass: gradeClass,
            status: statusMessage,
            reason: reason,
            timestamp: scanTime,
            verifiedBy: record['verified_by'] ?? '',
            action: record['action'] ?? '',
          ),
        );
      }
      setState(() {
        activities = fetched;
      });
    } catch (e) {
      print('Error fetching activities: $e');
    }
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
            _fetchRecentActivities();
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
            builder: (context) => AlertDialog(
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
          isMobile ? 2 : 4
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16, 
          vertical: isMobile ? 8 : 12
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue.withOpacity(0.3)) : null,
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                    color: Colors.white,
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
                        Padding(
                          padding: EdgeInsets.only(bottom: isMobile ? 12.0 : 24.0),
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

              // Main Content
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
