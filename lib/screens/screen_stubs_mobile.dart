// Conditional screen imports - mobile stubs
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provide stub classes for web-only screens on mobile
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  
  @override
  Widget build(BuildContext context) {
    return _buildWebOnlyScreen(context, 'Admin');
  }
}

class GuardPanel extends StatelessWidget {
  const GuardPanel({super.key});
  
  @override
  Widget build(BuildContext context) {
    return _buildWebOnlyScreen(context, 'Guard');
  }
}

class TeacherPanel extends StatelessWidget {
  const TeacherPanel({super.key});
  
  @override
  Widget build(BuildContext context) {
    return _buildWebOnlyScreen(context, 'Teacher');
  }
}

class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({super.key});
  static const String routeName = '/set-password';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.computer, size: 80, color: Colors.blue),
              SizedBox(height: 24),
              Text(
                'Password reset is only available on web',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Please use a web browser to reset your password.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildWebOnlyScreen(BuildContext context, String role) {
  return Scaffold(
    appBar: AppBar(
      title: Text('$role Dashboard'),
      backgroundColor: Colors.blue.shade800,
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.computer,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              '$role features require a web browser',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please access the KidSync system through a web browser to use $role features.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (e) {
                  print('Error signing out: $e');
                }
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}