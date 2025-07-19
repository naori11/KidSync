import 'package:flutter/material.dart';

class ParentNotificationsScreen extends StatelessWidget {
  const ParentNotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Text(
          'Notifications about child arrival/absence will appear here.',
        ),
      ),
    );
  }
}
