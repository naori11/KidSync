import 'package:flutter/material.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_panel_content.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return RoleProtected(
      requiredRole: 'Admin',
      child: AdminPanelContent(
        userName: user?.userMetadata?['full_name'] ?? 'User',
      ),
    );
  }
}
