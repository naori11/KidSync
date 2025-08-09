import 'package:flutter/material.dart';

class ParentProfileScreen extends StatelessWidget {
  const ParentProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      appBar: AppBar(
        title: const Text(
          'Profile & Fetchers',
          style: TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        shadowColor: const Color(0xFF000000).withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF000000).withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: greenWithOpacity,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: primaryGreen,
                          ),
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
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Fetchers Section
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.verified_user,
                    color: primaryGreen,
                    size: 20,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Authorized Fetchers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: black,
                  ),
                ),
              ],
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
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement add fetcher functionality
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: primaryGreen,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: black,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Add fetcher functionality will be available in the next update.',
                          style: TextStyle(color: black.withOpacity(0.7)),
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Fetcher'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: white,
                  elevation: 2,
                  shadowColor: const Color(0xFF000000).withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: const Color(0xFF000000).withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: greenWithOpacity,
                  radius: 20,
                  child: Icon(
                    Icons.verified_user,
                    color: primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 14,
                          color: black.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active ? greenWithOpacity : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    active ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: active ? primaryGreen : black.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
