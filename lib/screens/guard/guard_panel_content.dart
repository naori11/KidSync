import 'package:flutter/material.dart';

// Dummy Data Models
class Student {
  final String name;
  final String imageUrl;
  final String studentId;
  final String emergencyContact;

  Student({
    required this.name,
    required this.imageUrl,
    required this.studentId,
    required this.emergencyContact,
  });
}

class Fetcher {
  final String name;
  final String relationship;
  final String contact;

  Fetcher({
    required this.name,
    required this.relationship,
    required this.contact,
  });
}

class GuardPanelContent extends StatefulWidget {
  const GuardPanelContent({super.key});

  @override
  State<GuardPanelContent> createState() => _GuardPanelContentState();
}

class _GuardPanelContentState extends State<GuardPanelContent> {
  Student? scannedStudent;
  List<Fetcher>? fetchers;
  String? fetchStatus; // "approved", "denied", or null

  void simulateRFIDScan() {
    setState(() {
      scannedStudent = Student(
        name: "Juan Dela Cruz",
        imageUrl: "https://i.pravatar.cc/150?img=3",
        studentId: "20250001",
        emergencyContact: "+63 912 345 6789",
      );

      fetchers = [
        Fetcher(
          name: "Maria Dela Cruz",
          relationship: "Mother",
          contact: "+63 911 223 4567",
        ),
        Fetcher(
          name: "Jose Dela Cruz",
          relationship: "Father",
          contact: "+63 922 333 8888",
        ),
      ];

      fetchStatus = null;
    });
  }

  void clearScan() {
    setState(() {
      scannedStudent = null;
      fetchers = null;
      fetchStatus = null;
    });
  }

  void handleApproval(bool approved) {
    setState(() {
      fetchStatus = approved ? 'approved' : 'denied';
    });

    // Optional: show status for 3 seconds then clear
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        clearScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Guard Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.sync),
              title: Text('Simulate Scan'),
              onTap: simulateRFIDScan,
            ),
            ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Reset'),
              onTap: clearScan,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('Student Pick-up & Drop-off'),
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      body: Row(
        children: [
          // Expanded(
          //   flex: 1,
          //   child: Card(
          //     margin: EdgeInsets.all(12),
          //     child: Center(
          //       child: Column(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         children: [
          //           Icon(Icons.credit_card, size: 80, color: Colors.blueGrey),
          //           SizedBox(height: 12),
          //           Text('RFID Scanner', style: Theme.of(context).textTheme.titleLarge),
          //           SizedBox(height: 8),
          //           Text('Please scan an RFID card'),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child:
                  scannedStudent == null
                      ? Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waiting for Scan',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Divider(),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Name: ____________________",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        Text(
                                          "Student ID: _______________",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Emergency Contact: _________",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Authorized Fetchers',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SizedBox(height: 12),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'No fetcher data. Waiting for RFID...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: null,
                                    icon: Icon(Icons.check),
                                    label: Text("Approve"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade200,
                                      disabledBackgroundColor:
                                          Colors.green.shade200,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: null,
                                    icon: Icon(Icons.close),
                                    label: Text("Deny"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade200,
                                      disabledBackgroundColor:
                                          Colors.red.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      : Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (fetchStatus == 'approved')
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  margin: EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✅ Fetch Approved!',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              if (fetchStatus == 'denied')
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  margin: EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '❌ Fetch Denied!',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              Text(
                                'Student Verified',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Divider(),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: NetworkImage(
                                      scannedStudent!.imageUrl,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Name: ${scannedStudent!.name}",
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        Text(
                                          "Student ID: ${scannedStudent!.studentId}",
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Emergency Contact: ${scannedStudent!.emergencyContact}",
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Authorized Fetchers',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SizedBox(height: 12),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: fetchers!.length,
                                  separatorBuilder: (_, __) => Divider(),
                                  itemBuilder: (context, index) {
                                    final f = fetchers![index];
                                    return ListTile(
                                      leading: Icon(Icons.person),
                                      title: Text(f.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Relationship: ${f.relationship}",
                                          ),
                                          Text("Contact: ${f.contact}"),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => handleApproval(true),
                                    icon: Icon(Icons.check),
                                    label: Text("Approve"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => handleApproval(false),
                                    icon: Icon(Icons.close),
                                    label: Text("Deny"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
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
    );
  }
}
