import 'package:flutter/material.dart';

class PickupConfirmationScreen extends StatelessWidget {
  const PickupConfirmationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text(
          'Pickup/Drop-off Confirmation',
          style: TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen, width: 1),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car, size: 48, color: primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Pickup Confirmation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirm your child\'s pickup or drop-off',
                    style: TextStyle(
                      fontSize: 14,
                      color: black.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement pickup confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pickup confirmed'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirm Pickup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement drop-off confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Drop-off confirmed'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.directions_car),
              label: const Text('Confirm Drop-off'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryGreen,
                side: BorderSide(color: primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
