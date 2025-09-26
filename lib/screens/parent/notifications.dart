import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../parent/parent_home.dart'; // For Student model
import '../../services/parent_audit_service.dart';

class ParentNotificationsModal extends StatefulWidget {
  final Student selectedStudent;
  
  const ParentNotificationsModal({
    Key? key,
    required this.selectedStudent,
  }) : super(key: key);

  @override
  State<ParentNotificationsModal> createState() => _ParentNotificationsModalState();
}

class _ParentNotificationsModalState extends State<ParentNotificationsModal> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final ParentAuditService _auditService = ParentAuditService();
  
  List<Map<String, dynamic>> todayNotifications = [];
  // ...existing code...
  // replaced earlierNotifications list with a map grouped by date (yyyy-MM-dd)
  Map<String, List<Map<String, dynamic>>> groupedEarlierNotifications = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _loadNotifications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => isLoading = true);

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final parentResponse = await supabase
          .from('parents')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (parentResponse != null) {
        final parentId = parentResponse['id'];
        
        // Load today's notifications
        final todayNotifs = await _notificationService.getParentNotifications(
          parentId,
          studentId: widget.selectedStudent.id,
          todayOnly: true,
          limit: 50,
        );
        
        // Load all recent notifications (including pickup denials) for earlier section
        final allNotifs = await _notificationService.getParentAllNotifications(
          parentId,
          studentId: widget.selectedStudent.id,
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
        await _notificationService.markNotificationsAsRead(
          parentId,
          studentId: widget.selectedStudent.id,
        );

        // Log notification acknowledgment
        for (final notif in [...todayNotifs, ...allNotifs]) {
          if (notif['is_read'] != true) {
            await _auditService.logNotificationAcknowledgment(
              notificationId: notif['id']?.toString() ?? '',
              notificationType: notif['type'] ?? 'general',
              childId: widget.selectedStudent.id.toString(),
              childName: widget.selectedStudent.fullName,
              responseType: 'acknowledged',
              acknowledgmentTime: DateTime.now(),
              notificationData: notif,
            );
          }
        }
      }
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 500;
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: double.infinity,
            height: screenSize.height * 0.85,
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.notifications_active,
                          color: primaryGreen,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              widget.selectedStudent.fullName,
                              style: TextStyle(
                                color: black.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: black.withOpacity(0.6)),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          shape: CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Modal Content
                Expanded(
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(20),
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
                                    color: primaryGreen.withOpacity(0.2),
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
                                          color: primaryGreen,
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
                                          _buildModalNotificationItem(
                                            notification,
                                            primaryGreen,
                                            black,
                                            isMobile,
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
                                        primaryGreen,
                                        black,
                                        isMobile,
                                      ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEarlierDateGroups(
    Map<String, List<Map<String, dynamic>>> grouped,
    Color primaryGreen,
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
        _buildModalNotificationItem(
          notification,
          primaryGreen,
          black,
          isMobile,
        )
      ).toList());

      widgets.add(SizedBox(height: 8));
    }

    return widgets;
  }

  Widget _buildModalNotificationItem(
    Map<String, dynamic> notification,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'];
    final isRead = notification['is_read'] ?? false;
    
    IconData icon;
    Color iconColor;
    Color backgroundColor;
    
    switch (type) {
      case 'pickup':
        icon = Icons.school;
        iconColor = Colors.blue;
        backgroundColor = Colors.blue.withOpacity(0.1);
        break;
      case 'dropoff':
        icon = Icons.home;
        iconColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
        break;
      case 'rfid_entry':
        icon = Icons.login;
        iconColor = Colors.green;
        backgroundColor = Colors.green.withOpacity(0.1);
        break;
      case 'rfid_exit':
        icon = Icons.logout;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
      case 'pickup_denied':
        icon = Icons.cancel;
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.1);
        break;
      case 'pickup_dropoff_cancellation':
        icon = Icons.cancel_outlined;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.1);
        break;
      default:
        icon = Icons.info;
        iconColor = primaryGreen;
        backgroundColor = primaryGreen.withOpacity(0.1);
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

  Widget _buildRealNotificationItem(
    Map<String, dynamic> notification,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    // ...existing code...
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'];
    final isRead = notification['is_read'] ?? false;
    
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
      case 'rfid_entry':
        icon = Icons.login;
        iconColor = Colors.green;
        break;
      case 'rfid_exit':
        icon = Icons.logout;
        iconColor = Colors.orange;
        break;
      case 'pickup_denied':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.info;
        iconColor = primaryGreen;
    }

    String timeText = 'Recently';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt);
        timeText = DateFormat('h:mm a').format(dateTime);
      } catch (e) {
        timeText = 'Recently';
      }
    }

    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : greenWithOpacity,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRead
              ? primaryGreen.withOpacity(0.1)
              : primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: isMobile ? 18 : 20,
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
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
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
                color: primaryGreen,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    String message,
    String details,
    IconData icon,
    bool isRead,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : greenWithOpacity,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isRead
                  ? primaryGreen.withOpacity(0.1)
                  : primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isRead ? primaryGreen : primaryGreen,
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: black.withOpacity(0.6),
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
                color: primaryGreen,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
