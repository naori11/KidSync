import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({Key? key}) : super(key: key);

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock data for demonstration
  final List<Map<String, dynamic>> _logEntries = [
    {
      'timestamp': DateTime(2024, 1, 20, 10, 15),
      'user': {'name': 'Mary Johnson', 'role': 'Admin'},
      'action': 'Created new class',
      'module': 'Class Management',
      'status': 'success',
      'details': 'Created Class 5B for Academic Year 2024',
    },
    {
      'timestamp': DateTime(2024, 1, 20, 11, 00),
      'user': {'name': 'Robert Wilson', 'role': 'Guard'},
      'action': 'dadadwdawdawd',
      'module': 'dadadaw',
      'status': 'success',
      'details': 'Accessed attendance history for Student ID: 5878',
    },
    {
      'timestamp': DateTime(2024, 1, 20, 11, 45),
      'user': {'name': 'Sarah Davis', 'role': 'Teacher'},
      'action': 'Marked attendance',
      'module': 'Attendance',
      'status': 'success',
      'details': 'Marked attendance for Class 3A',
    },
    {
      'timestamp': DateTime(2024, 1, 20, 13, 20),
      'user': {'name': 'James Brown', 'role': 'Admin'},
      'action': 'Deleted user account',
      'module': 'User Management',
      'status': 'error',
      'details': 'Removed inactive user account ID: 9012',
    },
    {
      'timestamp': DateTime(2024, 1, 19, 9, 30),
      'user': {'name': 'Emma Wilson', 'role': 'Admin'},
      'action': 'Updated system settings',
      'module': 'System',
      'status': 'success',
      'details': 'Changed notification settings',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() => isLoading = true);

    // In a real app, fetch from Supabase
    // For now, we'll use mock data defined above

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => isLoading = false);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and filter header
            _buildHeader(),

            const SizedBox(height: 24),

            // Table header
            _buildTableHeader(),

            const SizedBox(height: 16),

            // Table content
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                        ),
                      )
                      : _buildLogsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Standardized Header
        Row(
          children: [
            const Text(
              "Audit Logs",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // Standardized Search bar
            Container(
              width: 260,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search logs...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF2ECC71),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Standardized Export button
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.file_download_outlined,
                  color: Color(0xFF2ECC71),
                  size: 18,
                ),
                label: const Text(
                  "Export",
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFF2ECC71),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export functionality coming soon...'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Standardized Breadcrumb
        const Padding(
          padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
          child: Text(
            "Home / Audit Logs",
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Timestamp column
          SizedBox(
            width: 120,
            child: Text(
              'Timestamp',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // User column
          SizedBox(
            width: 150,
            child: Text(
              'User',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Action column
          SizedBox(
            width: 150,
            child: Text(
              'Action',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Module column
          SizedBox(
            width: 150,
            child: Text(
              'Module',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Status column
          SizedBox(
            width: 80,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Details column
          Expanded(
            child: Text(
              'Details',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    // Filter log entries based on search query
    final filteredLogs =
        _logEntries.where((log) {
          if (_searchQuery.isEmpty) return true;

          final String searchableContent =
              '${log['user']['name']} ${log['action']} ${log['module']} ${log['details']}'
                  .toLowerCase();

          return searchableContent.contains(_searchQuery);
        }).toList();

    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildLogEntry(log, index % 2 == 0);
      },
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, bool isEvenRow) {
    final timestamp = log['timestamp'] as DateTime;
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : const Color(0xFFF9F9F9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Timestamp column
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormatter.format(timestamp),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeFormatter.format(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // User column
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['user']['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log['user']['role'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Action column
          SizedBox(
            width: 150,
            child: Text(
              log['action'],
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Module column
          SizedBox(
            width: 150,
            child: Text(
              log['module'],
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),

          // Status column
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        log['status'] == 'success'
                            ? const Color(0xFF2ECC71)
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Details column
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    log['details'],
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Actions menu
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onPressed: () {
                    // Show actions menu
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
