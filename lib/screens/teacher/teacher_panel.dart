import 'package:flutter/material.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'teacher_panel_content.dart';

class TeacherPanel extends StatelessWidget {
  const TeacherPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Teacher',
      child: TeacherPanelContent(userName: ''),
    );
  }
}
