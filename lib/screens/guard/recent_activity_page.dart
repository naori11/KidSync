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

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;

    // Set up real-time subscription to the scan_records table with student relationship
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
          return activity.studentName.toLowerCase().contains(
            widget.searchQuery.toLowerCase(),
          );
        }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row, tabs, search, filter
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
                _tableHeaderCell('Reason', flex: 2),
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
                  height: 56,
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
                      _tableCell(
                        Text(
                          activity.status == "Pickup Denied" &&
                                  activity.reason.isNotEmpty
                              ? activity.reason
                              : '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        flex: 2,
                      ),
                      _tableCell(
                        IconButton(
                          icon: Icon(
                            Icons.more_horiz,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: () {},
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
        bg = Color(0xFFE3F2FD); // Light Blue
        fg = Color(0xFF1976D2); // Blue
        break;
      case 'Pickup Approved':
        bg = Color(0xFFE8F5E9); // Light Green
        fg = Color(0xFF388E3C); // Green
        break;
      case 'Pickup Denied':
        bg = Color(0xFFFFEBEE); // Light Red
        fg = Color(0xFFD32F2F); // Red
        break;
      case 'Checked Out':
        bg = Color(0xFFF3E5F5); // Light Purple
        fg = Color(0xFF7B1FA2); // Purple
        break;
      default:
        bg = Color(0xFFECEFF1); // Light Grey
        fg = Color(0xFF455A64); // Grey
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
