import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/guard/guard_panel.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/teacher/teacher_panel.dart';
import 'screens/set_password_screen.dart';
import 'screens/parent/parent_home.dart';
import 'screens/driver/driver_panel.dart';
import 'services/verification_reminder_service.dart';
import 'services/attendance_escalation_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_strategy/url_strategy.dart';
import 'dart:html' as html;
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

  // Capture the initial URL as early as possible in Dart.
  if (kIsWeb) {
    initialUrlFromMain = html.window.location.href;
    print("main.dart - main(): Captured initial full URL: $initialUrlFromMain");
  }

  setHashUrlStrategy();

  await Supabase.initialize(
    url: 'https://zouitgpqqudhqdcbuhbz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw',
  );

  // Start the verification reminder service
  VerificationReminderService().startReminderService();

  // Start the attendance escalation service
  AttendanceEscalationService().startEscalationMonitoring();

  runApp(KidSyncApp(initialUrl: initialUrlFromMain)); // Pass initialUrl
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

  @override
  void initState() {
    super.initState();
    print(
      "[DEBUG] _KidSyncAppState initState: Initial URL passed from main: ${widget.initialUrl}",
    );

    // For invite flows with double hash pattern, navigate directly to set password screen
    if (kIsWeb && widget.initialUrl.contains('#/set-password#access_token=')) {
      print(
        "[DEBUG] Detected double hash pattern in URL - cleaning up routing",
      );

      // Just navigate directly to set password screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigator = _navigatorKey.currentState;
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

      print(
        "[DEBUG] Auth state changed: $authEvent, User: ${user?.email}, Session: ${session != null}",
      );

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

    print(
      "[DEBUG] _checkInitialSessionAfterDelay: Manually checking session as no onAuthStateChange event seemed to complete navigation yet.",
    );

    // NEW CODE: Check for password reset code in session storage
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code')) {
      print(
        "[DEBUG] _checkInitialSessionAfterDelay: Found reset code in session storage, navigating to SetPasswordScreen",
      );
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
        html.window.sessionStorage.containsKey('kidsync_reset_code')) {
      print(
        "[DEBUG] _handleNavigation: Found reset code in session storage, navigating to SetPasswordScreen",
      );
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
        '/guard': (_) => GuardPanel(),
        '/teacher': (_) => const TeacherPanel(),
        '/parent': (_) => const ParentHomeScreen(),
        '/driver': (_) => const DriverPanel(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
