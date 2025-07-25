import 'package:flutter/material.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'parent_home.dart';

class ParentPanel extends StatelessWidget {
  const ParentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Parent',
      child: ParentHomeScreen(),
    );
  }
}
