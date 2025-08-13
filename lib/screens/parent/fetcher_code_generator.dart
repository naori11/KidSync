import 'package:flutter/material.dart';
import 'dart:math';

class FetcherCodeGeneratorScreen extends StatefulWidget {
  const FetcherCodeGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<FetcherCodeGeneratorScreen> createState() =>
      _FetcherCodeGeneratorScreenState();
}

class _FetcherCodeGeneratorScreenState
    extends State<FetcherCodeGeneratorScreen> {
  String _generatedCode = '';
  bool _isGenerating = false;

  void _generateCode() {
    setState(() {
      _isGenerating = true;
    });

    // Simulate code generation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _generatedCode = _generateRandomCode();
          _isGenerating = false;
        });
      }
    });
  }

  String _generateRandomCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

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
                        'Fetcher Code',
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
                          Icons.security,
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
                        // Current Temporary Fetcher Card
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
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: greenWithOpacity,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Current Temporary Fetcher',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Container(
                                      padding: EdgeInsets.all(
                                        isMobile ? 16 : 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Emma\'s Mom',
                                            style: TextStyle(
                                              fontSize: isMobile ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: white,
                                            ),
                                          ),
                                          SizedBox(height: isMobile ? 8 : 12),
                                          Text(
                                            'PIN Code',
                                            style: TextStyle(
                                              fontSize: isMobile ? 14 : 16,
                                              color: white.withOpacity(0.8),
                                            ),
                                          ),
                                          SizedBox(height: isMobile ? 4 : 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 16 : 20,
                                              vertical: isMobile ? 12 : 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _generatedCode.isNotEmpty
                                                  ? _generatedCode
                                                  : '5698',
                                              style: TextStyle(
                                                fontSize: isMobile ? 24 : 28,
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                                letterSpacing: 4,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: isMobile ? 8 : 12),
                                          Text(
                                            'Valid for today only',
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 14,
                                              color: white.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                icon: Icon(Icons.content_copy, size: 18),
                                label: Text('Copy PIN'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('PIN copied to clipboard'),
                                      backgroundColor: primaryGreen,
                                    ),
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
                                icon: Icon(Icons.refresh, size: 18),
                                label: Text('Regenerate'),
                                onPressed: _isGenerating ? null : _generateCode,
                              ),
                            ),
                          ],
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
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Margaret Smith',
                                      'Grandmother',
                                      true,
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

                        // Confirm Actions Card
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
                                            Icons.check_circle_outline,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Confirm Actions',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryGreen,
                                              foregroundColor: white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: isMobile ? 10 : 16,
                                              ),
                                              elevation: 2,
                                            ),
                                            icon: Icon(
                                              Icons.check_circle,
                                              size: 18,
                                            ),
                                            label: Text('Confirm Pick-up'),
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Pick-up confirmed',
                                                  ),
                                                  backgroundColor: primaryGreen,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primaryGreen,
                                              side: BorderSide(
                                                color: primaryGreen,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: isMobile ? 10 : 16,
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.directions_car,
                                              size: 18,
                                            ),
                                            label: Text('Confirm Drop-off'),
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Drop-off confirmed',
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
    bool active,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: greenWithOpacity,
            radius: isMobile ? 20 : 24,
            child: Icon(
              Icons.person,
              color: primaryGreen,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 16 : 18,
                    color: black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: active ? primaryGreen : Colors.grey.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
