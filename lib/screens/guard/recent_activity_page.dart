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
  bool showEarlyDismissalOnly = false;
  bool showEmergencyExitOnly = false;

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

  // Time period helpers
  List<Activity> _applyTimePeriodFilter(List<Activity> input) {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (widget.selectedTimePeriod) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        end = start.add(const Duration(days: 7));
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end =
            (now.month < 12)
                ? DateTime(now.year, now.month + 1, 1)
                : DateTime(now.year + 1, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
    }

    return input.where((a) {
      final ts = a.timestamp;
      if (ts == null) return false;
      // inclusive of start, exclusive of end
      return !ts.isBefore(start) && ts.isBefore(end);
    }).toList();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final timeFiltered = _applyTimePeriodFilter(activities);
        final tempCount =
            timeFiltered.where((a) => a.isTemporaryFetcher).length;
        final earlyCount =
            timeFiltered
                .where((a) => a.isEarlyDismissal || a.isVeryEarlyDismissal)
                .length;
        final emergencyCount =
            timeFiltered.where((a) => a.isEmergencyExit).length;

        String selected =
            showTempFetchersOnly
                ? 'Temp Fetchers'
                : (showEarlyDismissalOnly
                    ? 'Early Dismissal'
                    : (showEmergencyExitOnly ? 'Emergency' : 'All'));

        Widget buildOption({
          required String label,
          String? subtitle,
          required IconData icon,
          required Color color,
        }) {
          return RadioListTile<String>(
            value: label,
            groupValue: selected,
            onChanged: (value) {
              setState(() {
                showTempFetchersOnly = label == 'Temp Fetchers';
                showEarlyDismissalOnly = label == 'Early Dismissal';
                showEmergencyExitOnly = label == 'Emergency';
              });
              Navigator.pop(context);
            },
            activeColor: Colors.green,
            dense: true,
            secondary: Icon(icon, color: color, size: 18),
            title: Text(label),
            subtitle: subtitle != null ? Text(subtitle) : null,
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          showTempFetchersOnly = false;
                          showEarlyDismissalOnly = false;
                          showEmergencyExitOnly = false;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                buildOption(
                  label: 'All',
                  subtitle: 'Show all activities in the selected period',
                  icon: Icons.select_all,
                  color: Colors.grey[600]!,
                ),
                buildOption(
                  label: 'Temp Fetchers',
                  subtitle: 'Only temporary fetchers ($tempCount)',
                  icon: Icons.pin,
                  color: Colors.orange,
                ),
                buildOption(
                  label: 'Early Dismissal',
                  subtitle: 'Only early dismissals ($earlyCount)',
                  icon: Icons.schedule_outlined,
                  color: Colors.amber[700]!,
                ),
                buildOption(
                  label: 'Emergency',
                  subtitle: 'Only emergency exits ($emergencyCount)',
                  icon: Icons.emergency,
                  color: Colors.red[700]!,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply time period filter first
    final List<Activity> timeFiltered = _applyTimePeriodFilter(activities);

    List<Activity> filteredActivities =
        timeFiltered.where((activity) {
          bool matchesSearch = activity.studentName.toLowerCase().contains(
            widget.searchQuery.toLowerCase(),
          );

          bool matchesTempFilter =
              !showTempFetchersOnly || activity.isTemporaryFetcher;

          bool matchesEarlyDismissalFilter =
              !showEarlyDismissalOnly ||
              (activity.isEarlyDismissal || activity.isVeryEarlyDismissal);

          bool matchesEmergencyExitFilter =
              !showEmergencyExitOnly || activity.isEmergencyExit;

          return matchesSearch &&
              matchesTempFilter &&
              matchesEarlyDismissalFilter &&
              matchesEmergencyExitFilter;
        }).toList();

    // Count different activity types
    final tempFetcherCount =
        timeFiltered.where((a) => a.isTemporaryFetcher).length;
    final earlyDismissalCount =
        timeFiltered
            .where((a) => a.isEarlyDismissal || a.isVeryEarlyDismissal)
            .length;
    final emergencyExitCount =
        timeFiltered.where((a) => a.isEmergencyExit).length;

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

              // Temporary Fetcher Filter Toggle (removed in favor of dropdown menu)
              const SizedBox.shrink(),

              SizedBox(width: 8),

              // Emergency Exit Filter Toggle (removed in favor of dropdown menu)
              const SizedBox.shrink(),

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
                    suffixIcon: IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearchChanged('');
                      },
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
              // Prominent dropdown-style Filter button
              Theme(
                data: Theme.of(context).copyWith(
                  // Ensure popup uses clean white like the app theme
                  popupMenuTheme: PopupMenuThemeData(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: TextStyle(color: Colors.grey[800]),
                  ),
                  dividerTheme: DividerThemeData(
                    color: Colors.grey[200],
                    thickness: 1,
                    space: 4,
                  ),
                  // Softer green-ish interactions
                  hoverColor: const Color(0xFF19AE61).withOpacity(0.06),
                  highlightColor: const Color(0xFF19AE61).withOpacity(0.08),
                  splashColor: const Color(0xFF19AE61).withOpacity(0.10),
                  // Defensive: some platforms read from these for menu
                  canvasColor: Colors.white,
                  cardColor: Colors.white,
                ),
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      showTempFetchersOnly = value == 'Temp';
                      showEarlyDismissalOnly = value == 'Early';
                      showEmergencyExitOnly = value == 'Emergency';
                      if (value == 'All') {
                        showTempFetchersOnly = false;
                        showEarlyDismissalOnly = false;
                        showEmergencyExitOnly = false;
                      }
                    });
                  },
                  offset: const Offset(0, 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  constraints: const BoxConstraints(minWidth: 240),
                  itemBuilder: (context) {
                    final bool none =
                        !showTempFetchersOnly &&
                        !showEarlyDismissalOnly &&
                        !showEmergencyExitOnly;
                    return [
                      PopupMenuItem<String>(
                        value: 'All',
                        child: Row(
                          children: [
                            Icon(
                              Icons.select_all,
                              color: Colors.grey[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('All')),
                            if (none)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green[700],
                              ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'Temp',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.pin,
                              color: Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Temp Fetchers ($tempFetcherCount)'),
                            ),
                            if (showTempFetchersOnly)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green[700],
                              ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Early',
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: Colors.amber[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Early Dismissal ($earlyDismissalCount)',
                              ),
                            ),
                            if (showEarlyDismissalOnly)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green[700],
                              ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Emergency',
                        child: Row(
                          children: [
                            Icon(
                              Icons.emergency,
                              color: Colors.red[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Emergency ($emergencyExitCount)'),
                            ),
                            if (showEmergencyExitOnly)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green[700],
                              ),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_list,
                          size: 18,
                          color: Color(0xFF19AE61),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Table with same design as student management
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEEEEEE)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                columnWidths: {
                  0: const FlexColumnWidth(1.5), // Time
                  1: const FlexColumnWidth(2.5), // Student Name
                  2: const FlexColumnWidth(1.5), // Grade/Class
                  3: const FlexColumnWidth(1.5), // Status
                  4: const FlexColumnWidth(2.0), // Verified By
                  5: const FlexColumnWidth(1.0), // Actions
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Table header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                    ),
                    children: [
                      const TableHeaderCell(text: 'Time'),
                      const TableHeaderCell(text: 'Student Name'),
                      const TableHeaderCell(text: 'Grade/Class'),
                      const TableHeaderCell(
                        text: 'Status',
                        alignment: Alignment.center,
                      ),
                      const TableHeaderCell(text: 'Verified By'),
                      const TableHeaderCell(text: 'Actions'),
                    ],
                  ),

                  // Table data rows
                  ...filteredActivities.map((activity) {
                    return TableRow(
                      children: [
                        // Time
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  activity.time,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Student Name
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  activity.studentName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Show special exit type badges
                                    if (activity.isVeryEarlyDismissal) ...[
                                      _buildExitTypeBadge(
                                        'Very Early',
                                        Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                    ] else if (activity.isEarlyDismissal) ...[
                                      _buildExitTypeBadge(
                                        'Early Dismissal',
                                        Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                    ] else if (activity.isEmergencyExit) ...[
                                      _buildExitTypeBadge(
                                        'Emergency',
                                        Colors.red[800]!,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (activity.isTemporaryFetcher) ...[
                                      _buildExitTypeBadge(
                                        'Temp',
                                        Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Grade/Class
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              activity.gradeClass,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        // Status
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: _statusChip(activity.status),
                          ),
                        ),

                        // Verified By
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: _buildVerifiedByWidget(activity),
                          ),
                        ),

                        // Actions
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: IconButton(
                              icon: Icon(
                                Icons.more_horiz,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () => _showActivityDetails(activity),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          // Pagination/footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filteredActivities.length} of ${timeFiltered.length} entries',
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

                    // Additional Information Section for Special Exit Types
                    if (activity.isEarlyDismissal ||
                        activity.isVeryEarlyDismissal ||
                        activity.isEmergencyExit) ...[
                      SizedBox(height: 20),
                      _buildSectionHeader(
                        activity.isEmergencyExit
                            ? 'Emergency Exit Details'
                            : 'Early Dismissal Details',
                        activity.isEmergencyExit
                            ? Icons.emergency
                            : Icons.schedule_outlined,
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              activity.isEmergencyExit
                                  ? Colors.red[50]
                                  : activity.isVeryEarlyDismissal
                                  ? Colors.red[50]
                                  : Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                activity.isEmergencyExit
                                    ? Colors.red[200]!
                                    : activity.isVeryEarlyDismissal
                                    ? Colors.red[200]!
                                    : Colors.amber[200]!,
                          ),
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
                                    color:
                                        activity.isEmergencyExit
                                            ? Colors.red[100]
                                            : activity.isVeryEarlyDismissal
                                            ? Colors.red[100]
                                            : Colors.amber[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activity.isEmergencyExit
                                        ? 'EMERGENCY EXIT'
                                        : activity.isVeryEarlyDismissal
                                        ? 'VERY EARLY DISMISSAL'
                                        : 'EARLY DISMISSAL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          activity.isEmergencyExit
                                              ? Colors.red[700]
                                              : activity.isVeryEarlyDismissal
                                              ? Colors.red[700]
                                              : Colors.amber[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (activity.isEmergencyExit) ...[
                              _detailRowInContainer(
                                'Exit Type',
                                'Emergency Exit (Teacher Approved)',
                              ),
                              if (activity.emergencyExitTeacher != null)
                                _detailRowInContainer(
                                  'Approved By',
                                  'Teacher: ${activity.emergencyExitTeacher}',
                                ),
                              _detailRowInContainer(
                                'Authorization',
                                'Guard Override with Emergency Justification',
                              ),
                            ] else ...[
                              _detailRowInContainer(
                                'Exit Type',
                                activity.isVeryEarlyDismissal
                                    ? 'Very Early Dismissal (2+ hours early)'
                                    : 'Early Dismissal',
                              ),
                              if (activity.dismissalReason != null)
                                _detailRowInContainer(
                                  'Dismissal Reason',
                                  activity.dismissalReason!,
                                ),
                              _detailRowInContainer(
                                'Authorization',
                                activity.isVeryEarlyDismissal
                                    ? 'Guard Override Required'
                                    : 'Section-wide Early Dismissal or Guard Override',
                              ),
                            ],
                            _detailRowInContainer(
                              'Special Processing',
                              'Bypass Normal Schedule Validation',
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
                                    ? (activity.isEmergencyExit ||
                                            activity.isEarlyDismissal ||
                                            activity.isVeryEarlyDismissal
                                        ? 'Guard Override Authorization'
                                        : 'Guard Approval')
                                    : 'RFID Entry'),
                          ),
                          if (activity.isEarlyDismissal ||
                              activity.isVeryEarlyDismissal ||
                              activity.isEmergencyExit)
                            _detailRowInContainer(
                              'Schedule Override',
                              'Schedule validation bypassed - Special authorization',
                            ),
                          _detailRowInContainer(
                            'Processing Status',
                            activity.status,
                          ),
                          _detailRowInContainer(
                            'Timestamp',
                            '${activity.time} - ${DateTime.now().toString().split(' ')[0]}',
                          ),
                          if (activity.isVeryEarlyDismissal)
                            _detailRowInContainer(
                              'Risk Level',
                              'High - Very early dismissal requires special attention',
                            ),
                          if (activity.isEmergencyExit)
                            _detailRowInContainer(
                              'Risk Level',
                              'Critical - Emergency exit requires immediate attention',
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

  Widget _buildExitTypeBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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

// Custom header cell for table (same as student management)
class TableHeaderCell extends StatelessWidget {
  final String text;
  final Alignment alignment;

  const TableHeaderCell({
    super.key,
    required this.text,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      alignment: alignment,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
