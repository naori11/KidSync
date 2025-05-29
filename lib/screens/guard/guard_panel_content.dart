import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;
final userName = user?.userMetadata?['full_name'] ?? 'User';

// Dummy Data Models
class Student {
  final String name;
  final String imageUrl;
  final String studentId;
  final String emergencyContact;
  final String grade;
  final String section;

  Student({
    required this.name,
    required this.imageUrl,
    required this.studentId,
    required this.emergencyContact,
    required this.grade,
    required this.section,
  });
}

class Fetcher {
  final String name;
  final String imageUrl;
  final String relationship;
  final String contact;
  final bool authorized;

  Fetcher({
    required this.name,
    required this.imageUrl,
    required this.relationship,
    required this.contact,
    this.authorized = true,
  });
}

class GuardPanelContent extends StatefulWidget {
  const GuardPanelContent({super.key});

  @override
  State<GuardPanelContent> createState() => _GuardPanelContentState();
}

class _GuardPanelContentState extends State<GuardPanelContent> {
  int selectedIndex = 0;
  Student? scannedStudent;
  List<Fetcher>? fetchers;
  String? fetchStatus; // "approved", "denied", or null
  bool showNotification = false;
  String notificationMessage = '';
  Color notificationColor = Colors.green;
  DateTime? actionTimestamp;

  @override
  void initState() {
    super.initState();
    // No context-dependent code here
  }

  // Define navigation items - moved out of initState
  List<_NavItem> get navItems => [
    _NavItem("Dashboard", Icons.dashboard_outlined),
    _NavItem("Student Verification", Icons.verified_outlined),
    _NavItem("Scan RFID", Icons.credit_card),
    _NavItem("Logout", Icons.logout),
  ];

  void simulateRFIDScan() {
    setState(() {
      scannedStudent = Student(
        name: "Sarah Johnson",
        imageUrl: "https://i.pravatar.cc/150?img=5",
        studentId: "STU-2024-0123",
        emergencyContact: "+1 (555) 123-4567",
        grade: "8",
        section: "A",
      );

      fetchers = [
        Fetcher(
          name: "Michael Johnson",
          imageUrl: "https://i.pravatar.cc/150?img=3",
          relationship: "Father",
          contact: "+1 (555) 0123",
        ),
        Fetcher(
          name: "Emma Smith",
          imageUrl: "https://i.pravatar.cc/150?img=13",
          relationship: "Fetcher",
          contact: "+1 (555) 0123",
        ),
        Fetcher(
          name: "Sarah Wilsom",
          imageUrl: "https://i.pravatar.cc/150?img=3",
          relationship: "Guardian",
          contact: "+1 (555) 0123",
        ),
      ];

      fetchStatus = null;
      showNotification = false;

      // Switch to verification tab automatically
      setState(() {
        selectedIndex = 1;
      });
    });
  }

  void clearScan() {
    setState(() {
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
      showNotification = false;
    });
  }

