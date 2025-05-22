import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleProtected extends StatefulWidget {
  final String requiredRole;
  final Widget child;

  const RoleProtected({
    Key? key,
    required this.requiredRole,
    required this.child,
  }) : super(key: key);

  @override
  _RoleProtectedState createState() => _RoleProtectedState();
}

class _RoleProtectedState extends State<RoleProtected> {
  bool _loading = true;
  bool _unauthorized = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      // Not logged in
      _redirectToLogin();
      return;
    }

    final role = user.userMetadata?['role'];

    if (role != widget.requiredRole) {
      // Role mismatch
      setState(() {
        _unauthorized = true;
        _loading = false;
      });
    } else {
      // Authorized
      setState(() {
        _unauthorized = false;
        _loading = false;
      });
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_unauthorized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                "Access Denied",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text("You are not authorized to view this page."),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _redirectToLogin,
                child: const Text("Return to Login"),
              ),
            ],
          ),
        ),
      );
    }

    // Authorized → show the actual page
    return widget.child;
  }
}
