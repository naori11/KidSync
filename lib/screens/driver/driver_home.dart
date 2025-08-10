import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver_models.dart';
import '../../models/pickup_status.dart';
import 'package:intl/intl.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    final List<_NavItem> navItems = [
      _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
      _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
      _NavItem('Students', Icons.group, 'students'),
    ];
    return _DriverHomeTabs(
      navItems: navItems,
      primaryColor: primaryGreen,
      secondaryText: black.withOpacity(0.7),
      logout: _logout,
    );
  }
}

class _DriverHomeTabs extends StatefulWidget {
  final List<_NavItem> navItems;
  final Color primaryColor;
  final Color secondaryText;
  final Future<void> Function(BuildContext) logout;

  const _DriverHomeTabs({
    required this.navItems,
    required this.primaryColor,
    required this.secondaryText,
    required this.logout,
    Key? key,
  }) : super(key: key);

  @override
  State<_DriverHomeTabs> createState() => _DriverHomeTabsState();
}

class _DriverHomeTabsState extends State<_DriverHomeTabs> {
  int selectedIndex = 0;
  bool showNotifications = false;
  bool showProfile = false;

  void _toggleNotifications() {
    setState(() {
      showNotifications = !showNotifications;
      if (showNotifications) showProfile = false;
    });
  }

