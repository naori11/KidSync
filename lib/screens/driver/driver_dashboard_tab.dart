import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/driver_models.dart';
import '../../services/driver_service.dart';

class DriverDashboardTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverDashboardTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  final supabase = Supabase.instance.client;
  final DriverService _driverService = DriverService();

  bool isDashboardLoading = true;
  Timer? _refreshTimer;

  // Real-time data
  Map<String, dynamic> todaysTasksData = {};
  List<Map<String, dynamic>> recentActivity = [];
  List<DriverAssignment> assignedStudents = [];
  Map<String, int> taskStats = {
    'completed_pickups': 0,
    'completed_dropoffs': 0,
    'pending_pickups': 0,
    'pending_dropoffs': 0,
    'total_students': 0,
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => isDashboardLoading = true);

    try {
      await _loadAllData();
      _setupPeriodicRefresh();
    } catch (e) {
      print('Error initializing driver dashboard data: $e');
    } finally {
      setState(() => isDashboardLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final driverId = user.id;

    // Load all data concurrently
    final results = await Future.wait([
      _loadTodaysTasksData(driverId),
      _loadRecentActivity(driverId),
      _loadAssignedStudents(driverId),
      _loadTaskStats(driverId),
    ]);

    setState(() {
      todaysTasksData = results[0] as Map<String, dynamic>;
      recentActivity = results[1] as List<Map<String, dynamic>>;
      assignedStudents = results[2] as List<DriverAssignment>;
      taskStats = results[3] as Map<String, int>;
    });
  }

  void _setupPeriodicRefresh() {
    _refreshTimer?.cancel(); // Cancel existing timer first
    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        // Check if widget is still mounted
        _refreshData();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _refreshData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final driverId = user.id;

      // Refresh real-time data
      final newTodaysTasksData = await _loadTodaysTasksData(driverId);
      final newRecentActivity = await _loadRecentActivity(driverId);
      final newTaskStats = await _loadTaskStats(driverId);

      setState(() {
        todaysTasksData = newTodaysTasksData;
        recentActivity = newRecentActivity;
        taskStats = newTaskStats;
      });
    } catch (e) {
      print('Error refreshing driver dashboard data: $e');
    }
  }

  Future<Map<String, dynamic>> _loadTodaysTasksData(String driverId) async {
    try {
      final tasksData = await _driverService.getTodaysStudentsWithPatterns(
        driverId,
      );
      return tasksData;
    } catch (e) {
      print('Error loading today\'s tasks: $e');
      return {
        'all_students': [],
        'morning_pickup': [],
        'afternoon_dropoff': [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity(
    String driverId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('''
            id,
            event_type,
            pickup_time,
            dropoff_time,
            notes,
            created_at,
            students!inner(fname, lname)
          ''')
          .eq('driver_id', driverId)
          .gte('created_at', startOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5);

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading recent activity: $e');
      return [];
    }
  }

  Future<List<DriverAssignment>> _loadAssignedStudents(String driverId) async {
    try {
      return await _driverService.getDriverAssignments(driverId);
    } catch (e) {
      print('Error loading assigned students: $e');
      return [];
    }
  }

  Future<Map<String, int>> _loadTaskStats(String driverId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return _getEmptyTaskStats();
      }

      // Add null safety checks
      final todaysData = this.todaysTasksData;
      final assignedStudents = this.assignedStudents;

      if (todaysData.isEmpty) {
        return _getEmptyTaskStats();
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get today's completed tasks
      final completedResponse = await supabase
          .from('pickup_dropoff_logs')
          .select('event_type')
          .eq('driver_id', driverId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      int completedPickups = 0;
      int completedDropoffs = 0;

      for (final log in completedResponse) {
        if (log['event_type'] == 'pickup') completedPickups++;
        if (log['event_type'] == 'dropoff') completedDropoffs++;
      }

      // Get today's scheduled tasks
      final morningTasks = todaysData['morning_pickup'] as List? ?? [];
      final afternoonTasks = todaysData['afternoon_dropoff'] as List? ?? [];

      final pendingPickups = morningTasks.length - completedPickups;
      final pendingDropoffs = afternoonTasks.length - completedDropoffs;
      final totalStudents = assignedStudents.length;

      return {
        'completed_pickups': completedPickups,
        'completed_dropoffs': completedDropoffs,
        'pending_pickups': pendingPickups > 0 ? pendingPickups : 0,
        'pending_dropoffs': pendingDropoffs > 0 ? pendingDropoffs : 0,
        'total_students': totalStudents,
      };
    } catch (e) {
      print('Error loading task stats: $e');
      return _getEmptyTaskStats();
    }
  }

  Map<String, int> _getEmptyTaskStats() {
    return {
      'completed_pickups': 0,
      'completed_dropoffs': 0,
      'pending_pickups': 0,
      'pending_dropoffs': 0,
      'total_students': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    // No local colors needed at this scope

    if (isDashboardLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Today's Tasks Card - REAL-TIME STATUS
          _buildTodaysTasksCard(widget.primaryColor, widget.isMobile),
          SizedBox(height: widget.isMobile ? 10 : 14),

          // 2. Task Status Card - PROGRESS OVERVIEW
          _buildTaskStatusCard(widget.primaryColor, widget.isMobile),
          SizedBox(height: widget.isMobile ? 10 : 14),

          // 3. Recent Activity Card - moved to its own page
          const SizedBox.shrink(),
          SizedBox(height: widget.isMobile ? 10 : 14),

          // Assigned Students section removed per request
        ],
      ),
    );
  }

  Widget _buildTodaysTasksCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    final morningTasks = todaysTasksData['morning_pickup'] as List? ?? [];
    final afternoonTasks = todaysTasksData['afternoon_dropoff'] as List? ?? [];
    final hasAnyTasks = morningTasks.isNotEmpty || afternoonTasks.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.today,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Today\'s Tasks',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                if (!hasAnyTasks)
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_busy,
                          color: Colors.grey[600],
                          size: isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No tasks scheduled for today',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 15,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (morningTasks.isNotEmpty) ...[
                    _buildTaskSection(
                      'Morning Pickup Tasks',
                      morningTasks,
                      Icons.school,
                      primaryColor,
                      black,
                      isMobile,
                    ),
                    if (afternoonTasks.isNotEmpty)
                      SizedBox(height: isMobile ? 12 : 16),
                  ],
                  if (afternoonTasks.isNotEmpty)
                    _buildTaskSection(
                      'Afternoon Dropoff Tasks',
                      afternoonTasks,
                      Icons.home,
                      primaryColor,
                      black,
                      isMobile,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSection(
    String title,
    List<dynamic> tasks,
    IconData icon,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor, size: isMobile ? 16 : 18),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : 16,
                color: black,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ...tasks.map((task) {
          final student = task['students'];
          final studentName = '${student['fname']} ${student['lname']}';
          final time = task['pickup_time'] ?? task['dropoff_time'] ?? 'N/A';
          final address = task['pickup_address'] ?? student['address'] ?? 'N/A';

          final profileImage =
              (student != null &&
                      student['profile_image_url'] != null &&
                      student['profile_image_url'].toString().isNotEmpty)
                  ? NetworkImage(student['profile_image_url'].toString())
                  : null;

          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  radius: isMobile ? 16 : 20,
                  backgroundImage: profileImage,
                  child:
                      profileImage == null
                          ? Icon(
                            Icons.person,
                            color: primaryColor,
                            size: isMobile ? 16 : 20,
                          )
                          : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 14 : 16,
                          color: black,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Time: $time',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        'Address: $address',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: black.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTaskStatusCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.assignment_turned_in,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Task Status Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Completed\nPickups',
                        taskStats['completed_pickups'].toString(),
                        Icons.check_circle,
                        Colors.green,
                        isMobile,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Pending\nPickups',
                        taskStats['pending_pickups'].toString(),
                        Icons.schedule,
                        Colors.orange,
                        isMobile,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Completed\nDropoffs',
                        taskStats['completed_dropoffs'].toString(),
                        Icons.check_circle,
                        Colors.green,
                        isMobile,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Pending\nDropoffs',
                        taskStats['pending_dropoffs'].toString(),
                        Icons.schedule,
                        Colors.orange,
                        isMobile,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  child: _buildStatItem(
                    'Total Assigned Students',
                    taskStats['total_students'].toString(),
                    Icons.group,
                    primaryColor,
                    isMobile,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 24 : 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000000),
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: const Color(0xFF000000).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecentActivityCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.history,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                if (recentActivity.isEmpty)
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No recent activity. Pickup/dropoff logs will appear here.',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 15,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...recentActivity.map((activity) {
                    final eventType = activity['event_type'] ?? '';
                    final studentName =
                        '${activity['students']['fname']} ${activity['students']['lname']}';
                    final time =
                        activity['pickup_time'] ?? activity['dropoff_time'];
                    final formattedTime =
                        time != null
                            ? DateFormat('HH:mm').format(DateTime.parse(time))
                            : 'N/A';

                    IconData icon;
                    Color iconColor;
                    String actionText;

                    if (eventType == 'pickup') {
                      icon = Icons.school;
                      iconColor = Colors.blue;
                      actionText = 'Picked up';
                    } else {
                      icon = Icons.home;
                      iconColor = Colors.green;
                      actionText = 'Dropped off';
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: iconColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: iconColor,
                            size: isMobile ? 16 : 18,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$actionText $studentName',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 16,
                                    color: black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Time: $formattedTime',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                    color: black.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
