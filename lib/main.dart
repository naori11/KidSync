import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/guard/guard_panel.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/set_password_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;


// This new screen will handle the initial auth state and URL fragment check
class AuthRedirectScreen extends StatefulWidget {
  const AuthRedirectScreen({super.key});

  @override
  State<AuthRedirectScreen> createState() => _AuthRedirectScreenState();
}

class _AuthRedirectScreenState extends State<AuthRedirectScreen> {
  String _debugInfo = "Initializing..."; // State variable to hold debug info

  @override
  void initState() {
    super.initState();
    _processAuthRedirect(); // Changed name for clarity
  }

  Future<void> _processAuthRedirect() async {
    // Give Supabase a bit more time, especially on web after a redirect
    await Future.delayed(const Duration(milliseconds: 300)); // Slightly longer delay

    if (!mounted) return;

    final supabaseClient = Supabase.instance.client;
    final currentUser = supabaseClient.auth.currentUser;
    final uri = Uri.base;
    final fragment = uri.fragment;
    final bool isSetPasswordFlowFromUrl = fragment.startsWith(SetPasswordScreen.routeName);

    // Prepare debug information
    final newDebugInfo = """
    Current URL: ${uri.toString()}
    Fragment: $fragment
    SetPasswordScreen.routeName: ${SetPasswordScreen.routeName}
    IsSetPasswordFlowFromUrl: $isSetPasswordFlowFromUrl
    CurrentUser ID: ${currentUser?.id}
    CurrentUser Email: ${currentUser?.email}
    Current Time: ${DateTime.now()}
    """;

    // Update state to display debug info on screen
    if (mounted) {
      setState(() {
        _debugInfo = newDebugInfo;
      });
    }

    // Print to console as well
    print("AuthRedirectScreen Debug Info:\n$newDebugInfo");


    // ---- TEMPORARY DELAY FOR DEBUGGING ----
    // This will pause the screen for 10 seconds so you can read the debug info.
    // REMOVE THIS FOR PRODUCTION.
    if (kIsWeb) {
      await Future.delayed(const Duration(seconds: 10));
    }
    // ---- END TEMPORARY DELAY ----

    if (!mounted) return; // Check mounted again after delay

    if (isSetPasswordFlowFromUrl && currentUser != null) {
      print("AuthRedirectScreen: Navigating to SetPasswordScreen");
      Navigator.of(context).pushReplacementNamed(SetPasswordScreen.routeName);
    } else if (currentUser != null) {
      final role = currentUser.userMetadata?['role'];
      print("AuthRedirectScreen: User has session, role = $role. Navigating by role.");
      switch (role) {
        case 'Admin': // Ensure your roles are cased correctly
          Navigator.of(context).pushReplacementNamed('/admin');
          break;
        case 'Guard':
          Navigator.of(context).pushReplacementNamed('/guard');
          break;
        default:
          print("AuthRedirectScreen: Unknown role or fallback. Signing out and navigating to Login.");
          await supabaseClient.auth.signOut();
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    } else {
      print("AuthRedirectScreen: No currentUser or not set-password flow with user. Navigating to LoginScreen.");
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This build method will now display the _debugInfo string
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _debugInfo, // Display the debug information
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase here
  await Supabase.initialize(
    url: 'https://zouitgpqqudhqdcbuhbz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw',
  );

  runApp(const KidSyncApp());
}

class KidSyncApp extends StatelessWidget {
  const KidSyncApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const AuthRedirectScreen(),
      routes: {
        LoginScreen.routeName:
            (_) => const LoginScreen(), // Use static routeName
        SetPasswordScreen.routeName:
            (_) =>
                const SetPasswordScreen(), // Add route for set password screen
        '/admin': (_) => const AdminPanel(),
        // '/parent': (_) => const ParentHome(),
        // '/teacher': (_) => const TeacherDashboard(),
        '/guard': (_) => GuardPanel(),
        // '/guard': (_) => const GuardPanel(role: 'Guard'),
        // '/driver': (_) => const DriverPage(),
      },
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
