import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () => Navigator.pushNamed(context, '/parent/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Child Status'),
            onTap: () => Navigator.pushNamed(context, '/parent/child_status'),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle),
            title: const Text('Pickup/Drop-off Confirmation'),
            onTap:
                () =>
                    Navigator.pushNamed(context, '/parent/pickup_confirmation'),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Fetcher Code Generator'),
            onTap:
                () => Navigator.pushNamed(
                  context,
                  '/parent/fetcher_code_generator',
                ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile & Fetchers'),
            onTap: () => Navigator.pushNamed(context, '/parent/profile'),
          ),
        ],
      ),
    );
  }
}