  void _toggleProfile() {
    setState(() {
      showProfile = !showProfile;
      if (showProfile) showNotifications = false;
    });
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: const Color(0xFF19AE61), size: 24),
              SizedBox(width: 8),
              Text(
                'Confirm Logout',
                style: TextStyle(
                  color: const Color(0xFF000000),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: const Color(0xFF000000).withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: const Color(0xFF000000).withOpacity(0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.logout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF19AE61),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                color: const Color(0xFFFFFFFF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(
                        Icons.local_shipping,
                        color: Color(0xFF19AE61),
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    // Notification Bell
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Color(0xFF000000),
                            size: 28,
                          ),
                          onPressed: _toggleNotifications,
                        ),
                        if (showNotifications)
                          Positioned(
                            right: 0,
                            top: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF19AE61),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _toggleProfile,
                      child: const CircleAvatar(
                        backgroundColor: Color.fromRGBO(25, 174, 97, 0.171),
                        radius: 16,
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF19AE61),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: _buildTabContent(selectedIndex, isMobile),
                  ),
                ),
              ),
              // Bottom Navigation Bar
              Container(
                color: const Color(0xFFFFFFFF),
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(widget.navItems.length, (i) {
                    final item = widget.navItems[i];
                    final bool selected = i == selectedIndex;
                    return IconButton(
                      icon: Icon(
                        item.icon,
                        color:
                            selected
                                ? widget.primaryColor
                                : widget.secondaryText,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() => selectedIndex = i);
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
          // Notifications Popover
          if (showNotifications)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _NotificationsTab(
                  primaryColor: widget.primaryColor,
                  isMobile: isMobile,
                ),
              ),
            ),
          // Profile Popover
          if (showProfile)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _ProfileTab(
                  logout: () => _showLogoutConfirmation(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index, bool isMobile) {
    switch (index) {
      case 0:
        return _DashboardTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 1:
        return _PickupDropoffTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      case 2:
        return _StudentsTab(
          primaryColor: widget.primaryColor,
          isMobile: isMobile,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DashboardTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _DashboardTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final monthlyTasks = StaticDriverData.monthlyTasks;
    final todaysTask = StaticDriverData.getTodaysTask();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Welcome, ${StaticDriverData.driverInfo.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vehicle: ${StaticDriverData.driverInfo.vehicleNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF000000).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Today's Task Section
          if (todaysTask != null) ...[
            Text(
              'Today\'s Pickup Task',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            const SizedBox(height: 12),
            _buildTaskCard(todaysTask, isToday: true),
            const SizedBox(height: 24),
          ],

          // Monthly Overview Section
          Text(
            'Monthly Pickup Tasks Overview',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 12),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Tasks',
                  monthlyTasks.length.toString(),
                  Icons.assignment,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Students',
                  monthlyTasks
                      .fold<int>(0, (sum, task) => sum + task.studentCount)
                      .toString(),
                  Icons.group,
                  primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Upcoming Tasks
          Text(
            'Upcoming Tasks',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(height: 12),

          // Task List
          ...monthlyTasks.map((task) => _buildTaskCard(task)).toList(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(PickupTask task, {bool isToday = false}) {
    return Card(
      elevation: isToday ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: primaryColor, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isToday) const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM dd, yyyy').format(task.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.pickupTime,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.school, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.schoolName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${task.studentCount} student${task.studentCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF000000).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Students:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    task.students
                        .map(
                          (student) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${student.name} (${student.grade})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupDropoffTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const _PickupDropoffTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<_PickupDropoffTab> createState() => _PickupDropoffTabState();
}

class _PickupDropoffTabState extends State<_PickupDropoffTab> {
  late PickupTask? todaysTask;
  List<Student> pickedUpStudents = [];

  @override
  void initState() {
    super.initState();
    todaysTask = StaticDriverData.getTodaysTask();
    // Load sample pickup status data for demonstration
    StaticPickupStatusStorage.loadSampleData();
  }

  void _toggleStudentPickup(Student student) {
    setState(() {
      if (pickedUpStudents.any((s) => s.id == student.id)) {
        // Remove student from picked up list
        pickedUpStudents.removeWhere((s) => s.id == student.id);
      } else {
        // Add student to picked up list with pickup time
        final pickupTime = DateTime.now();
        final updatedStudent = student.copyWith(
          isPickedUp: true,
          pickupTime: pickupTime,
          driverName: StaticDriverData.driverInfo.name,
        );
        pickedUpStudents.add(updatedStudent);

        // Create pickup status for parents (static)
        final pickupStatus = PickupStatus.fromPickup(
          studentId: student.id,
          studentName: student.name,
          pickupTime: pickupTime,
          driverName: StaticDriverData.driverInfo.name,
          vehicleNumber: StaticDriverData.driverInfo.vehicleNumber,
          schoolName: todaysTask!.schoolName,
        );

        // Store pickup status (this would normally be sent to backend/parents app)
        StaticPickupStatusStorage.addPickupStatus(pickupStatus);
      }
    });

    // Show confirmation snackbar
    final isPickedUp = pickedUpStudents.any((s) => s.id == student.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPickedUp
              ? '✓ ${student.name} marked as picked up - Parents notified'
              : '${student.name} pickup cancelled',
        ),
        backgroundColor: isPickedUp ? widget.primaryColor : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isStudentPickedUp(Student student) {
    return pickedUpStudents.any((s) => s.id == student.id);
  }

  @override
  Widget build(BuildContext context) {
    if (todaysTask == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: widget.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No pickup tasks scheduled for today',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back tomorrow or view all tasks in the Dashboard',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final completedCount = pickedUpStudents.length;
    final totalCount = todaysTask!.studentCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.1),
                    widget.primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY\'S TASK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          todaysTask!.pickupTime,
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.school, color: widget.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          todaysTask!.schoolName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF000000).withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.primaryColor,
                              ),
                              minHeight: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$completedCount / $totalCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Student List Header
          Row(
            children: [
              Text(
                'Students to Pick Up',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
              const Spacer(),
              if (completedCount == totalCount)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'COMPLETE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Tap on a student\'s name to mark them as picked up',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF000000).withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),

          // Student Cards
          ...todaysTask!.students.map((student) => _buildStudentCard(student)),

          const SizedBox(height: 24),

          // Action Buttons
          if (completedCount > 0) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Summary',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Students picked up: $completedCount',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                      ),
                    ),
                    Text(
                      'Time: ${DateFormat('h:mm a').format(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF000000).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (completedCount == totalCount)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Pickup task completed! Parents will be notified.',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Complete Pickup Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final isPickedUp = _isStudentPickedUp(student);
    final pickedUpStudent = pickedUpStudents.firstWhere(
      (s) => s.id == student.id,
      orElse: () => student,
    );

    return Card(
      elevation: isPickedUp ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _toggleStudentPickup(student),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                isPickedUp
                    ? Border.all(color: widget.primaryColor, width: 2)
                    : null,
            color: isPickedUp ? widget.primaryColor.withOpacity(0.05) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  isPickedUp
                                      ? widget.primaryColor
                                      : const Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isPickedUp)
                            Icon(
                              Icons.check_circle,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.grade,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF000000).withOpacity(0.7),
                        ),
                      ),
                      if (isPickedUp && pickedUpStudent.pickupTime != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Picked up at ${DateFormat('h:mm a').format(pickedUpStudent.pickupTime!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isPickedUp
                            ? widget.primaryColor
                            : Colors.grey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPickedUp ? Icons.check : Icons.person,
                    color: isPickedUp ? Colors.white : Colors.grey,
                    size: 20,
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

class _StudentsTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _StudentsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get all unique students from all tasks
    final allStudents = <String, Student>{};
    for (final task in StaticDriverData.monthlyTasks) {
      for (final student in task.students) {
        allStudents[student.id] = student;
      }
    }

    final studentList = allStudents.values.toList();
    studentList.sort((a, b) => a.name.compareTo(b.name));

    // Group students by grade
    final studentsByGrade = <String, List<Student>>{};
    for (final student in studentList) {
      studentsByGrade[student.grade] ??= [];
      studentsByGrade[student.grade]!.add(student);
    }

    final grades = studentsByGrade.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Student Directory',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All students assigned to your pickup routes',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF000000).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Students',
                  studentList.length.toString(),
                  Icons.group,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Grade Levels',
                  grades.length.toString(),
                  Icons.school,
                  primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Students by Grade
          ...grades.map(
            (grade) => _buildGradeSection(grade, studentsByGrade[grade]!),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSection(String grade, List<Student> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${students.length} student${students.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF000000).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        ...students.map((student) => _buildStudentCard(student)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStudentCard(Student student) {
    // Find which schools this student is picked up from
    final schools = <String>{};
    for (final task in StaticDriverData.monthlyTasks) {
      if (task.students.any((s) => s.id == student.id)) {
        schools.add(task.schoolName);
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Student Avatar
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              radius: 24,
              child: Text(
                student.name.split(' ').map((name) => name[0]).take(2).join(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Student Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.grade,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF000000).withOpacity(0.7),
                    ),
                  ),
                  if (schools.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          schools
                              .map(
                                (school) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    school,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Info Icon
            Icon(
              Icons.info_outline,
              color: primaryColor.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const _NotificationsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Text(
        'Notifications (empty)',
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final VoidCallback logout;

  const _ProfileTab({required this.logout, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color.fromRGBO(25, 174, 97, 0.171),
                radius: 20,
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF19AE61),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF19AE61),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(color: const Color(0xFF000000).withOpacity(0.1)),
          const SizedBox(height: 8),
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: logout,
              icon: Icon(
                Icons.logout,
                color: const Color(0xFF19AE61),
                size: 20,
              ),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: const Color(0xFF19AE61),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
              ),
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
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
