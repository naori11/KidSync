import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/guard_models.dart';

class RecentActivityPage extends StatefulWidget {
  final String searchQuery;
  final String selectedTimePeriod;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final Function(String) onTimePeriodChanged;

  const RecentActivityPage({
    super.key,
    required this.searchQuery,
    required this.selectedTimePeriod,
    required this.searchController,
    required this.onSearchChanged,
    required this.onTimePeriodChanged,
  });

  @override
  _RecentActivityPageState createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends State<RecentActivityPage> {
  List<Activity> activities = [];
  bool isLoading = true;
  late Stream<List<Map<String, dynamic>>> _activityStream;
  bool showTempFetchersOnly = false;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;

    _activityStream =
        supabase
            .from('scan_records')
            .select('''
          scan_time, action, verified_by, status, notes,
          students(id, fname, mname, lname, grade_level, section_id)
        ''')
            .order('scan_time', ascending: false)
            .asStream();

    _activityStream.listen((data) {
      setState(() {
        activities = data.map((item) => Activity.fromJson(item)).toList();
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Activity> filteredActivities =
        activities.where((activity) {
          bool matchesSearch = activity.studentName.toLowerCase().contains(
            widget.searchQuery.toLowerCase(),
          );

          bool matchesTempFilter =
              !showTempFetchersOnly || activity.isTemporaryFetcher;

          return matchesSearch && matchesTempFilter;
        }).toList();

    // Count temporary fetcher activities
    final tempFetcherCount =
        activities.where((a) => a.isTemporaryFetcher).length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with tabs, search, and filters
          Row(
            children: [
              _buildTimePeriodTab(
                'Today',
                widget.selectedTimePeriod == 'Today',
              ),
              _buildTimePeriodTab(
                'This Week',
                widget.selectedTimePeriod == 'This Week',
              ),
              _buildTimePeriodTab(
                'This Month',
                widget.selectedTimePeriod == 'This Month',
              ),
              SizedBox(width: 24),

              // Temporary Fetcher Filter Toggle
              Container(
                decoration: BoxDecoration(
                  color:
                      showTempFetchersOnly
                          ? Colors.orange[50]
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        showTempFetchersOnly
                            ? Colors.orange
                            : Colors.grey[300]!,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      showTempFetchersOnly = !showTempFetchersOnly;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pin,
                          size: 16,
                          color:
                              showTempFetchersOnly
                                  ? Colors.orange
                                  : Colors.grey[600],
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Temp Fetchers ($tempFetcherCount)',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                showTempFetchersOnly
                                    ? Colors.orange
                                    : Colors.grey[700],
                            fontWeight:
                                showTempFetchersOnly
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Spacer(),

              SizedBox(
                width: 250,
                child: TextField(
                  controller: widget.searchController,
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search activities...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(10, 78, 241, 157),
                  foregroundColor: Colors.grey[700],
                  elevation: 0,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {},
                icon: Icon(Icons.filter_list, size: 16),
                label: Text('Filter'),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Table header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                _tableHeaderCell('Time', flex: 2),
                _tableHeaderCell('Student Name', flex: 3),
                _tableHeaderCell('Grade/Class', flex: 2),
                _tableHeaderCell('Status', flex: 2),
                _tableHeaderCell('Verified By', flex: 3),
                _tableHeaderCell('Actions', flex: 1),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),

          // Table body
          Expanded(
            child: ListView.separated(
              itemCount: filteredActivities.length,
              separatorBuilder:
                  (context, i) =>
                      Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                return Container(
                  height: 64, // Slightly taller for temporary fetcher info
                  alignment: Alignment.center,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _tableCell(
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                            SizedBox(width: 8),
                            Text(
                              activity.time,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        flex: 2,
                      ),
                      _tableCell(
                        Text(
                          activity.studentName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        flex: 3,
                      ),
                      _tableCell(
                        Text(
                          activity.gradeClass,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        flex: 2,
                      ),
                      _tableCell(_statusChip(activity.status), flex: 2),
                      _tableCell(_buildVerifiedByWidget(activity), flex: 3),
                      _tableCell(
                        IconButton(
                          icon: Icon(
                            Icons.more_horiz,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: () => _showActivityDetails(activity),
                        ),
                        flex: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Pagination/footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filteredActivities.length} of ${activities.length} entries',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.chevron_left, color: Colors.grey[400]),
                      iconSize: 20,
                    ),
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      iconSize: 20,
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

  Widget _buildVerifiedByWidget(Activity activity) {
    if (activity.isTemporaryFetcher) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pin, size: 12, color: Colors.orange[700]),
                    SizedBox(width: 4),
                    Text(
                      'TEMP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  activity.tempFetcherName ?? 'Unknown',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            activity.tempFetcherRelationship ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      return Text(
        activity.verifiedBy,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  // Update the _showActivityDetails method to fetch official fetcher information correctly
  void _showActivityDetails(Activity activity) async {
    // Fetch additional fetcher information if it's not a temporary fetcher
    Map<String, dynamic>? officialFetcherDetails;

    if (!activity.isTemporaryFetcher && activity.action == 'exit') {
      try {
        // First, get the student information to find the student ID
        final studentNameParts = activity.studentName.split(' ');
        final firstName =
            studentNameParts.isNotEmpty ? studentNameParts[0] : '';
        final lastName =
            studentNameParts.length > 1 ? studentNameParts.last : '';

        // Find the student by name to get student ID
        final studentResponse =
            await Supabase.instance.client
                .from('students')
                .select('id')
                .eq('fname', firstName)
                .eq('lname', lastName)
                .maybeSingle();

        if (studentResponse != null) {
          final studentId = studentResponse['id'];

          // Get the parent-student relationships for this student
          final parentStudentResponse = await Supabase.instance.client
              .from('parent_student')
              .select('''
                parent_id,
                relationship_type,
                is_primary
              ''')
              .eq('student_id', studentId);

          if (parentStudentResponse.isNotEmpty) {
            // Get the parent IDs
            final parentIds =
                parentStudentResponse
                    .map((rel) => rel['parent_id'])
                    .toSet()
                    .toList();

            // Fetch parent details
            final parentsResponse = await Supabase.instance.client
                .from('parents')
                .select('''
                id,
                fname,
                mname,
                lname,
                phone,
                email,
                address,
                status
              ''')
                .inFilter('id', parentIds)
                .eq('status', 'active');

            if (parentsResponse.isNotEmpty) {
              // Find the primary parent or use the first one
              final parentData = parentsResponse.first;
              final relationshipData = parentStudentResponse.firstWhere(
                (rel) => rel['parent_id'] == parentData['id'],
                orElse: () => parentStudentResponse.first,
              );

              officialFetcherDetails = {
                'fetcher_name':
                    '${parentData['fname']} ${parentData['mname'] ?? ''} ${parentData['lname']}'
                        .trim(),
                'relationship':
                    relationshipData['relationship_type'] ?? 'Parent',
                'contact_number': parentData['phone'] ?? '',
                'email': parentData['email'] ?? '',
                'address': parentData['address'] ?? '',
                'is_primary': relationshipData['is_primary'] ?? false,
              };
            }
          }
        }
      } catch (e) {
        print('Error fetching official fetcher details: $e');
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  activity.isTemporaryFetcher ? Icons.pin : Icons.info,
                  color:
                      activity.isTemporaryFetcher ? Colors.orange : Colors.blue,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Activity Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Container(
              width: 500,
              constraints: BoxConstraints(maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Information Section
                    _buildSectionHeader('Student Information', Icons.person),
                    _detailRow('Student Name', activity.studentName),
                    _detailRow('Grade/Class', activity.gradeClass),
                    _detailRow('Time', activity.time),
                    _detailRow('Status', activity.status),
                    _detailRow('Action', activity.action.toUpperCase()),

                    SizedBox(height: 20),

                    // Fetcher Information Section
                    if (activity.isTemporaryFetcher) ...[
                      _buildSectionHeader(
                        'Temporary Fetcher Details',
                        Icons.pin,
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'TEMPORARY FETCHER',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _detailRowInContainer(
                              'Fetcher Name',
                              activity.tempFetcherName ?? 'Unknown',
                            ),
                            _detailRowInContainer(
                              'Relationship',
                              activity.tempFetcherRelationship ?? 'Unknown',
                            ),
                            _detailRowInContainer(
                              'PIN Used',
                              activity.tempFetcherPin ?? 'Unknown',
                            ),
                            _detailRowInContainer(
                              'Verification Type',
                              'One-time PIN',
                            ),
                          ],
                        ),
                      ),
                    ] else if (officialFetcherDetails != null) ...[
                      _buildSectionHeader(
                        'Official Fetcher Details',
                        Icons.verified_user,
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    officialFetcherDetails['is_primary'] == true
                                        ? 'PRIMARY PARENT'
                                        : 'AUTHORIZED PARENT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _detailRowInContainer(
                              'Fetcher Name',
                              officialFetcherDetails['fetcher_name'] ??
                                  'Unknown',
                            ),
                            _detailRowInContainer(
                              'Relationship',
                              officialFetcherDetails['relationship'] ??
                                  'Unknown',
                            ),
                            _detailRowInContainer(
                              'Contact Number',
                              officialFetcherDetails['contact_number'] ??
                                  'Not provided',
                            ),
                            _detailRowInContainer(
                              'Email',
                              officialFetcherDetails['email'] ?? 'Not provided',
                            ),
                            _detailRowInContainer(
                              'Address',
                              officialFetcherDetails['address'] ??
                                  'Not provided',
                            ),
                            _detailRowInContainer(
                              'Verification Type',
                              'Pre-authorized Parent',
                            ),
                          ],
                        ),
                      ),
                    ] else if (activity.action == 'exit') ...[
                      _buildSectionHeader(
                        'Fetcher Information',
                        Icons.person_outline,
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fetcher details not available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Verified by: ${activity.verifiedBy.isNotEmpty ? activity.verifiedBy : 'System'}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Additional Notes Section
                    if (activity.reason.isNotEmpty) ...[
                      SizedBox(height: 20),
                      _buildSectionHeader('Additional Notes', Icons.note),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          activity.reason,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],

                    // Security Information Section
                    SizedBox(height: 20),
                    _buildSectionHeader('Security Information', Icons.security),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRowInContainer(
                            'Record Type',
                            activity.action == 'exit'
                                ? 'Student Pickup'
                                : 'Student Entry',
                          ),
                          _detailRowInContainer(
                            'Verification Method',
                            activity.isTemporaryFetcher
                                ? 'PIN Verification'
                                : (activity.action == 'exit'
                                    ? 'Guard Approval'
                                    : 'RFID Entry'),
                          ),
                          _detailRowInContainer(
                            'Processing Status',
                            activity.status,
                          ),
                          _detailRowInContainer(
                            'Timestamp',
                            '${activity.time} - ${DateTime.now().toString().split(' ')[0]}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (activity.action == 'exit')
                ElevatedButton.icon(
                  onPressed: () {
                    // You can add functionality to print or export this record
                    Navigator.pop(context);
                    _showExportDialog(activity);
                  },
                  icon: Icon(Icons.print, size: 16),
                  label: Text('Print Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
            ],
          ),
    );
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for detail rows in containers
  Widget _detailRowInContainer(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Add export dialog functionality
  void _showExportDialog(Activity activity) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Export Record'),
            content: Text(
              'Export options for ${activity.studentName}\'s record:',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Implement PDF export functionality here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export functionality coming soon!'),
                    ),
                  );
                },
                child: Text('Export as PDF'),
              ),
            ],
          ),
    );
  }

  // Update the existing _detailRow method to handle the regular dialog sections
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _tableCell(Widget child, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: child,
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    String label = status;

    switch (status) {
      case 'Entry Recorded':
        bg = Color(0xFFE3F2FD);
        fg = Color(0xFF1976D2);
        break;
      case 'Pickup Approved':
        bg = Color(0xFFE8F5E9);
        fg = Color(0xFF388E3C);
        break;
      case 'Pickup Denied':
        bg = Color(0xFFFFEBEE);
        fg = Color(0xFFD32F2F);
        break;
      case 'Checked Out':
        bg = Color(0xFFF3E5F5);
        fg = Color(0xFF7B1FA2);
        break;
      default:
        bg = Color(0xFFECEFF1);
        fg = Color(0xFF455A64);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTimePeriodTab(String title, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => widget.onTimePeriodChanged(title),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey[300]!,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
