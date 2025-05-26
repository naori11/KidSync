import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/guard/guard_panel.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/set_password_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_strategy/url_strategy.dart'; // <--- IMPORT THIS (already present)
import 'dart:html' as html; // <--- IMPORT THIS for web-specific URL reading (already present)
import 'dart:async'; // For StreamSubscription

// Global variable to store the initial URL, captured before Flutter app runs.
String initialUrlFromMain = "";

// Simple screen to show while initial auth processing happens.
class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});
  static const String routeName = '/'; // Using '/' as the route name for the initial screen

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

  // Initialize Supabase here
  await Supabase.initialize(
    url: 'https://zouitgpqqudhqdcbuhbz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw',
  );

  runApp(KidSyncApp(initialUrl: initialUrlFromMain)); // Pass initialUrl
}

class KidSyncApp extends StatefulWidget { // Changed to StatefulWidget
  final String initialUrl;
  const KidSyncApp({super.key, required this.initialUrl});

  @override
  State<KidSyncApp> createState() => _KidSyncAppState();
}

class _KidSyncAppState extends State<KidSyncApp> {
  StreamSubscription<AuthState>? _authSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _initialAuthCheckCompleted = false; // To coordinate with _checkInitialSessionAfterDelay

  @override
  void initState() {
    super.initState();
    print("[TEMP DEBUG] _KidSyncAppState initState: Initial URL passed from main: ${widget.initialUrl}");

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final User? user = session?.user;

      // General log for every event
      print("[TEMP DEBUG] _KidSyncAppState onAuthStateChange: event=$event, user ID=${user?.id}, session active: ${session != null}");
      _initialAuthCheckCompleted = true; // Mark that an auth event has been processed

      // Removed the specific 'return;' for initialSession on invite.
      // All events will now go to _handleNavigation.
      // If initialSession has user=null for an invite, _handleNavigation will likely route to login.

      _handleNavigation(session, user, event, widget.initialUrl);
    });

    _checkInitialSessionAfterDelay();
  }

  void _handleNavigation(Session? session, User? user, AuthChangeEvent event, String initialUrl) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      print("[TEMP DEBUG] _handleNavigation: Navigator not yet available.");
      return;
    }

    String? currentRouteName;
    navigator.popUntil((route) {
      currentRouteName = route.settings.name;
      return true; // This doesn't pop anything, just inspects
    });
    print("[TEMP DEBUG] _handleNavigation: Current route is $currentRouteName. Event: $event");

    bool wasSetPasswordInviteFlow = initialUrl.contains('/#/set-password') &&
                                 (initialUrl.contains('access_token=') || initialUrl.contains('token='));

    // Priority 1: If we have an active session and user
    if (session != null && user != null) {
        // Sub-priority 1.1: It was a set password invite flow
        if (wasSetPasswordInviteFlow) {
            print("[TEMP DEBUG] _handleNavigation: Set password flow (from initial URL) with active session. Navigating to SetPasswordScreen.");
            if (currentRouteName != SetPasswordScreen.routeName) {
                navigator.pushReplacementNamed(SetPasswordScreen.routeName);
            } else {
                print("[TEMP DEBUG] _handleNavigation: Already on SetPasswordScreen for invite flow.");
            }
        }
        // Sub-priority 1.2: It was an explicit password recovery event
        else if (event == AuthChangeEvent.passwordRecovery) {
            print("[TEMP DEBUG] _handleNavigation: AuthChangeEvent.passwordRecovery detected with active session. Navigating to SetPasswordScreen.");
            if (currentRouteName != SetPasswordScreen.routeName) {
                navigator.pushReplacementNamed(SetPasswordScreen.routeName);
            } else {
                print("[TEMP DEBUG] _handleNavigation: Already on SetPasswordScreen for passwordRecovery event.");
            }
        }
        // Sub-priority 1.3: Regular signed-in user, navigate by role
        else {
            final role = user.userMetadata?['role'];
            print("[TEMP DEBUG] _handleNavigation: Session active (event: $event). Navigating based on role: $role");
            switch (role) {
            case 'Admin':
                if (currentRouteName != '/admin') navigator.pushReplacementNamed('/admin');
                break;
            case 'Guard':
                if (currentRouteName != '/guard') navigator.pushReplacementNamed('/guard');
                break;
            default:
                print("[TEMP DEBUG] _handleNavigation: Unknown role ('$role') or fallback. Navigating to LoginScreen.");
                if (currentRouteName != LoginScreen.routeName) navigator.pushReplacementNamed(LoginScreen.routeName);
            }
        }
    }
    // Priority 2: No session (user is signed out, or token was invalid/not processed by client)
    else {
      print("[TEMP DEBUG] _handleNavigation: No active session (event: $event). Navigating to LoginScreen.");
      // Avoid navigation loop if already on login or initial loading trying to go to login
      if (currentRouteName != LoginScreen.routeName && currentRouteName != InitialLoadingScreen.routeName) {
        navigator.pushReplacementNamed(LoginScreen.routeName);
      } else if (currentRouteName == LoginScreen.routeName) {
        print("[TEMP DEBUG] _handleNavigation: Already on LoginScreen.");
      } else if (currentRouteName == InitialLoadingScreen.routeName) {
         print("[TEMP DEBUG] _handleNavigation: Still on InitialLoadingScreen with no session. Will navigate to LoginScreen.");
         // If on loading and no session, definitely go to login.
         // This handles the case where initialSession had no user and it wasn't an invite needing a wait.
         navigator.pushReplacementNamed(LoginScreen.routeName);
      }
    }
  }


  Future<void> _checkInitialSessionAfterDelay() async {
    // This delay helps ensure onAuthStateChange has a chance to fire for initial events.
    await Future.delayed(const Duration(milliseconds: 500)); // Slightly longer delay for safety
    if (!mounted || _initialAuthCheckCompleted) {
      // If an auth event already ran and potentially navigated, or widget is disposed, do nothing.
      print("[TEMP DEBUG] _checkInitialSessionAfterDelay: Exiting because mounted=$mounted or _initialAuthCheckCompleted=$_initialAuthCheckCompleted");
      return;
    }

    print("[TEMP DEBUG] _checkInitialSessionAfterDelay: Manually checking session as no onAuthStateChange event seemed to complete navigation yet.");
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    
    // Call _handleNavigation to use the centralized logic.
    // Treat this manual check as if it's a follow-up to an initial state.
    // Pass AuthChangeEvent.initialSession as the event type for this manual check's context.
    _handleNavigation(session, user, AuthChangeEvent.initialSession, widget.initialUrl); 
    
    _initialAuthCheckCompleted = true; // Mark this manual check as done.
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
      navigatorKey: _navigatorKey, // Assign navigatorKey
      title: 'KidSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: InitialLoadingScreen.routeName, // Start with loading screen
      routes: {
        InitialLoadingScreen.routeName: (_) => const InitialLoadingScreen(), // Add InitialLoadingScreen route
        LoginScreen.routeName:
            (_) => const LoginScreen(), // Use static routeName
        SetPasswordScreen.routeName:
            (_) =>
                const SetPasswordScreen(),
        '/admin': (_) => const AdminPanel(),
        // '/parent': (_) => const ParentHome(),
        // '/teacher': (_) => const TeacherDashboard(),
        '/guard': (_) => GuardPanel(),
        // '/guard': (_) => const GuardPanel(role: 'Guard'),
        // '/driver': (_) => const DriverPage(),
      },
      // home: const MyHomePage(title: 'Flutter Demo Home Page'), // home is replaced by initialRoute
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