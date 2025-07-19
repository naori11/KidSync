import 'package:flutter/material.dart';

class ChildStatusScreen extends StatelessWidget {
  const ChildStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Status')),
      body: const Center(
        child: Text('Child arrival/absence status will be shown here.'),
      ),
    );
  }
}
