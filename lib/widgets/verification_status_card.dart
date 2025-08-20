import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VerificationStatusCard extends StatelessWidget {
  final List<Map<String, dynamic>> pendingVerifications;
  final VoidCallback onTap;
  final Color primaryColor;
  final bool isMobile;

  const VerificationStatusCard({
    Key? key,
    required this.pendingVerifications,
    required this.onTap,
    required this.primaryColor,
    required this.isMobile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    
    if (pendingVerifications.isEmpty) {
      return const SizedBox.shrink(); // Don't show card if no pending verifications
    }

    final verification = pendingVerifications.first; // Show the most recent one
    final student = verification['students'];
    final driver = verification['drivers'];
    final eventType = verification['event_type'];
    final eventTime = DateTime.parse(verification['event_time']);
    final studentName = '${student['fname']} ${student['lname']}';
    final driverName = '${driver['fname']} ${driver['lname']}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: Colors.orange.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with pulsing indicator
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Verification Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 16 : 18,
                                    color: black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Pulsing indicator
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                            if (pendingVerifications.length > 1)
                              Text(
                                '${pendingVerifications.length} pending verifications',
                                style: TextStyle(
                                  color: Colors.orange.withOpacity(0.8),
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.orange,
                        size: isMobile ? 16 : 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Verification details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              eventType == 'pickup' ? Icons.directions_car : Icons.home,
                              color: eventType == 'pickup' ? primaryColor : Colors.orange,
                              size: isMobile ? 18 : 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${eventType == 'pickup' ? 'Pickup' : 'Dropoff'} Verification',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 14 : 16,
                                color: black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Student and time info
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Student',
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    studentName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isMobile ? 13 : 14,
                                      color: black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Driver',
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    driverName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isMobile ? 13 : 14,
                                      color: black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Time info
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.grey[600],
                              size: isMobile ? 14 : 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('MMM dd, h:mm a').format(eventTime),
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: white,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 12 : 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: Colors.orange.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.verified_user, color: white),
                      label: Text(
                        'Verify Now',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}