import 'package:flutter/material.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'guard_panel_content.dart';

class GuardPanel extends StatelessWidget {
  const GuardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Guard',
      child: GuardPanelContent(),
    );
  }
}
