import 'package:flutter/material.dart';

class PickupConfirmationScreen extends StatelessWidget {
  const PickupConfirmationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup/Drop-off Confirmation')),
      body: const Center(
        child: Text('Pickup/Drop-off confirmation UI will be here.'),
      ),
    );
  }
}