  void handleApproval(bool approved) {
    final now = DateTime.now();
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      fetchStatus = approved ? 'approved' : 'denied';

      // Show notification
      showNotification = true;
      notificationMessage =
          approved
              ? 'Pickup approved at $formattedTime'
              : 'Pickup denied at $formattedTime';
      notificationColor = approved ? Colors.green : Colors.red;
      actionTimestamp = now;
    });

    // Optional: hide notification after a few seconds
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          showNotification = false;
        });
      }
    });

    // Optional: clear scan after some time
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        clearScan();
      }
    });
  }

  // Function to handle logout
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await supabase.auth.signOut();

      // Navigate to login screen and clear the navigation stack
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  // Dashboard content
  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Header Section
          Text(
            "Guard Dashboard",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

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

          // Recent Activities
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
                  "Recent Activities",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Activity list
                _activityItem(
                  "Sarah Johnson",
                  "Checked out by parent (John Johnson)",
                  "10:15 AM",
                  Icons.logout,
                  Colors.green,
                ),
                _divider(),
                _activityItem(
                  "Michael Smith",
                  "Checked in by guardian (Mary Smith)",
                  "8:30 AM",
                  Icons.login,
                  Colors.blue,
                ),
                _divider(),
                _activityItem(
                  "Emma Davis",
                  "Checked out by approved pickup (Tom Wilson)",
                  "3:45 PM",
                  Icons.logout,
                  Colors.green,
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

  // Updated Student verification content based on the image
  Widget _buildVerificationContent() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Student info
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Verification',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan RFID card to verify student',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 24),

                    // RFID Card box or Student info
                    if (scannedStudent == null)
                      _buildRfidScanBox()
                    else
                      _buildStudentInfoBox(),
                  ],
                ),
              ),

              SizedBox(width: 24),

              // Right side - Fetchers list
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authorized Fetcher',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 16),

                    if (fetchers != null)
                      Expanded(
                        child: ListView.builder(
                          itemCount: fetchers!.length,
                          itemBuilder: (context, index) {
                            final fetcher = fetchers![index];
                            return _buildFetcherCard(fetcher);
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Text(
                            'No student scanned',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 16),

                    if (scannedStudent != null)
                      Column(
                        children: [
                          _buildActionButton(
                            onPressed: () => handleApproval(true),
                            icon: Icons.check_circle_outline,
                            label: "Approve Pick-up",
                            color: Colors.green,
                          ),
                          SizedBox(height: 12),
                          _buildActionButton(
                            onPressed: () => handleApproval(false),
                            icon: Icons.cancel_outlined,
                            label: "Deny Pick-up",
                            color: Colors.red,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Floating notification
        if (showNotification) _buildFloatingNotification(),
      ],
    );
  }

  // Floating notification widget
  Widget _buildFloatingNotification() {
    final formattedDate =
        actionTimestamp != null
            ? "${actionTimestamp!.year}-${actionTimestamp!.month.toString().padLeft(2, '0')}-${actionTimestamp!.day.toString().padLeft(2, '0')}"
            : '';

    return Positioned(
      top: 24,
      right: 24,
      child: AnimatedOpacity(
        opacity: showNotification ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notificationColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                fetchStatus == 'approved' ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fetchStatus == 'approved'
                        ? 'Pickup Approved'
                        : 'Pickup Denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '$formattedDate | ${notificationMessage.split(' at ')[1]}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Record saved to database',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              InkWell(
                onTap: () {
                  setState(() {
                    showNotification = false;
                  });
                },
                child: Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRfidScanBox() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[100]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contact_page, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Tap RFID Card',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        // Empty student placeholder - matches style
        Container(
          height: 320,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 150,
                  height: 150,
                  color: Colors.grey[200],
                  child: Icon(Icons.person, size: 80, color: Colors.grey[400]),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: 120,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student ID',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),

            SizedBox(height: 16),
            Text(
              'Emergency Contact',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentInfoBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  scannedStudent!.imageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 16),
              Text(
                scannedStudent!.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Grade ${scannedStudent!.grade} - Section ${scannedStudent!.section}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Student ID
        Text(
          'Student ID',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Text(
            scannedStudent!.studentId,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),

        SizedBox(height: 16),

        // Emergency Contact
        Text(
          'Emergency Contact',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Text(
            scannedStudent!.emergencyContact,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildFetcherCard(Fetcher fetcher) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                fetcher.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fetcher.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Relationship: ${fetcher.relationship}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Contact: ${fetcher.contact}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'AUTHORIZED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // RFID scan content
  Widget _buildScanRFIDContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.credit_card, size: 80, color: Colors.blueGrey),
                    SizedBox(height: 16),
                    Text(
                      'RFID Scanner',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Please scan an RFID card to verify a student',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: simulateRFIDScan,
                      icon: Icon(Icons.sync),
                      label: Text('Simulate RFID Scan'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: clearScan,
                      icon: Icon(Icons.refresh),
                      label: Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation - copied from admin panel layout
          Container(
            width: 180,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Text(
                    "KidSync",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Navigation items
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final item = navItems[index];

                      // Add extra spacing before logout
                      if (item.label == "Logout" && index > 0) {
                        return Column(
                          children: [
                            SizedBox(height: 16),
                            _buildNavItem(item, index),
                          ],
                        );
                      }

                      return _buildNavItem(item, index);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(child: _getContentForIndex(selectedIndex)),
        ],
      ),
    );
  }

  // Helper method to get content based on selected index
  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildVerificationContent();
      case 2:
        return _buildScanRFIDContent();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavItem(_NavItem item, int index) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () {
        // If it's the logout button
        if (item.label == "Logout") {
          _handleLogout(context);
        } else {
          setState(() => selectedIndex = index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  _NavItem(this.label, this.icon);
}
