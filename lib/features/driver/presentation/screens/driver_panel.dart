import 'package:flutter/material.dart';
import '../../../../widgets/role_protection.dart';
import 'driver_home.dart';

class DriverPanel extends StatelessWidget {
  const DriverPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(requiredRole: 'Driver', child: DriverHomeScreen());
  }
}
