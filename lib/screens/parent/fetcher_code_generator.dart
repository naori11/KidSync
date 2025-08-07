import 'package:flutter/material.dart';

class FetcherCodeGeneratorScreen extends StatelessWidget {
  const FetcherCodeGeneratorScreen({Key? key}) : super(key: key);

  // Static PIN for temporary fetcher (for now)
  static const String _staticPin = "8472";

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
          'Fetcher Code Generator',
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
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code, size: 60, color: primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Temporary Fetcher Code',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this code with your temporary fetcher',
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

            // PIN Display Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'PIN Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: greenWithOpacity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _staticPin,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Valid for today only',
                    style: TextStyle(
                      fontSize: 12,
                      color: black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionItem(
                    '1. Share this PIN with your temporary fetcher',
                    Icons.share,
                    primaryGreen,
                    black,
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionItem(
                    '2. The fetcher will use this code for pickup/drop-off',
                    Icons.directions_car,
                    primaryGreen,
                    black,
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionItem(
                    '3. Code expires at the end of the day',
                    Icons.schedule,
                    primaryGreen,
                    black,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement copy to clipboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('PIN copied to clipboard'),
                          backgroundColor: primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy PIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement regenerate code
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code regenerated'),
                          backgroundColor: primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: BorderSide(color: primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    String text,
    IconData icon,
    Color iconColor,
    Color textColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }
}
