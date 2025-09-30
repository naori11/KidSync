import 'dart:async';
import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';
import '../services/notification_service.dart';
import '../screens/driver/driver_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InAppNotificationWidget extends StatefulWidget {
  final String userRole; // 'parent', 'teacher', 'driver'
  final Widget child;
  final Color primaryColor;
  
  const InAppNotificationWidget({
    Key? key,
    required this.userRole,
    required this.child,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<InAppNotificationWidget> createState() => _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<InAppNotificationWidget>
    with TickerProviderStateMixin {
  final PushNotificationService _pushService = PushNotificationService();
  final NotificationService _notificationService = NotificationService();
  final supabase = Supabase.instance.client;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _badgeSubscription;
  
  OverlayEntry? _overlayEntry;
  Timer? _autoHideTimer;
  
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupNotificationListeners();
    _updateBadgeCount();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _badgeSubscription?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    _autoHideTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  void _setupNotificationListeners() {
    // Listen to push notifications
    _notificationSubscription = _pushService.notificationStream.listen((data) {
      _handleNotification(data);
    });
    
    // Listen to badge count updates
    _badgeSubscription = _pushService.badgeCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
    
    // ✅ ADD REAL-TIME DATABASE SUBSCRIPTION
    _setupRealtimeSubscription();
  }
  
  void _setupRealtimeSubscription() {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    
    // Listen to real-time notifications from database
    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (mounted && data.isNotEmpty) {
            // Filter for current user's unread notifications
            final userNotifications = data.where((notification) =>
                notification['recipient_id'] == currentUser.id &&
                notification['is_read'] == false).toList();
            
            if (userNotifications.isNotEmpty) {
              // Get the most recent notification
              final latestNotification = userNotifications.last;
              print('📱 Real-time notification received: ${latestNotification['message']}');
              
              // Show in-app notification
              _showInAppNotification({
                'title': latestNotification['title'] ?? 'KidSync Notification',
                'body': latestNotification['message'] ?? '',
                'type': latestNotification['type'] ?? 'info',
                'data': latestNotification['extra_data'] ?? {},
                'id': latestNotification['id'],
              });
              
              _updateBadgeCount();
            }
          }
        });
  }

  void _handleNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final notificationData = data['data'] ?? {};
    
    // Only show in-app notifications for foreground messages
    if (type == 'foreground') {
      _showInAppNotification(notificationData);
    } else if (type == 'tap') {
      // Handle notification tap - navigate to appropriate screen
      _handleNotificationTap(notificationData);
    }
    
    _updateBadgeCount();
  }

  void _showInAppNotification(Map<String, dynamic> data) {
    if (_overlayEntry != null) {
      _hideInAppNotification(); // Hide current notification first
    }
    
    _overlayEntry = _createOverlayEntry(data);
    Overlay.of(context).insert(_overlayEntry!);
    
    _slideController.forward();
    _fadeController.forward();
    
    // Auto hide after 5 seconds
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      _hideInAppNotification();
    });
  }

  OverlayEntry _createOverlayEntry(Map<String, dynamic> data) {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildNotificationCard(data),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final title = data['title'] ?? 'New Notification';
    final body = data['message'] ?? data['body'] ?? '';
    final type = data['type'] ?? 'general';
    final studentName = data['student_name'] ?? '';
    
    IconData icon;
    Color iconColor;
    
    switch (type) {
      case 'pickup':
      case 'pickup_approved':
        icon = Icons.school;
        iconColor = Colors.green;
        break;
      case 'pickup_denied':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'dropoff':
      case 'dropoff_approved':
        icon = Icons.home;
        iconColor = Colors.blue;
        break;
      case 'dropoff_denied':
        icon = Icons.cancel_outlined;
        iconColor = Colors.orange;
        break;
      case 'rfid_entry':
        icon = Icons.login;
        iconColor = Colors.green;
        break;
      case 'rfid_exit':
        icon = Icons.logout;
        iconColor = Colors.orange;
        break;
      case 'emergency':
        icon = Icons.warning;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.notifications;
        iconColor = widget.primaryColor;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: iconColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _hideInAppNotification();
            _handleNotificationTap(data);
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (studentName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Student: $studentName',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.primaryColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                color: Colors.grey[600],
                onPressed: _hideInAppNotification,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideInAppNotification() {
    _autoHideTimer?.cancel();
    
    if (_overlayEntry != null) {
      _slideController.reverse().then((_) {
        _fadeController.reverse().then((_) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        });
      });
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final studentId = data['student_id'];
    
    // Navigate based on user role and notification type
    switch (widget.userRole) {
      case 'parent':
        _navigateToParentNotifications(studentId);
        break;
      case 'driver':
        _navigateToDriverNotifications();
        break;
      case 'teacher':
        _navigateToTeacherNotifications(studentId);
        break;
      default:
        // Show generic notification details
        _showNotificationDetails(data);
    }
  }

  void _navigateToParentNotifications(int? studentId) {
    // This would need to be implemented based on your parent navigation structure
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening parent notifications...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToDriverNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: DriverNotificationsTab(
            primaryColor: widget.primaryColor,
            isMobile: MediaQuery.of(context).size.width < 600,
          ),
        ),
      ),
    );
  }

  void _navigateToTeacherNotifications(int? studentId) {
    // This would need to be implemented based on your teacher navigation structure
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening teacher notifications...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Notification'),
        content: Text(data['message'] ?? data['body'] ?? 'No message'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBadgeCount() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      int count = 0;
      
      switch (widget.userRole) {
        case 'parent':
          // Get parent ID first
          final parentResponse = await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();
          
          if (parentResponse != null) {
            count = await _notificationService.getUnreadNotificationCount(
              parentResponse['id'],
            );
          }
          break;
        case 'driver':
          count = await _notificationService.getUnreadDriverNotificationCount(user.id);
          break;
        case 'teacher':
          // Implement teacher notification count if needed
          break;
      }
      
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      print('Error updating badge count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Show badge indicator in top-right corner
        if (_unreadCount > 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;

  const NotificationBadge({
    Key? key,
    required this.child,
    required this.count,
    this.badgeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}