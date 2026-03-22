import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/driver_theme.dart';

class DriverRecentActivity extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverRecentActivity({
    required this.primaryColor,
    required this.isMobile,
    super.key,
  });

  @override
  State<DriverRecentActivity> createState() => _DriverRecentActivityState();
}

class _DriverRecentActivityState extends State<DriverRecentActivity> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  Map<String, List<Map<String, dynamic>>> _groupedLogs = {};
  String _selectedFilter = 'all'; // 'all', 'pickup', 'dropoff', 'today'

  @override
  void initState() {
    super.initState();
    _loadRecentActivity();
  }

  Future<void> _loadRecentActivity() async {
    try {
      setState(() => _isLoading = true);
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Skip audit logging as table may not exist
      // This prevents 404 errors without breaking functionality

      var query = supabase
          .from('pickup_dropoff_logs')
          .select('''
            id,
            event_type,
            pickup_time,
            dropoff_time,
            created_at,
            notes,
            students!inner(
              id, fname, mname, lname, grade_level, profile_image_url,
              sections(name)
            )
          ''')
          .eq('driver_id', user.id);

      // Apply filters
      if (_selectedFilter == 'pickup') {
        query = query.eq('event_type', 'pickup');
      } else if (_selectedFilter == 'dropoff') {
        query = query.eq('event_type', 'dropoff');
      } else if (_selectedFilter == 'today') {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50); // Increased limit for better data

      final logs = List<Map<String, dynamic>>.from(response);

      // Group logs by date
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final log in logs) {
        final createdAt = DateTime.parse(log['created_at']);
        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(log);
      }

      setState(() {
        _logs = logs;
        _groupedLogs = grouped;
      });
    } catch (e) {
      print('Error loading recent activity: $e');
      _showErrorSnackBar('Failed to load recent activity');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: DriverTheme.errorRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadRecentActivity,
          ),
        ),
      );
    }
  }

  void _changeFilter(String filter) {
    if (filter != _selectedFilter) {
      setState(() {
        _selectedFilter = filter;
      });
      _loadRecentActivity();
    }
  }

  String _formatTime(dynamic time) {
    try {
      final dt = DateTime.parse((time ?? '').toString());
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatDate(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateToCheck = DateTime(date.year, date.month, date.day);

      if (dateToCheck == today) {
        return 'Today';
      } else if (dateToCheck == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE, MMM d, yyyy').format(date);
      }
    } catch (_) {
      return dateKey;
    }
  }

  String _getRelativeTime(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      }
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return RefreshIndicator(
      color: widget.primaryColor,
      onRefresh: _loadRecentActivity,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: DriverTheme.contentPadding(widget.isMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: DriverTheme.cardBorderRadius(widget.isMobile),
              ),
              elevation: 6,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: DriverTheme.white,
                  borderRadius: DriverTheme.cardBorderRadius(widget.isMobile),
                  boxShadow: DriverTheme.cardShadow(widget.primaryColor),
                ),
                child: Padding(
                  padding: DriverTheme.cardPadding(widget.isMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: DriverTheme.greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.update,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Recent Activity',
                            style: DriverTheme.subHeaderTextStyle(
                              widget.isMobile,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            color: widget.primaryColor,
                            onPressed: _loadRecentActivity,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),

                      // Filter Chips - Professional alignment
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('today', 'Today'),
                            const SizedBox(width: 8),
                            _buildFilterChip('pickup', 'Pickups'),
                            const SizedBox(width: 8),
                            _buildFilterChip('dropoff', 'Dropoffs'),
                          ],
                        ),
                      ),

                      SizedBox(height: widget.isMobile ? 12 : 16),

                      // Summary Stats - Professional alignment
                      if (_logs.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Total Activities',
                                  _logs.length.toString(),
                                  Icons.timeline,
                                  widget.primaryColor,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Pickups',
                                  _logs
                                      .where((l) => l['event_type'] == 'pickup')
                                      .length
                                      .toString(),
                                  Icons.directions_car,
                                  Colors.blue[600]!,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Dropoffs',
                                  _logs
                                      .where(
                                        (l) => l['event_type'] == 'dropoff',
                                      )
                                      .length
                                      .toString(),
                                  Icons.home,
                                  Colors.green[600]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Activity Content
            if (_logs.isEmpty)
              Card(
                child: Padding(
                  padding: DriverTheme.cardPadding(widget.isMobile),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: DriverTheme.greyMedium,
                        size: widget.isMobile ? 16 : 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getEmptyMessage(),
                          style: DriverTheme.bodyTextStyle(
                            widget.isMobile,
                          ).copyWith(color: DriverTheme.greyMedium),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._buildGroupedActivities(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    final isToday = filter == 'today';

    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isToday
                      ? Colors.white
                      : widget.primaryColor.withOpacity(0.1))
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected
                    ? (isToday ? widget.primaryColor : widget.primaryColor)
                    : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _changeFilter(filter),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      isSelected
                          ? (isToday
                              ? widget.primaryColor
                              : widget.primaryColor)
                          : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: widget.isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: widget.isMobile ? 11 : 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper method to get student profile image
  NetworkImage? _getStudentProfileImage(Map<String, dynamic> student) {
    final profileImageUrl = student['profile_image_url'];
    if (profileImageUrl != null && profileImageUrl.toString().isNotEmpty) {
      return NetworkImage(profileImageUrl.toString());
    }
    return null;
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'pickup':
        return 'No pickup activities found.';
      case 'dropoff':
        return 'No dropoff activities found.';
      case 'today':
        return 'No activities recorded today.';
      default:
        return 'No recent activity yet.';
    }
  }

  List<Widget> _buildGroupedActivities() {
    final widgets = <Widget>[];
    final sortedDates =
        _groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final dateKey in sortedDates) {
      final dayLogs = _groupedLogs[dateKey]!;

      // Date Header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: widget.primaryColor),
              const SizedBox(width: 8),
              Text(
                _formatDate(dateKey),
                style: DriverTheme.subHeaderTextStyle(
                  widget.isMobile,
                ).copyWith(color: widget.primaryColor),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '${dayLogs.length}',
                  style: DriverTheme.captionTextStyle(widget.isMobile).copyWith(
                    color: widget.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Activity Items for this date
      for (final log in dayLogs) {
        widgets.add(_buildEnhancedActivityItem(log));
      }
    }

    return widgets;
  }

  Widget _buildEnhancedActivityItem(Map<String, dynamic> log) {
    final String eventType = (log['event_type'] ?? '').toString();
    final student = log['students'] ?? {};
    final String firstName = (student['fname'] ?? '').toString();
    final String middleName = (student['mname'] ?? '').toString();
    final String lastName = (student['lname'] ?? '').toString();

    final String studentName = [
      firstName,
      middleName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');

    final String gradeLevel = (student['grade_level'] ?? '').toString();
    final String sectionName = (student['sections']?['name'] ?? '').toString();
    final String notes = (log['notes'] ?? '').toString();
    final String createdAt = (log['created_at'] ?? '').toString();

    final dynamic eventTime =
        eventType == 'pickup' ? log['pickup_time'] : log['dropoff_time'];

    final bool isPickup = eventType == 'pickup';
    final Color eventColor =
        isPickup ? widget.primaryColor : DriverTheme.successGreen;
    final IconData eventIcon = isPickup ? Icons.directions_car : Icons.home;
    final String actionText = isPickup ? 'Picked up' : 'Dropped off';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: eventColor.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: eventColor.withOpacity(0.1),
                    backgroundImage: _getStudentProfileImage(student),
                    child:
                        _getStudentProfileImage(student) == null
                            ? Icon(eventIcon, color: eventColor, size: 18)
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$actionText $studentName',
                          style: DriverTheme.bodyTextStyle(
                            widget.isMobile,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (gradeLevel.isNotEmpty || sectionName.isNotEmpty)
                          Text(
                            [
                              gradeLevel,
                              sectionName,
                            ].where((s) => s.isNotEmpty).join(' • '),
                            style: DriverTheme.captionTextStyle(
                              widget.isMobile,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(eventTime),
                        style: DriverTheme.bodyTextStyle(
                          widget.isMobile,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          color: eventColor,
                        ),
                      ),
                      Text(
                        _getRelativeTime(createdAt),
                        style: DriverTheme.captionTextStyle(widget.isMobile),
                      ),
                    ],
                  ),
                ],
              ),

              // Additional Details
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: DriverTheme.greyMedium),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notes: $notes',
                        style: DriverTheme.captionTextStyle(widget.isMobile),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
