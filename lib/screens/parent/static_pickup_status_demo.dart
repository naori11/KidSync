import 'package:flutter/material.dart';
import '../../models/pickup_status.dart';
import 'package:intl/intl.dart';

/// Demo page showing how parents would see static pickup status information
/// This demonstrates the static pickup status display for parents
class StaticPickupStatusDemo extends StatelessWidget {
  const StaticPickupStatusDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Status (Parent View)'),
        backgroundColor: const Color(0xFF19AE61),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF19AE61), Color(0xFF15A055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.family_restroom,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'BB Parents App',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Static Pickup Status Demo',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Today's Pickup Status
            _buildTodaysStatus(),

            const SizedBox(height: 24),

            // Recent Pickup History
            _buildRecentHistory(),

            const SizedBox(height: 24),

            // Demo Instructions
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysStatus() {
    final today = DateTime.now();
    final todaysStatuses = StaticPickupStatusStorage.getPickupStatusesForDate(
      today,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Pickup Status',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 12),

        if (todaysStatuses.isEmpty)
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No pickups recorded today',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the Driver Panel to mark students as picked up',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...todaysStatuses.map(
            (status) => _buildStatusCard(status, isToday: true),
          ),
      ],
    );
  }

  Widget _buildRecentHistory() {
    final recentStatuses =
        StaticPickupStatusStorage.getRecentPickupStatuses()
            .where((status) => !_isToday(status.pickupTime))
            .toList();

    if (recentStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Pickup History',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 12),

        ...recentStatuses.map((status) => _buildStatusCard(status)),
      ],
    );
  }

  Widget _buildStatusCard(PickupStatus status, {bool isToday = false}) {
    return Card(
      elevation: isToday ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              isToday
                  ? Border.all(color: const Color(0xFF19AE61), width: 2)
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF19AE61),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isToday) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.studentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'PICKED UP',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Pickup Details
              _buildDetailRow(
                Icons.access_time,
                'Pickup Time',
                DateFormat('MMM dd, yyyy - h:mm a').format(status.pickupTime),
              ),

              const SizedBox(height: 8),

              _buildDetailRow(Icons.person, 'Driver', status.driverName),

              const SizedBox(height: 8),

              _buildDetailRow(
                Icons.directions_car,
                'Vehicle',
                status.vehicleNumber,
              ),

              const SizedBox(height: 8),

              _buildDetailRow(Icons.school, 'School', status.schoolName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF19AE61)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF000000).withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Demo Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Go to the Driver Panel\n'
              '2. Navigate to the "Pick-up/Drop-off" tab\n'
              '3. Tap on student names to mark them as picked up\n'
              '4. Return here to see the static pickup status updates\n\n'
              'This demonstrates how parents would see pickup notifications in the BB Parents app.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF000000),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }
}
