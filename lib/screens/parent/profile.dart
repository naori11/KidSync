import 'package:flutter/material.dart';

class ParentProfileScreen extends StatelessWidget {
  const ParentProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Fetchers')),
      body: const Center(
        child: Text('Profile and fetcher management UI will be here.'),
      ),
    );
  }
}
