import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  String? guardId;
  String? guardName;
  String? profileImageUrl;
  bool isLoading = false;
  
  // Dashboard statistics
  int studentsCheckedIn = 0;
  int studentsCheckedOut = 0;
  int pendingPickups = 0;
  
  // Recent activities
  List<Map<String, dynamic>> recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadGuardData();
    _loadDashboardData();
  }

  Future<void> _loadGuardData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    guardId = user?.id;

    if (guardId == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch guard's first and last name from the users table
    final guardData =
        await supabase
            .from('users')
            .select('fname, lname, profile_image_url')
            .eq('id', guardId!)
            .maybeSingle();

    guardName =
        guardData != null
            ? '${guardData['fname'] ?? ''} ${guardData['lname'] ?? ''}'.trim()
            : user?.email ?? 'Guard';

    profileImageUrl = guardData?['profile_image_url'];

    setState(() => isLoading = false);
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _loadTodayStats(),
      _loadRecentActivities(),
    ]);
  }

  Future<void> _loadTodayStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get check-ins (entry scans)
      final checkInsResponse = await supabase
          .from('scan_records')
          .select('id')
          .eq('action', 'entry')
          .gte('scan_time', startOfDay.toIso8601String())
          .lt('scan_time', endOfDay.toIso8601String());

      // Get check-outs (exit scans)
      final checkOutsResponse = await supabase
          .from('scan_records')
          .select('id')
          .eq('action', 'exit')
          .gte('scan_time', startOfDay.toIso8601String())
          .lt('scan_time', endOfDay.toIso8601String());

      // Calculate pending pickups (checked in but not checked out)
      final checkedInStudents = await supabase
          .from('scan_records')
          .select('student_id')
          .eq('action', 'entry')
          .gte('scan_time', startOfDay.toIso8601String())
          .lt('scan_time', endOfDay.toIso8601String());

      final checkedOutStudents = await supabase
          .from('scan_records')
          .select('student_id')
          .eq('action', 'exit')
          .gte('scan_time', startOfDay.toIso8601String())
          .lt('scan_time', endOfDay.toIso8601String());

      final checkedInIds = (checkedInStudents as List)
          .map((e) => e['student_id'])
          .toSet();
      final checkedOutIds = (checkedOutStudents as List)
          .map((e) => e['student_id'])
          .toSet();
      final pending = checkedInIds.difference(checkedOutIds).length;

      setState(() {
        studentsCheckedIn = (checkInsResponse as List).length;
        studentsCheckedOut = (checkOutsResponse as List).length;
        pendingPickups = pending;
      });
    } catch (e) {
      print('Error loading today stats: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final response = await supabase
          .from('scan_records')
          .select('''
            id,
            student_id,
            action,
            scan_time,
            verified_by,
            notes,
            students!inner(fname, lname)
          ''')
          .order('scan_time', ascending: false)
          .limit(10);

      setState(() {
        recentActivities = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading recent activities: $e');
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
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 23,
            backgroundImage:
                profileImageUrl != null && profileImageUrl!.isNotEmpty
                    ? NetworkImage(profileImageUrl!)
                    : null,
            child:
                profileImageUrl == null || profileImageUrl!.isEmpty
                    ? Text(
                      (guardName != null && guardName!.isNotEmpty)
                          ? guardName![0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Color(0xFF2563EB),
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Good day, ${guardName ?? 'Guard'}!",
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildDashboardHeader(),
          const SizedBox(height: 24),

          // Expanded wrapper to make content non-scrollable
          Expanded(
            child: Column(
              children: [
                // Stats Overview
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
                      Text(
                        "Today's Summary",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary stats
                      Row(
                        children: [
                          _statCard(
                            "Students Checked In",
                            studentsCheckedIn.toString(),
                            Icons.login,
                            Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _statCard(
                            "Students Checked Out",
                            studentsCheckedOut.toString(),
                            Icons.logout,
                            Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _statCard(
                            "Pending Pickups",
                            pendingPickups.toString(),
                            Icons.people_outline,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Activities - wrapped in Expanded to fill remaining space
                Expanded(
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
                          "Recent Activities",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Activity list - wrapped in Expanded to make it scrollable if needed
                        Expanded(
                          child: recentActivities.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No recent activities',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < recentActivities.length; i++) ...[
                                        _buildActivityItem(recentActivities[i]),
                                        if (i < recentActivities.length - 1) _divider(),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for stat cards in dashboard
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
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
            Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // Build activity item from database record
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final student = activity['students'];
    final studentName = student != null
        ? '${student['fname'] ?? ''} ${student['lname'] ?? ''}'.trim()
        : 'Unknown Student';
    
    final action = activity['action'] ?? '';
    final scanTime = activity['scan_time'] != null
        ? DateTime.parse(activity['scan_time'])
        : DateTime.now();
    
    final timeStr = DateFormat('h:mm a').format(scanTime);
    
    // Determine icon and color based on action
    IconData icon;
    Color color;
    String actionText;
    
    if (action == 'entry') {
      icon = Icons.login;
      color = Colors.blue;
      actionText = 'Checked in by ${activity['verified_by'] ?? 'guardian'}';
    } else if (action == 'exit') {
      icon = Icons.logout;
      color = Colors.green;
      actionText = 'Checked out by ${activity['verified_by'] ?? 'guardian'}';
    } else {
      icon = Icons.info_outline;
      color = Colors.grey;
      actionText = activity['notes'] ?? 'Activity recorded';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  actionText,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Helper widget for activity items (legacy - kept for compatibility)
  Widget _activityItem(
    String name,
    String action,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  action,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Divider for list items
  Widget _divider() {
    return Divider(color: Colors.grey[200], height: 1);
  }
}
