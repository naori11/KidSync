import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/parent_models.dart';
import '../../models/driver_models.dart';
import '../../services/notification_service.dart';

class ParentDashboardTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final int? selectedStudentId; // ADD THIS

  const ParentDashboardTab({
    required this.primaryColor,
    required this.isMobile,
    this.selectedStudentId, // ADD THIS
    Key? key,
  }) : super(key: key);

  @override
  State<ParentDashboardTab> createState() => _ParentDashboardTabState();
}

class _ParentDashboardTabState extends State<ParentDashboardTab> {
  List<AuthorizedFetcher> dashboardFetchers = [];
  bool isDashboardLoading = true;
  final supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  
  // Real-time data
  Map<String, dynamic>? driverInfo;
  Map<String, dynamic> todayStatus = {};
  List<Map<String, dynamic>> recentNotifications = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(ParentDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when selectedStudentId changes
    if (widget.selectedStudentId != oldWidget.selectedStudentId) {
      _refreshTimer?.cancel();
      _initializeData();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (widget.selectedStudentId == null) {
      setState(() => isDashboardLoading = false);
      return;
    }

    setState(() => isDashboardLoading = true);

    try {
      await _loadAllData();
      _setupPeriodicRefresh();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() => isDashboardLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    if (widget.selectedStudentId == null) return;

    final studentId = widget.selectedStudentId!;

    // Load all data concurrently
    final results = await Future.wait([
      _notificationService.getStudentDriver(studentId),
      _notificationService.getTodayStatus(studentId),
      _loadDashboardFetchers(),
      _loadRecentNotifications(),
    ]);

    setState(() {
      driverInfo = results[0] as Map<String, dynamic>?;
      todayStatus = results[1] as Map<String, dynamic>;
    });
  }

  Future<void> _loadRecentNotifications() async {
    if (widget.selectedStudentId == null) return;

    try {
      // Get current user (parent)
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get parent ID from user metadata or database
      final parentResponse = await supabase
          .from('parents')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (parentResponse != null) {
        final parentId = parentResponse['id'];
        // Get notifications for the selected student, today only
        final notifications = await _notificationService.getParentNotifications(
          parentId, 
          studentId: widget.selectedStudentId!,
          todayOnly: true,
          limit: 5,
        );
        setState(() {
          recentNotifications = notifications;
        });
      }
    } catch (e) {
      print('Error loading recent notifications: $e');
    }
  }

  void _setupPeriodicRefresh() {
    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (widget.selectedStudentId != null) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    if (widget.selectedStudentId == null) return;

    try {
      final studentId = widget.selectedStudentId!;
      
      // Refresh today's status and notifications
      final newTodayStatus = await _notificationService.getTodayStatus(studentId);
      await _loadRecentNotifications();
      
      setState(() {
        todayStatus = newTodayStatus;
      });
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<void> _loadDashboardFetchers() async {
    if (widget.selectedStudentId == null) {
      return;
    }

    try {
      // Use the provided student ID directly
      final fetchersResponse = await supabase
          .from('parent_student')
          .select('''
            relationship_type,
            is_primary,
            parents!inner(
              id, fname, mname, lname, phone, email, status, user_id,
              users!inner(
                profile_image_url, role
              )
            )
          ''')
          .eq('student_id', widget.selectedStudentId!)
          .eq('parents.status', 'active')
          .eq('parents.users.role', 'Parent')
          .limit(3);

      final List<AuthorizedFetcher> fetchers =
          fetchersResponse
              .map((data) => AuthorizedFetcher.fromJson(data))
              .toList();

      dashboardFetchers = fetchers;
    } catch (error) {
      print('Error loading dashboard fetchers: $error');
    }
  }

  Widget _fetcherRow(
    String name,
    String role,
    bool active,
    Color primaryColor, [
    bool isMobile = false,
    String? profileImageUrl, // Add this parameter
  ]) {
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(
        bottom: isMobile ? 6 : 8,
      ), // Add margin for spacing
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 10,
        horizontal: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: greenWithOpacity,
            radius: isMobile ? 16 : 20,
            backgroundImage:
                profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
            child:
                profileImageUrl == null || profileImageUrl.isEmpty
                    ? Icon(
                      Icons.person,
                      color: primaryColor,
                      size: isMobile ? 18 : 22,
                    )
                    : null,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 15,
                    color: black,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.circle,
            color: active ? primaryColor : black.withOpacity(0.3),
            size: isMobile ? 10 : 12,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    
    // Use real driver data or show loading/no driver state
    if (driverInfo == null) {
      return _buildNoDriverCard(primaryColor, isMobile);
    }
    
    final driver = driverInfo!['drivers'];
    final driverName = '${driver['fname']} ${driver['lname']}';
    final driverPhone = driver['phone'] ?? 'No phone';
    final profileImageUrl = driver['users']?['profile_image_url'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
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
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Your Driver',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: greenWithOpacity,
                        radius: isMobile ? 24 : 30,
                        backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null || profileImageUrl.isEmpty
                            ? Icon(
                                Icons.person,
                                color: primaryColor,
                                size: isMobile ? 24 : 30,
                              )
                            : null,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'License: ${driver['license_number'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  driverPhone,
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(Icons.phone, size: isMobile ? 16 : 18),
                        label: Text(
                          'Call Driver',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Calling $driverName...'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.message, size: isMobile ? 16 : 18),
                        label: Text(
                          'Message',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          final driverName = driverInfo?['drivers'] != null
                              ? '${driverInfo!['drivers']['fname']} ${driverInfo!['drivers']['lname']}'
                              : 'driver';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opening message to $driverName...',
                              ),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupSummaryCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
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
                      'Today\'s Pickup Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                ..._buildRealTimeSummaryItems(primaryColor, black, isMobile),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Real-time updates will appear here when your child is picked up',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: black.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDriverCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
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
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Driver Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        radius: isMobile ? 24 : 30,
                        child: Icon(
                          Icons.person_off,
                          color: Colors.grey,
                          size: isMobile ? 24 : 30,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Driver Assigned',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please contact school administration',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                                color: Colors.grey[500],
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
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRealTimeSummaryItems(Color primaryColor, Color black, bool isMobile) {
    final List<Widget> items = [];
    
    // Morning dropoff status
    final pickup = todayStatus['pickup'];
    if (pickup != null) {
      final pickupTime = pickup['pickup_time'];
      final driverName = pickup['drivers'] != null 
          ? '${pickup['drivers']['fname']} ${pickup['drivers']['lname']}'
          : 'Driver';
      
      items.add(_buildSummaryItem(
        Icons.school,
        'Morning Pickup',
        '${_formatTimeFromString(pickupTime)} - Picked up successfully',
        'Driver: $driverName confirmed pickup',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    }
    
    // Afternoon dropoff status
    final dropoff = todayStatus['dropoff'];
    if (dropoff != null) {
      final dropoffTime = dropoff['dropoff_time'];
      final driverName = dropoff['drivers'] != null 
          ? '${dropoff['drivers']['fname']} ${dropoff['drivers']['lname']}'
          : 'Driver';
      
      items.add(_buildSummaryItem(
        Icons.home,
        'Afternoon Dropoff',
        '${_formatTimeFromString(dropoffTime)} - Dropped off safely',
        'Driver: $driverName confirmed dropoff',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    }
    
    // Current status based on what's happened
    if (pickup != null && dropoff == null) {
      items.add(_buildSummaryItem(
        Icons.school,
        'Current Status',
        'At school - Waiting for pickup',
        'Student is currently at school',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    } else if (dropoff != null) {
      items.add(_buildSummaryItem(
        Icons.home,
        'Current Status',
        'At home - Day completed',
        'Student has been safely dropped off',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    } else {
      // No pickup yet - show scheduled time
      final scheduledPickupTime = driverInfo?['pickup_time'] ?? '8:00 AM';
      final driverName = driverInfo != null 
          ? '${driverInfo!['drivers']['fname']} ${driverInfo!['drivers']['lname']}'
          : 'Driver';
      
      items.add(_buildSummaryItem(
        Icons.schedule,
        'Scheduled Pickup',
        '$scheduledPickupTime - Waiting for pickup',
        'Driver: $driverName will pick up',
        false,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    }
    
    return items;
  }

  String _formatTimeFromString(String? timeString) {
    if (timeString == null) return 'Unknown time';
    
    try {
      final dateTime = DateTime.parse(timeString);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return timeString;
    }
  }

  Widget _buildNotificationsCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
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
                        Icons.notifications,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Recent Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                if (recentNotifications.isEmpty)
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
                            'No recent notifications. You\'ll see pickup/dropoff updates here.',
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
                  ...recentNotifications.take(3).map((notification) {
                    final type = notification['type'] ?? '';
                    final title = notification['title'] ?? 'Notification';
                    final message = notification['message'] ?? '';
                    
                    IconData icon;
                    Color iconColor;
                    
                    switch (type) {
                      case 'pickup':
                        icon = Icons.school;
                        iconColor = Colors.blue;
                        break;
                      case 'dropoff':
                        icon = Icons.home;
                        iconColor = Colors.green;
                        break;
                      default:
                        icon = Icons.info;
                        iconColor = primaryColor;
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
                          Icon(icon, color: iconColor, size: isMobile ? 16 : 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 16,
                                    color: black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                    color: black.withOpacity(0.7),
                                  ),
                                  maxLines: 2,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String title,
    String time,
    String description,
    bool completed,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    const Color white = Color(0xFFFFFFFF);

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: completed ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : icon,
              color: completed ? white : black.withOpacity(0.6),
              size: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 15,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: black.withOpacity(0.6),
                  ),
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
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    // Show message if no student selected
    if (widget.selectedStudentId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: widget.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Please select a student',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF000000).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Notification Card (larger, responsive)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: widget.primaryColor.withOpacity(0.3),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 32),
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
                            Icons.local_shipping,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          'Pick-up Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: widget.primaryColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for Pick-up',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: widget.primaryColor,
                            fontSize: widget.isMobile ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today, 3:30 PM',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.7),
                            fontSize: widget.isMobile ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 12 : 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: widget.isMobile ? 10 : 16,
                              ),
                              textStyle: TextStyle(
                                fontSize: widget.isMobile ? 13 : 15,
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Confirm Pick-up'),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.primaryColor,
                              side: BorderSide(color: widget.primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: widget.isMobile ? 10 : 16,
                              ),
                              textStyle: TextStyle(
                                fontSize: widget.isMobile ? 13 : 15,
                              ),
                            ),
                            icon: const Icon(Icons.directions_car, size: 18),
                            label: const Text('Confirm Drop-off'),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: widget.isMobile ? 10 : 14),
        // Driver Information Card
        _buildDriverInfoCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        // Pickup Summary Card
        _buildPickupSummaryCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        // Recent Notifications Card
        _buildNotificationsCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        // Today's Schedule Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: widget.primaryColor.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
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
                            Icons.calendar_today,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 8 : 12),
                    Row(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '8:00 AM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: widget.isMobile ? 13 : 15,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Drop-off',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.6),
                            fontSize: widget.isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 13 : 15,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 4 : 8),
                    Row(
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          size: 18,
                          color: const Color(0xFF000000).withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '3:30 PM',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: widget.isMobile ? 13 : 15,
                            color: const Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pick-up',
                          style: TextStyle(
                            color: const Color(0xFF000000).withOpacity(0.6),
                            fontSize: widget.isMobile ? 12 : 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 13 : 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: widget.isMobile ? 10 : 14),
        // Authorized Fetchers Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: widget.primaryColor.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
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
                            Icons.verified_user,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          'Authorized Fetchers',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 6 : 10),
                    isDashboardLoading
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: CircularProgressIndicator(
                              color: widget.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                        : dashboardFetchers.isEmpty
                        ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'No authorized fetchers found',
                            style: TextStyle(
                              color: const Color(0xFF000000).withOpacity(0.6),
                              fontSize: widget.isMobile ? 12 : 14,
                            ),
                          ),
                        )
                        : Column(
                          children:
                              dashboardFetchers.map((fetcher) {
                                return _fetcherRow(
                                  fetcher.name,
                                  fetcher.relationship,
                                  fetcher.isActive,
                                  widget.primaryColor,
                                  widget.isMobile,
                                  fetcher.profileImageUrl, // Add this line
                                );
                              }).toList(),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
