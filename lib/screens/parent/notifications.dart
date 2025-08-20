import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../parent/parent_home.dart'; // For Student model

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
  
  List<Map<String, dynamic>> todayNotifications = [];
  List<Map<String, dynamic>> earlierNotifications = [];
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
          limit: 20,
        );
        
        // Load earlier notifications (not today)
        final allNotifs = await _notificationService.getParentNotifications(
          parentId,
          studentId: widget.selectedStudent.id,
          todayOnly: false,
          limit: 50,
        );
        
        // Filter out today's notifications from all notifications
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        
        final earlierNotifs = allNotifs.where((notif) {
          try {
            final createdAt = DateTime.parse(notif['created_at']);
            return createdAt.isBefore(todayStart);
          } catch (e) {
            return false;
          }
        }).toList();

        setState(() {
          todayNotifications = todayNotifs;
          earlierNotifications = earlierNotifs;
        });

        // Mark notifications as read after loading
        await _notificationService.markNotificationsAsRead(
          parentId,
          studentId: widget.selectedStudent.id,
        );
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
                              // Earlier Notifications Section
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
                                    if (earlierNotifications.isEmpty)
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
                                                'No earlier notifications',
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
                                      ...earlierNotifications.map((notification) =>
                                          _buildModalNotificationItem(
                                            notification,
                                            primaryGreen,
                                            black,
                                            isMobile,
                                          )).toList(),
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

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? Colors.grey.withOpacity(0.2)
              : primaryGreen.withOpacity(0.3),
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
                color: primaryGreen,
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
