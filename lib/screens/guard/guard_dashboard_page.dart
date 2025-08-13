import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  String? guardId;
  String? guardName;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGuardData();
  }

  Future<void> _loadGuardData() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    guardId = user?.id;

    if (guardId == null) {
      setState(() => isLoading = false);
      return;
    }

    // Fetch guard's first and last name from the users table
    final guardData =
        await supabase
            .from('users')
            .select('fname, lname')
            .eq('id', guardId!)
            .maybeSingle();

    guardName =
        guardData != null
            ? '${guardData['fname'] ?? ''} ${guardData['lname'] ?? ''}'.trim()
            : user?.email ?? 'Guard';

    setState(() => isLoading = false);
  }

  String getTodayLabel() {
    final now = DateTime.now();
    final date =
        "${["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][now.weekday - 1]}, "
        "${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.month - 1]} ${now.day}";
    return date;
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            radius: 23,
            child: Text(
              (guardName != null && guardName!.isNotEmpty)
                  ? guardName![0].toUpperCase()
                  : 'G',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Good day, ${guardName ?? 'Guard'}!",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222B45),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Color(0xFF8F9BB3),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      getTodayLabel(),
                      style: const TextStyle(
                        color: Color(0xFF8F9BB3),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildDashboardHeader(),
          const SizedBox(height: 24),

          // Expanded wrapper to make content non-scrollable
          Expanded(
            child: Column(
              children: [
                // Stats Overview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Summary",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary stats
                      Row(
                        children: [
                          _statCard(
                            "Students Checked In",
                            "42",
                            Icons.login,
                            Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _statCard(
                            "Students Checked Out",
                            "38",
                            Icons.logout,
                            Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _statCard(
                            "Pending Pickups",
                            "4",
                            Icons.people_outline,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Activities - wrapped in Expanded to fill remaining space
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recent Activities",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Activity list - wrapped in Expanded to make it scrollable if needed
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _activityItem(
                                  "RFID Tag",
                                  "Checked out by guardian",
                                  "10:15 AM",
                                  Icons.logout,
                                  Colors.green,
                                ),
                                _divider(),
                                _activityItem(
                                  "RFID Card",
                                  "Checked in by parent",
                                  "8:30 AM",
                                  Icons.login,
                                  Colors.blue,
                                ),
                                _divider(),
                                _activityItem(
                                  "Test Student",
                                  "Pickup denied - unauthorized fetcher",
                                  "3:45 PM",
                                  Icons.block,
                                  Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for stat cards in dashboard
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // Helper widget for activity items
  Widget _activityItem(
    String name,
    String action,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  action,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Divider for list items
  Widget _divider() {
    return Divider(color: Colors.grey[200], height: 1);
  }
}
