import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/role_protection.dart';
import '../../data/admin_repository.dart';
import 'admin_panel_content.dart';

class AdminPanel extends ConsumerWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(adminRepositoryProvider);
    final user = repository.currentUser;

    return RoleProtected(
      requiredRole: 'Admin',
      child: AdminPanelContent(
        userName: user?.userMetadata?['full_name'] ?? 'User',
      ),
    );
  }
}
