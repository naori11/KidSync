import 'package:flutter/material.dart';

class ParentProfileScreen extends StatelessWidget {
  const ParentProfileScreen({Key? key}) : super(key: key);

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
          'Profile & Fetchers',
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
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen, width: 1),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryGreen,
                    child: Icon(Icons.person, size: 40, color: white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Parent Name',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'parent@email.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: black.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Fetchers Section
            Text(
              'Authorized Fetchers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: black,
              ),
            ),

            const SizedBox(height: 12),

            // Fetcher List
            Expanded(
              child: ListView(
                children: [
                  _buildFetcherCard(
                    'John Smith',
                    'Father',
                    true,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildFetcherCard(
                    'Sarah Johnson',
                    'Grandmother',
                    true,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildFetcherCard(
                    'Mike Wilson',
                    'Driver',
                    false,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                ],
              ),
            ),

            // Add Fetcher Button
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement add fetcher
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Add fetcher functionality'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Fetcher'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: white,
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

  Widget _buildFetcherCard(
    String name,
    String role,
    bool active,
    Color primaryGreen,
    Color black,
    Color greenWithOpacity,
    Color white,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: greenWithOpacity,
            radius: 20,
            child: Icon(Icons.person, color: primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: black,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(color: black.withOpacity(0.6), fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(
            Icons.circle,
            color: active ? primaryGreen : black.withOpacity(0.3),
            size: 12,
          ),
        ],
      ),
    );
  }
}
