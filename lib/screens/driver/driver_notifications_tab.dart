import 'package:flutter/material.dart';

class DriverNotificationsTab extends StatelessWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverNotificationsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Text(
        'Notifications (empty)',
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
      ),
    );
  }
}