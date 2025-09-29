import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/driver_audit_service.dart';
import 'dart:async';

class DriverNotificationsTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverNotificationsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<DriverNotificationsTab> createState() => _DriverNotificationsTabState();
}

class _DriverNotificationsTabState extends State<DriverNotificationsTab> {
  final supabase = Supabase.instance.client;
  final DriverAuditService _auditService = DriverAuditService();
  
  List<Map<String, dynamic>> todayNotifications = [];
  Map<String, List<Map<String, dynamic>>> groupedEarlierNotifications = {};
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Set up periodic refresh for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => isLoading = true);
      
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // Load today's notifications
      final todayNotifs = await _getDriverNotifications(
        driverId: user.id,
        todayOnly: true,
        limit: 50,
      );
      
      // Load all recent notifications for earlier section
      final allNotifs = await _getDriverNotifications(
        driverId: user.id,
        limit: 200,
      );
      
      // Determine date ranges
      final now = DateTime.now().toLocal();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      // last 30 days including today => cutoff is 29 days before today's start
      final cutoffStart = todayStart.subtract(const Duration(days: 29));

      // Filter earlier notifications to those strictly before todayStart and within last 30 days
      final earlierNotifs = allNotifs.where((notif) {
        try {
          final createdAt = DateTime.parse(notif['created_at']).toLocal();
          final isBeforeToday = createdAt.isBefore(todayStart);
          final isWithinCutoff = createdAt.isAtSameMomentAs(cutoffStart) || createdAt.isAfter(cutoffStart);
          return isBeforeToday && isWithinCutoff;
        } catch (e) {
          return false;
        }
      }).toList();

      // Group earlier notifications by date (yyyy-MM-dd)
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final notif in earlierNotifs) {
        try {
          final createdAt = DateTime.parse(notif['created_at']).toLocal();
          final dateOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);
          final key = DateFormat('yyyy-MM-dd').format(dateOnly);
          grouped.putIfAbsent(key, () => []).add(notif);
        } catch (e) {
          // skip if parse fails
        }
      }

      setState(() {
        todayNotifications = todayNotifs.where((notif) {
          // ensure today's notifications are also within last 30 days (should be)
          try {
            final createdAt = DateTime.parse(notif['created_at']).toLocal();
            return (createdAt.isAtSameMomentAs(todayStart) || (createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd))) ||
                   createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd);
          } catch (e) {
            return false;
          }
        }).toList();
        groupedEarlierNotifications = grouped;
      });

      // Mark notifications as read after loading
      await _markDriverNotificationsAsRead(user.id);

      // Log notification acknowledgment
      for (final notif in [...todayNotifs, ...allNotifs]) {
        if (notif['is_read'] != true) {
          await _auditService.logStudentInfoAccess(
            studentId: notif['student_id']?.toString() ?? '0',
            studentName: notif['student_name'] ?? 'Unknown Student',
            accessType: 'notification_acknowledgment',
            accessDetails: {
              'notification_id': notif['id']?.toString() ?? '',
              'notification_type': notif['type'] ?? 'general',
              'acknowledgment_time': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    } catch (e) {
      print('Error loading driver notifications: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Get notifications for a driver
  Future<List<Map<String, dynamic>>> _getDriverNotifications({
    required String driverId,
    bool todayOnly = false,
    int limit = 50,
  }) async {
    try {
      // Build query to get notifications for this driver
      var query = supabase
          .from('notifications')
          .select('''
            *,
            students(fname, lname)
          ''')
          .eq('recipient_id', driverId);

      // Filter by today if requested
      if (todayOnly) {
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        
        query = query
            .gte('created_at', todayStart.toIso8601String())
            .lt('created_at', todayEnd.toIso8601String());
      }

      final notifications = await query
          .order('created_at', ascending: false)
          .limit(limit);

      // Enhance notifications with student names
      final enhancedNotifications = notifications.map<Map<String, dynamic>>((notif) {
        final student = notif['students'];
        final studentName = student != null 
            ? '${student['fname']} ${student['lname']}'
            : 'Unknown Student';
        
        return {
          ...notif,
          'student_name': studentName,
        };
      }).toList();

      return enhancedNotifications;
    } catch (e) {
      print('Error getting driver notifications: $e');
      return [];
    }
  }

  /// Mark notifications as read for a driver
  Future<bool> _markDriverNotificationsAsRead(String driverId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('recipient_id', driverId)
          .eq('is_read', false);
      
      return true;
    } catch (e) {
      print('Error marking driver notifications as read: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return RefreshIndicator(
      color: widget.primaryColor,
      onRefresh: _loadNotifications,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Today's Notifications Section
            Container(
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.today,
                        color: widget.primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Today\'s Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: black,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        color: widget.primaryColor,
                        onPressed: _loadNotifications,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (todayNotifications.isEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No notifications for today',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...todayNotifications.map((notification) =>
                        _buildNotificationItem(
                          notification,
                          widget.primaryColor,
                          black,
                          widget.isMobile,
                        )).toList(),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Earlier Notifications Section (grouped by date)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Earlier Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (groupedEarlierNotifications.isEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No earlier notifications in the last 30 days',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // build date groups sorted descending
                    ..._buildEarlierDateGroups(
                      groupedEarlierNotifications,
                      widget.primaryColor,
                      black,
                      widget.isMobile,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEarlierDateGroups(
    Map<String, List<Map<String, dynamic>>> grouped,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    // Sort keys (yyyy-MM-dd) descending
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final da = DateTime.parse(a);
        final db = DateTime.parse(b);
        return db.compareTo(da);
      });

    final List<Widget> widgets = [];

    for (final key in keys) {
      final date = DateTime.parse(key);
      final headerLabel = DateFormat('EEEE, MMM d').format(date); // e.g., Friday, Aug 21
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.08), width: 1),
          ),
          child: Text(
            headerLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: black.withOpacity(0.85),
            ),
          ),
        ),
      );

      final notifs = grouped[key]!;
      widgets.addAll(notifs.map((notification) =>
        _buildNotificationItem(
          notification,
          primaryColor,
          black,
          isMobile,
        )
      ).toList());

      widgets.add(SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildNotificationItem(
    Map<String, dynamic> notification,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'];
    final isRead = notification['is_read'] ?? false;
    final studentName = notification['student_name'] ?? 'Unknown Student';
    
    IconData icon;
    Color iconColor;
    Color backgroundColor;
    
    switch (type) {
      case 'pickup_approved':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
        break;
      case 'dropoff_approved':
        icon = Icons.home_outlined;
        iconColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.1);
        break;
      case 'pickup_verification':
        icon = Icons.verified_user;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
      case 'dropoff_verification':
        icon = Icons.security;
        iconColor = Colors.purple;
        backgroundColor = Colors.purple.withOpacity(0.1);
        break;
      case 'student_assignment':
        icon = Icons.assignment_ind;
        iconColor = primaryColor;
        backgroundColor = primaryColor.withOpacity(0.1);
        break;
      case 'route_update':
        icon = Icons.route;
        iconColor = Colors.indigo;
        backgroundColor = Colors.indigo.withOpacity(0.1);
        break;
      case 'pickup_skipped':
        icon = Icons.event_busy;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
      case 'pickup_cancelled':
        icon = Icons.cancel;
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
        break;
      case 'dropoff_cancelled':
        icon = Icons.cancel_outlined;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
      default:
        icon = Icons.info;
        iconColor = primaryColor;
        backgroundColor = primaryColor.withOpacity(0.1);
    }

    String timeText = 'Recently';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt).toLocal();
        timeText = DateFormat('h:mm a').format(dateTime);
      } catch (e) {
        timeText = 'Recently';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? Colors.grey.withOpacity(0.2)
              : iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
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
                    fontSize: 15,
                    color: black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: black.withOpacity(0.7),
                  ),
                ),
                if (studentName != 'Unknown Student') ...[
                  const SizedBox(height: 2),
                  Text(
                    'Student: $studentName',
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: iconColor, // Use icon color for unread indicator
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}