import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final supabase = Supabase.instance.client;

  // Stream controllers for different notification types
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _badgeCountController = StreamController<int>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<int> get badgeCountStream => _badgeCountController.stream;

  bool _isInitialized = false;
  String? _fcmToken;
  int _badgeCount = 0;

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase (if not already initialized)
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // Firebase already initialized
        print('Firebase already initialized');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Setup Firebase messaging handlers
      await _setupFirebaseHandlers();

      // Get FCM token
      await _getFCMToken();

      _isInitialized = true;
      print('✅ Push Notification Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Push Notification Service: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create notification channels for different types
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel pickupChannel = AndroidNotificationChannel(
      'pickup_channel',
      'Pickup Notifications',
      description: 'Notifications for student pickup events',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const AndroidNotificationChannel dropoffChannel =
        AndroidNotificationChannel(
          'dropoff_channel',
          'Dropoff Notifications',
          description: 'Notifications for student dropoff events',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('notification'),
        );

    const AndroidNotificationChannel attendanceChannel =
        AndroidNotificationChannel(
          'attendance_channel',
          'Attendance Notifications',
          description: 'Notifications for attendance updates',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('notification'),
        );

    const AndroidNotificationChannel emergencyChannel =
        AndroidNotificationChannel(
          'emergency_channel',
          'Emergency Notifications',
          description: 'High priority emergency notifications',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('emergency'),
        );

    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
          'general_channel',
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
        );

    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(pickupChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dropoffChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(attendanceChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(emergencyChannel);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(generalChannel);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request Firebase messaging permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Firebase permission granted: ${settings.authorizationStatus}');

    // Request system notification permissions
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      print('Android notification permission: $status');
    }
  }

  /// Setup Firebase messaging handlers
  Future<void> _setupFirebaseHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTerminatedMessage(initialMessage);
    }

    // Handle background message processing
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Get and store FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        print('FCM Token: $_fcmToken');
        await _storeFCMToken(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_storeFCMToken);
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Store FCM token in Supabase
  Future<void> _storeFCMToken(String token) async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('user_fcm_tokens').upsert({
          'user_id': user.id,
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        _fcmToken = token;
        print('✅ FCM token stored successfully');
      }
    } catch (e) {
      print('❌ Error storing FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Received foreground message: ${message.messageId}');

    // Show local notification
    _showLocalNotification(message);

    // Update badge count
    _updateBadgeCount();

    // Emit to stream for UI updates
    _notificationStreamController.add({
      'type': 'foreground',
      'message': message,
      'data': message.data,
    });
  }

  /// Handle background messages (app opened from notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    print('📱 Received background message: ${message.messageId}');

    _notificationStreamController.add({
      'type': 'background',
      'message': message,
      'data': message.data,
    });
  }

  /// Handle terminated messages (app opened from notification when closed)
  void _handleTerminatedMessage(RemoteMessage message) {
    print('📱 Received terminated message: ${message.messageId}');

    _notificationStreamController.add({
      'type': 'terminated',
      'message': message,
      'data': message.data,
    });
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      final notificationType = message.data['type'] ?? 'general';
      final channelId = _getChannelId(notificationType);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            channelId,
            _getChannelName(channelId),
            channelDescription: _getChannelDescription(channelId),
            importance: _getImportance(notificationType),
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF19AE61), // KidSync primary green
            playSound: true,
            enableVibration: true,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _notificationStreamController.add({'type': 'tap', 'data': data});
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  /// Update badge count
  Future<void> _updateBadgeCount() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('notifications')
            .select('id')
            .eq('recipient_id', user.id)
            .eq('is_read', false);

        _badgeCount = response.length;
        _badgeCountController.add(_badgeCount);
      }
    } catch (e) {
      print('Error updating badge count: $e');
    }
  }

  /// Get channel ID based on notification type
  String _getChannelId(String type) {
    switch (type) {
      case 'pickup':
      case 'pickup_approved':
      case 'pickup_denied':
      case 'pickup_verification':
        return 'pickup_channel';
      case 'dropoff':
      case 'dropoff_approved':
      case 'dropoff_denied':
      case 'dropoff_verification':
        return 'dropoff_channel';
      case 'attendance':
      case 'rfid_entry':
      case 'rfid_exit':
        return 'attendance_channel';
      case 'emergency':
      case 'emergency_exit':
        return 'emergency_channel';
      default:
        return 'general_channel';
    }
  }

  /// Get channel name
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'pickup_channel':
        return 'Pickup Notifications';
      case 'dropoff_channel':
        return 'Dropoff Notifications';
      case 'attendance_channel':
        return 'Attendance Notifications';
      case 'emergency_channel':
        return 'Emergency Notifications';
      default:
        return 'General Notifications';
    }
  }

  /// Get channel description
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'pickup_channel':
        return 'Notifications for student pickup events and approvals';
      case 'dropoff_channel':
        return 'Notifications for student dropoff events and approvals';
      case 'attendance_channel':
        return 'Notifications for attendance updates and RFID events';
      case 'emergency_channel':
        return 'High priority emergency notifications';
      default:
        return 'General app notifications and updates';
    }
  }

  /// Get importance level
  Importance _getImportance(String type) {
    switch (type) {
      case 'emergency':
      case 'emergency_exit':
        return Importance.max;
      case 'pickup_denied':
      case 'dropoff_denied':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  /// Send local notification for testing
  Future<void> showTestNotification({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications for debugging',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF19AE61),
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    _badgeCount = 0;
    _badgeCountController.add(_badgeCount);
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Get current badge count
  int get badgeCount => _badgeCount;

  /// Get current FCM token (public method for testing)
  Future<String?> getFCMToken() async {
    if (_fcmToken == null) {
      await _getFCMToken();
    }
    return _fcmToken;
  }

  /// Refresh and store FCM token for current user
  Future<void> refreshFCMToken() async {
    try {
      await _getFCMToken();
      if (_fcmToken != null) {
        await _storeFCMToken(_fcmToken!);
      }
    } catch (e) {
      print('❌ Error refreshing FCM token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationStreamController.close();
    _badgeCountController.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 Handling background message: ${message.messageId}');
}
