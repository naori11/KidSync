import 'package:flutter/material.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'admin_panel_content.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Admin',
      child: AdminPanelContent(
        userName: user?.userMetadata?['full_name'] ?? 'User',
      ),
    );
  }
}
