import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'screens/conditional_screens.dart';
import 'screens/parent/parent_home.dart';
import 'screens/driver/driver_panel.dart';
import 'services/verification_reminder_service.dart';
import 'services/push_notification_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_strategy/url_strategy.dart';
import 'utils/html_import.dart' as html;
import 'dart:async'; // For StreamSubscription

// Global variable to store the initial URL, captured before Flutter app runs.
String initialUrlFromMain = "";

// Simple screen to show while initial auth processing happens.
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});
  static const String routeName =
      '/'; // Using '/' as the route name for the initial screen

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Initializing... Please wait."),
          ],
        ),
      ),
    );
  }
}

// The AuthRedirectScreen is no longer needed with the new approach.
// Its logic is now handled by InitialLoadingScreen and _KidSyncAppState.
/*
class AuthRedirectScreen extends StatefulWidget {
  const AuthRedirectScreen({super.key});

  @override
  State<AuthRedirectScreen> createState() => _AuthRedirectScreenState();
}

class _AuthRedirectScreenState extends State<AuthRedirectScreen> {
  // ... (previous content of AuthRedirectScreenState) ...
}
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    // Continue without Firebase for web-only environments
  }

  // Initialize timezone data for proper PST handling
  tz.initializeTimeZones();

  // Capture the initial URL as early as possible in Dart.
  if (kIsWeb) {
    initialUrlFromMain = html.window.location.href;
  }

  setHashUrlStrategy();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Push Notifications AFTER Supabase (mobile platforms only)
  if (!kIsWeb) {
    try {
      await PushNotificationService().initialize();
    } catch (e) {
      // Push notification initialization failed
    }
  }

  // Start the verification reminder service
  VerificationReminderService().startReminderService();

  runApp(
    ProviderScope(
      child: KidSyncApp(initialUrl: initialUrlFromMain), // Pass initialUrl
    ),
  );
}

class KidSyncApp extends StatefulWidget {
  // Changed to StatefulWidget
  final String initialUrl;
  const KidSyncApp({super.key, required this.initialUrl});

  @override
  State<KidSyncApp> createState() => _KidSyncAppState();
}

class _KidSyncAppState extends State<KidSyncApp> {
  StreamSubscription<AuthState>? _authSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _initialAuthCheckCompleted = false;

  bool _resetCodeValid() {
    if (!kIsWeb) return false;
    try {
      final ts = html.window.sessionStorage['kidsync_reset_ts'];
      if (ts == null) return false;
      final millis = int.tryParse(ts);
      if (millis == null) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      // treat older than 10 minutes as stale
      return DateTime.now().difference(dt).inMinutes < 10;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();

    // For invite flows with double hash pattern, navigate directly to set password screen
    if (kIsWeb &&
        widget.initialUrl.contains('#/set-password#access_token=') &&
        _resetCodeValid()) {
      // Just navigate directly to set password screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigator = _navigatorKey.currentState;
          try {
            // mark reset navigation as in-progress to avoid repeated pushes
            if (kIsWeb)
              html.window.sessionStorage['kidsync_reset_in_progress'] = '1';
          } catch (_) {}
          if (navigator != null) {
            navigator.pushReplacementNamed(SetPasswordScreen.routeName);
            return; // Skip the rest of the initialization
          }
        }
      });
    }

    // Set up auth state change listener
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final authEvent = data.event;
      final session = data.session;
      final user = session?.user;

      // Handle routing based on auth state
      _handleNavigation(session, user, authEvent, widget.initialUrl);
    });

    // Always call this as a backup, in case the auth state listener doesn't fire
    _checkInitialSessionAfterDelay();
  }

  // In _KidSyncAppState class, update the _checkInitialSessionAfterDelay method
  Future<void> _checkInitialSessionAfterDelay() async {
    // Use a shorter delay to ensure responsiveness
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _initialAuthCheckCompleted) {
      return;
    }

    // NEW CODE: Check for password reset code in session storage
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code') &&
        _resetCodeValid()) {
      // If a prior navigation to the reset screen is already in progress, don't navigate again
      if (kIsWeb &&
          html.window.sessionStorage.containsKey('kidsync_reset_in_progress')) {
        print(
          "[DEBUG] _checkInitialSessionAfterDelay: reset in progress flag set, skipping navigation",
        );
        _initialAuthCheckCompleted = true;
        return;
      }
      print(
        "[DEBUG] _checkInitialSessionAfterDelay: Found reset code in session storage, navigating to SetPasswordScreen",
      );
      try {
        html.window.sessionStorage['kidsync_reset_in_progress'] = '1';
      } catch (_) {}
      final navigator = _navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushReplacementNamed(SetPasswordScreen.routeName);
      }
      _initialAuthCheckCompleted = true;
      return;
    }

    // Keep your existing code for invitation URLs
    if ((widget.initialUrl.contains('#/set-password#') ||
            widget.initialUrl.contains('/set-password')) &&
        (widget.initialUrl.contains('access_token=') ||
            widget.initialUrl.contains('type=invite'))) {
      print(
        "[DEBUG] _checkInitialSessionAfterDelay: Detected invitation URL pattern.",
      );

      final navigator = _navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushReplacementNamed(SetPasswordScreen.routeName);
      }
      _initialAuthCheckCompleted = true;
      return;
    }

    // Check current session state
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    print(
      "[DEBUG] _checkInitialSessionAfterDelay: Session exists: ${session != null}, User exists: ${user != null}",
    );

    // If no session and no user, redirect to login screen
    if (session == null && user == null) {
      print(
        "[DEBUG] _checkInitialSessionAfterDelay: No session or user found, redirecting to login screen",
      );
      final navigator = _navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushReplacementNamed(LoginScreen.routeName);
      }
      _initialAuthCheckCompleted = true;
      return;
    }

    // Use existing handling logic for other cases
    _handleNavigation(
      session,
      user,
      AuthChangeEvent.initialSession,
      widget.initialUrl,
    );

    _initialAuthCheckCompleted = true;
  }

  void _handleNavigation(
    Session? session,
    User? user,
    AuthChangeEvent event,
    String initialUrl,
  ) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      print("[DEBUG] _handleNavigation: Navigator not yet available.");
      return;
    }

    String? currentRouteName;
    navigator.popUntil((route) {
      currentRouteName = route.settings.name;
      return true; // This doesn't pop anything, just inspects
    });
    print(
      "[DEBUG] _handleNavigation: Current route is $currentRouteName. Event: $event",
    );

    // NEW CODE: Check for reset code in session storage
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code') &&
        _resetCodeValid()) {
      print(
        "[DEBUG] _handleNavigation: Found reset code in session storage, navigating to SetPasswordScreen",
      );
      // Avoid repeatedly navigating if another navigation is already in progress
      if (kIsWeb &&
          html.window.sessionStorage.containsKey('kidsync_reset_in_progress')) {
        print(
          "[DEBUG] _handleNavigation: reset in-progress flag set, skipping navigation",
        );
        return;
      }
      try {
        html.window.sessionStorage['kidsync_reset_in_progress'] = '1';
      } catch (_) {}
      if (currentRouteName != SetPasswordScreen.routeName) {
        navigator.pushReplacementNamed(SetPasswordScreen.routeName);
      }
      return;
    }

    // Check for invite URL patterns - both regular and double hash format
    bool wasSetPasswordInviteFlow =
        (initialUrl.contains('/set-password') ||
            initialUrl.contains('#/set-password')) &&
        (initialUrl.contains('access_token=') ||
            initialUrl.contains('token=') ||
            initialUrl.contains('type=invite'));

    // Priority 1: Handle password reset or invite flow first
    if (wasSetPasswordInviteFlow ||
        event == AuthChangeEvent.passwordRecovery ||
        (initialUrl.contains('type=invite'))) {
      print(
        "[DEBUG] _handleNavigation: Set password flow detected. Navigating to SetPasswordScreen.",
      );
      if (currentRouteName != SetPasswordScreen.routeName) {
        navigator.pushReplacementNamed(SetPasswordScreen.routeName);
      }
      return; // Important to return here and not proceed to other checks
    }

    // Priority 2: Handle active session with user role-based navigation
    if (session != null && user != null) {
      final role = user.userMetadata?['role'];
      print(
        "[DEBUG] _handleNavigation: Session active (event: $event). Navigating based on role: $role",
      );

      // Initialize push notifications for logged-in user (mobile only)
      if (!kIsWeb && event == AuthChangeEvent.signedIn) {
        _initializePushNotificationsForUser(user.id);
      }

      switch (role) {
        case 'Admin':
          if (currentRouteName != '/admin')
            navigator.pushReplacementNamed('/admin');
          break;
        case 'Guard':
          if (currentRouteName != '/guard')
            navigator.pushReplacementNamed('/guard');
          break;
        case 'Teacher':
          if (currentRouteName != '/teacher')
            navigator.pushReplacementNamed('/teacher');
          break;
        case 'Parent':
          if (currentRouteName != '/parent')
            navigator.pushReplacementNamed('/parent');
          break;
        case 'Driver':
          if (currentRouteName != '/driver')
            navigator.pushReplacementNamed('/driver');
          break;
        default:
          print(
            "[DEBUG] _handleNavigation: Unknown role ('$role') or fallback. Navigating to LoginScreen.",
          );
          if (currentRouteName != LoginScreen.routeName)
            navigator.pushReplacementNamed(LoginScreen.routeName);
      }
    }
    // Priority 3: Handle no session (not logged in) - FORCE LOGIN NAVIGATION
    else {
      print(
        "[DEBUG] _handleNavigation: No active session (event: $event). Navigating to LoginScreen.",
      );

      // ALWAYS navigate to login screen if no session, regardless of current screen
      navigator.pushReplacementNamed(LoginScreen.routeName);
    }
  }

  // Initialize push notifications for logged-in user
  Future<void> _initializePushNotificationsForUser(String userId) async {
    try {
      final pushService = PushNotificationService();

      // Refresh and store FCM token in database
      await pushService.refreshFCMToken();
      print("✅ FCM token stored for user: $userId");
    } catch (e) {
      print("❌ Failed to initialize push notifications for user: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'KidSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      initialRoute: InitialLoadingScreen.routeName,
      routes: {
        InitialLoadingScreen.routeName: (_) => const InitialLoadingScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SetPasswordScreen.routeName: (_) => const SetPasswordScreen(),
        '#/set-password': (_) => const SetPasswordScreen(),
        '/admin': (_) => const AdminPanel(),
        '/guard': (_) => const GuardPanel(),
        '/teacher': (_) => const TeacherPanel(),
        '/parent': (_) => const ParentHomeScreen(),
        '/driver': (_) => const DriverPanel(),
      },
    );
  }
}

// Removed default Flutter counter example (MyHomePage) per architecture plan.
