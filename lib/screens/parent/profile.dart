import 'package:flutter/material.dart';

class ParentProfileScreen extends StatelessWidget {
  const ParentProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar - matching parent_home.dart style
              Container(
                color: white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.school,
                                color: primaryGreen,
                                size: 28,
                              ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Profile & Family',
                        style: TextStyle(
                          color: black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.family_restroom,
                          color: primaryGreen,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Parent Profile Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: primaryGreen.withOpacity(0.3),
                            child: Container(
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(
                                      0xFF000000,
                                    ).withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 16 : 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: isMobile ? 30 : 40,
                                          backgroundColor: greenWithOpacity,
                                          child: Icon(
                                            Icons.person,
                                            size: isMobile ? 30 : 40,
                                            color: primaryGreen,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 12 : 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Sarah Williams',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 18 : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Mother of Emma Williams',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 14 : 16,
                                                  color: black.withOpacity(0.7),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'sarah.williams@email.com',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 12 : 14,
                                                  color: black.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Divider(color: black.withOpacity(0.1)),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          color: primaryGreen,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '+1 (555) 123-4567',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            color: black.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: primaryGreen,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '123 Maple Street, Springfield',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            color: black.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isMobile ? 10 : 14),

                        // Authorized Fetchers Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: primaryGreen.withOpacity(0.2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 12 : 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: greenWithOpacity,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.verified_user,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Authorized Fetchers',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    _buildFetcherItem(
                                      'David Williams',
                                      'Father',
                                      '+1 (555) 123-4568',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Margaret Smith',
                                      'Grandmother',
                                      '+1 (555) 987-6543',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Emma\'s Daycare Van',
                                      'School Transport',
                                      'License: ABC-123',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Jessica Brown',
                                      'Family Friend',
                                      '+1 (555) 456-7890',
                                      false,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isMobile ? 10 : 14),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 16,
                                  ),
                                  elevation: 2,
                                ),
                                icon: Icon(Icons.person_add, size: 18),
                                label: Text('Add Fetcher'),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                              'Add New Fetcher',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: black,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          'This feature allows you to add trusted family members and friends who can pick up Emma from school.',
                                          style: TextStyle(
                                            color: black.withOpacity(0.7),
                                          ),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryGreen,
                                              foregroundColor: white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('Got it'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen,
                                  side: BorderSide(color: primaryGreen),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 16,
                                  ),
                                ),
                                icon: Icon(Icons.edit, size: 18),
                                label: Text('Edit Profile'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Edit profile functionality',
                                      ),
                                      backgroundColor: primaryGreen,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFetcherItem(
    String name,
    String role,
    String contact,
    bool active,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: greenWithOpacity,
            radius: isMobile ? 16 : 20,
            child: Icon(
              Icons.person,
              color: primaryGreen,
              size: isMobile ? 18 : 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: black.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: active ? greenWithOpacity : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              active ? 'Active' : 'Pending',
              style: TextStyle(
                color: active ? primaryGreen : black.withOpacity(0.5),
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
