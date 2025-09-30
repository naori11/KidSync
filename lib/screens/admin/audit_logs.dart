import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/services/audit_log_service.dart';
import 'package:intl/intl.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({Key? key}) : super(key: key);

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final supabase = Supabase.instance.client;
  final auditLogService = AuditLogService();
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'All Roles';
  String _userFilter = 'All Users';
  String _actionTypeFilter = 'All Actions';
  String _statusFilter = 'All Status';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFilterSidebarOpen = false;

  // Real audit log entries from database
  List<Map<String, dynamic>> _logEntries = [];

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

    try {
      // Fetch audit logs from database using the service
      final logs = await auditLogService.getAuditLogs(
        limit: 100,
        offset: 0,
      );

      // Transform the database records to match the expected UI format
      final transformedLogs = logs.map((log) {
        return {
          'timestamp': DateTime.parse(log['created_at']),
          'user': {
            'name': log['user_name'],
            'role': log['user_role'],
            'id': log['user_id'],
          },
          'action': log['action_description'],
          'actionType': log['action_type'],
          'module': log['module'],
          'status': log['status'],
          'details': log['action_description'],
          'ipAddress': log['ip_address']?.toString() ?? 'Unknown',
          'target_type': log['target_type'],
          'target_id': log['target_id'],
          'target_name': log['target_name'],
        };
      }).toList();

      setState(() {
        _logEntries = transformedLogs;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching audit logs: $e');
      // Keep empty list if error occurs
      setState(() {
        _logEntries = [];
        isLoading = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audit logs: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    // Optionally refetch data with new filters
    _applyFiltersAndRefresh();
  }

  /// Apply current filters and refresh data from database
  Future<void> _applyFiltersAndRefresh() async {
    setState(() => isLoading = true);

    try {
      final logs = await auditLogService.getAuditLogs(
        limit: 200,
        offset: 0,
        actionType: _actionTypeFilter != 'All Actions' ? _actionTypeFilter : null,
        status: _statusFilter != 'All Status' ? _statusFilter : null,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final transformedLogs = logs.map((log) {
        return {
          'timestamp': DateTime.parse(log['created_at']),
          'user': {
            'name': log['user_name'],
            'role': log['user_role'],
            'id': log['user_id'],
          },
          'action': log['action_description'],
          'actionType': log['action_type'],
          'module': log['module'],
          'status': log['status'],
          'details': log['action_description'],
          'ipAddress': log['ip_address']?.toString() ?? 'Unknown',
          'target_type': log['target_type'],
          'target_id': log['target_id'],
          'target_name': log['target_name'],
        };
      }).toList();

      setState(() {
        _logEntries = transformedLogs;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching filtered audit logs: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          // Main content
          Padding(
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
                  child: isLoading
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
          
          // Filter Sidebar Overlay
          if (_isFilterSidebarOpen) ...[
            // Dark overlay with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withOpacity(_isFilterSidebarOpen ? 0.5 : 0.0),
              width: double.infinity,
              height: double.infinity,
              child: GestureDetector(
                onTap: () => setState(() => _isFilterSidebarOpen = false),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            // Sidebar
            _buildFilterSidebar(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive Header
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 700;

            final Widget filterButton = Container(
              height: 44,
              decoration: BoxDecoration(
                color: _hasActiveFilters() ? const Color(0xFF2ECC71) : Colors.white,
                border: Border.all(color: const Color(0xFF2ECC71), width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _isFilterSidebarOpen = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list, color: _hasActiveFilters() ? Colors.white : const Color(0xFF2ECC71), size: 18),
                        const SizedBox(width: 8),
                        Text('Filters',
                            style: TextStyle(
                              color: _hasActiveFilters() ? Colors.white : const Color(0xFF2ECC71),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            )),
                        if (_hasActiveFilters()) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: Text('${_getActiveFilterCount()}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );

            final Widget searchField = Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search logs...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF2ECC71), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                ),
              ),
            );

            final Widget exportButton = SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, color: Color(0xFF2ECC71), size: 18),
                label: const Text("Export",
                    style: TextStyle(color: Color(0xFF2ECC71), fontSize: 14, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export functionality coming soon...'), backgroundColor: Colors.orange),
                  );
                },
              ),
            );

            if (!isCompact) {
              return Row(
                children: [
                  const Text(
                    "Audit Logs",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: 0.5),
                  ),
                  const Spacer(),
                  filterButton,
                  const SizedBox(width: 12),
                  SizedBox(width: 260, child: searchField),
                  const SizedBox(width: 12),
                  exportButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Audit Logs",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    filterButton,
                    const SizedBox(width: 12),
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    exportButton,
                  ],
                ),
              ],
            );
          },
        ),
        // Standardized Breadcrumb
        const Padding(
          padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
          child: Text(
            "Home / Audit Logs",
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ),

        // Active filter summary (when filters are applied)
        if (_hasActiveFilters()) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.05),
              border: Border.all(
                color: const Color(0xFF2ECC71).withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt,
                  size: 16,
                  color: const Color(0xFF2ECC71).withOpacity(0.8),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Active filters:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _getActiveFilterBadges(),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _roleFilter = 'All Roles';
                      _userFilter = 'All Users';
                      _actionTypeFilter = 'All Actions';
                      _statusFilter = 'All Status';
                      _startDate = null;
                      _endDate = null;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.clear,
                    size: 14,
                    color: Color(0xFF666666),
                  ),
                  label: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // Helper method to build consistent filter dropdowns
  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    IconData icon,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 16,
                color: const Color(0xFF2ECC71),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  // Get user filter options from log entries
  List<String> _getUserFilterOptions() {
    final users = <String>{'All Users'};
    for (var log in _logEntries) {
      final userName = log['user']['name'] as String;
      users.add(userName);
    }
    return users.toList()..sort();
  }

  // Build date range picker
  Widget _buildDateRangePicker() {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date Range',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF2ECC71),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF2ECC71),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _startDate != null ? dateFormat.format(_startDate!) : 'Start Date',
                              style: TextStyle(
                                fontSize: 14,
                                color: _startDate != null ? const Color(0xFF1A1A1A) : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                          if (_startDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _startDate = null),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'to',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF2ECC71),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Color(0xFF2ECC71),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _endDate != null ? dateFormat.format(_endDate!) : 'End Date',
                              style: TextStyle(
                                fontSize: 14,
                                color: _endDate != null ? const Color(0xFF1A1A1A) : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                          if (_endDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _endDate = null),
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Quick filter shortcuts
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Quick Filters:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              _buildQuickFilterChip('Today', () {
                final today = DateTime.now();
                setState(() {
                  _startDate = DateTime(today.year, today.month, today.day);
                  _endDate = DateTime(today.year, today.month, today.day);
                });
              }),
              const SizedBox(width: 8),
              _buildQuickFilterChip('Last 7 Days', () {
                final today = DateTime.now();
                setState(() {
                  _startDate = today.subtract(const Duration(days: 7));
                  _endDate = today;
                });
              }),
              const SizedBox(width: 8),
              _buildQuickFilterChip('Errors Only', () {
                setState(() {
                  _statusFilter = 'error';
                });
              }),
              const SizedBox(width: 8),
              _buildQuickFilterChip('Admin Actions', () {
                setState(() {
                  _roleFilter = 'Admin';
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        if (isCompact) {
          // Use card layout on small screens; hide table header
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text(
                  'Date & Time',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'User & Role',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Action & Type',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Module',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  'Details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF424242), letterSpacing: 0.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogsList() {
    // Apply all filters to log entries
    final filteredLogs = _logEntries.where((log) {
      final logDate = log['timestamp'] as DateTime;
      
      // Date range filter
      if (_startDate != null) {
        final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (logDate.isBefore(startOfDay)) return false;
      }
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (logDate.isAfter(endOfDay)) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final String searchableContent =
            '${log['user']['name']} ${log['action']} ${log['module']} ${log['details']}'
                .toLowerCase();
        if (!searchableContent.contains(_searchQuery)) return false;
      }

      // Role filter
      if (_roleFilter != 'All Roles' && log['user']['role'] != _roleFilter) {
        return false;
      }

      // User filter
      if (_userFilter != 'All Users' && log['user']['name'] != _userFilter) {
        return false;
      }

      // Action type filter
      if (_actionTypeFilter != 'All Actions' && log['actionType'] != _actionTypeFilter) {
        return false;
      }

      // Status filter
      if (_statusFilter != 'All Status' && log['status'] != _statusFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort by timestamp (newest first)
    filteredLogs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search criteria',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Showing ${filteredLogs.length} log ${filteredLogs.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // Quick filter badges
                if (_hasActiveFilters()) ...[
                  const Text(
                    'Active filters: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 4,
                    children: _getActiveFilterBadges(),
                  ),
                ],
              ],
            ),
          ),
          // Log entries
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                return ListView.builder(
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    if (isCompact) {
                      return _buildLogCard(log);
                    }
                    return _buildLogEntry(log, index % 2 == 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Check if any filters are active
  bool _hasActiveFilters() {
    return _roleFilter != 'All Roles' ||
           _userFilter != 'All Users' ||
           _actionTypeFilter != 'All Actions' ||
           _statusFilter != 'All Status' ||
           _startDate != null ||
           _endDate != null ||
           _searchQuery.isNotEmpty;
  }

  // Get active filter badges
  List<Widget> _getActiveFilterBadges() {
    final badges = <Widget>[];
    
    if (_roleFilter != 'All Roles') {
      badges.add(_buildFilterBadge(_roleFilter));
    }
    if (_userFilter != 'All Users') {
      badges.add(_buildFilterBadge(_userFilter));
    }
    if (_actionTypeFilter != 'All Actions') {
      badges.add(_buildFilterBadge(_actionTypeFilter));
    }
    if (_statusFilter != 'All Status') {
      badges.add(_buildFilterBadge(_statusFilter));
    }
    if (_startDate != null || _endDate != null) {
      badges.add(_buildFilterBadge('Date Range'));
    }
    if (_searchQuery.isNotEmpty) {
      badges.add(_buildFilterBadge('Search'));
    }
    
    return badges;
  }

  // Get count of active filters
  int _getActiveFilterCount() {
    int count = 0;
    if (_roleFilter != 'All Roles') count++;
    if (_userFilter != 'All Users') count++;
    if (_actionTypeFilter != 'All Actions') count++;
    if (_statusFilter != 'All Status') count++;
    if (_startDate != null || _endDate != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  // Shorten long action text previews for the table so it doesn't crowd other columns.
  // Always append an ellipsis so all rows visually end the same way.
  String _shortenAction(String text, {int max = 32}) {
    final t = text.trim();
    if (max <= 0) return '...';
    final base = t.length <= max ? t : t.substring(0, max);
    return base.trimRight() + '...';
  }

  // Build the floating filter sidebar
  Widget _buildFilterSidebar() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: math.min(400.0, MediaQuery.of(context).size.width * 0.9),
        transform: Matrix4.translationValues(
          _isFilterSidebarOpen ? 0 : math.min(400.0, MediaQuery.of(context).size.width * 0.9),
          0,
          0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Sidebar Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2ECC71),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Options',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _isFilterSidebarOpen = false),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),

            // Sidebar Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clear all filters button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _roleFilter = 'All Roles';
                            _userFilter = 'All Users';
                            _actionTypeFilter = 'All Actions';
                            _statusFilter = 'All Status';
                            _startDate = null;
                            _endDate = null;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear_all, size: 18, color: Color(0xFF666666)),
                        label: const Text('Clear All Filters',
                            style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Role Filter
                    _buildSidebarFilterSection(
                      'User Role',
                      Icons.admin_panel_settings,
                      _buildFilterDropdown(
                        'Role',
                        _roleFilter,
                        ['All Roles', 'Admin', 'Teacher', 'Guard', 'Driver', 'Parent', 'System'],
                        Icons.admin_panel_settings,
                        (value) => setState(() => _roleFilter = value!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // User Filter
                    _buildSidebarFilterSection(
                      'Specific User',
                      Icons.person,
                      _buildFilterDropdown(
                        'User',
                        _userFilter,
                        _getUserFilterOptions(),
                        Icons.person,
                        (value) => setState(() => _userFilter = value!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Type Filter
                    _buildSidebarFilterSection(
                      'Action Type',
                      Icons.assignment,
                      _buildFilterDropdown(
                        'Action Type',
                        _actionTypeFilter,
                        ['All Actions', 'Create', 'Update', 'Delete', 'View', 'Export', 'Security', 'Alert', 'System'],
                        Icons.assignment,
                        (value) => setState(() => _actionTypeFilter = value!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Status Filter
                    _buildSidebarFilterSection(
                      'Status',
                      Icons.info_outline,
                      _buildFilterDropdown(
                        'Status',
                        _statusFilter,
                        ['All Status', 'success', 'warning', 'error'],
                        Icons.info_outline,
                        (value) => setState(() => _statusFilter = value!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Date Range Filter
                    _buildSidebarFilterSection(
                      'Date Range',
                      Icons.calendar_today,
                      _buildDateRangePicker(),
                    ),

                    const SizedBox(height: 24),

                    // Quick filter shortcuts
                    _buildSidebarFilterSection(
                      'Quick Filters',
                      Icons.speed,
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickFilterButton('Today', () {
                                  final today = DateTime.now();
                                  setState(() {
                                    _startDate = DateTime(today.year, today.month, today.day);
                                    _endDate = DateTime(today.year, today.month, today.day);
                                  });
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildQuickFilterButton('Last 7 Days', () {
                                  final today = DateTime.now();
                                  setState(() {
                                    _startDate = today.subtract(const Duration(days: 7));
                                    _endDate = today;
                                  });
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickFilterButton('Errors Only', () {
                                  setState(() {
                                    _statusFilter = 'error';
                                  });
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildQuickFilterButton('Admin Actions', () {
                                  setState(() {
                                    _roleFilter = 'Admin';
                                  });
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sidebar Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: const Border(
                  top: BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_getActiveFilterCount()} filter${_getActiveFilterCount() == 1 ? '' : 's'} active',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _isFilterSidebarOpen = false),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w600),
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

  // Build sidebar filter section
  Widget _buildSidebarFilterSection(String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF2ECC71),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // Build quick filter button for sidebar
  Widget _buildQuickFilterButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF2ECC71)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2ECC71),
          ),
        ),
      ),
    );
  }

  // Build individual filter badge
  Widget _buildFilterBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2ECC71).withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2ECC71),
        ),
      ),
    );
  }

  // Build compact mobile card for a single log entry
  Widget _buildLogCard(Map<String, dynamic> log) {
    final timestamp = log['timestamp'] as DateTime;
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('HH:mm');
    final status = log['status'] as String;
    final role = log['user']['role'] as String;

    Color getRoleColor(String role) {
      switch (role) {
        case 'Admin':
          return const Color(0xFF9C27B0);
        case 'Teacher':
          return const Color(0xFF2196F3);
        case 'Guard':
          return const Color(0xFFFF9800);
        case 'Driver':
          return const Color(0xFF4CAF50);
        case 'Parent':
          return const Color(0xFFE91E63);
        case 'System':
          return const Color(0xFF607D8B);
        default:
          return const Color(0xFF757575);
      }
    }

    Widget statusPill(String status) {
      Color color;
      String label;
      switch (status) {
        case 'success':
          color = const Color(0xFF2ECC71);
          label = 'Success';
          break;
        case 'warning':
          color = const Color(0xFFF39C12);
          label = 'Warning';
          break;
        case 'error':
          color = const Color(0xFFE74C3C);
          label = 'Error';
          break;
        default:
          color = Colors.grey;
          label = 'Unknown';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${dateFormatter.format(timestamp)}  ${timeFormatter.format(timestamp)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A1A))),
              statusPill(status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(log['user']['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A1A)),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: getRoleColor(role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: getRoleColor(role).withOpacity(0.3), width: 0.5),
                ),
                child: Text(role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: getRoleColor(role))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(log['module'], style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF2ECC71).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(log['actionType'],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF2ECC71))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log['details'],
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              color: Colors.white,
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 18),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _showLogDetails(log);
                    break;
                  case 'copy':
                    _copyLogDetails(log);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(children: [Icon(Icons.visibility, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), const Text('View Details')]),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(children: [Icon(Icons.copy, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), const Text('Copy Info')]),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, bool isEvenRow) {
    final timestamp = log['timestamp'] as DateTime;
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('HH:mm');
    final status = log['status'] as String;
    final role = log['user']['role'] as String;

    // Define role colors
    Color getRoleColor(String role) {
      switch (role) {
        case 'Admin':
          return const Color(0xFF9C27B0);
        case 'Teacher':
          return const Color(0xFF2196F3);
        case 'Guard':
          return const Color(0xFFFF9800);
        case 'Driver':
          return const Color(0xFF4CAF50);
        case 'Parent':
          return const Color(0xFFE91E63);
        case 'System':
          return const Color(0xFF607D8B);
        default:
          return const Color(0xFF757575);
      }
    }

    // Define status colors and icons
    Widget getStatusIndicator(String status) {
      switch (status) {
        case 'success':
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2ECC71),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Success',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2ECC71),
                ),
              ),
            ],
          );
        case 'warning':
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Warning',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF39C12),
                ),
              ),
            ],
          );
        case 'error':
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE74C3C),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE74C3C),
                ),
              ),
            ],
          );
        default:
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Timestamp column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormatter.format(timestamp),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 3),
                Text(
                  timeFormatter.format(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),

          // User & Role column
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['user']['name'],
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getRoleColor(role).withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(role,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: getRoleColor(role))),
                ),
              ],
            ),
          ),

          // Action & Type column
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortenAction(log['action'].toString(), max: 32),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF2ECC71).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(log['actionType'],
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF2ECC71))),
                ),
              ],
            ),
          ),

          // Module column
          Expanded(
            flex: 2,
            child: Text(
              log['module'],
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status column
          Expanded(
            flex: 2,
            child: getStatusIndicator(status),
          ),

          // Details column
          Expanded(
            flex: 6,
            child: Text(
              log['details'],
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          // Actions column
          SizedBox(
            width: 60,
            child: PopupMenuButton<String>(
              color: Colors.white,
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey.shade600,
                size: 18,
              ),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _showLogDetails(log);
                    break;
                  case 'copy':
                    _copyLogDetails(log);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      const Text('View Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      const Text('Copy Info'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show detailed log information in a dialog
  void _showLogDetails(Map<String, dynamic> log) {
    final timestamp = log['timestamp'] as DateTime;
    final dateTimeFormatter = DateFormat('MMM d, yyyy \'at\' HH:mm:ss');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFF2ECC71),
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Log Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: math.min(500.0, MediaQuery.of(context).size.width - 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Timestamp', dateTimeFormatter.format(timestamp)),
              _buildDetailRow('User', log['user']['name']),
              _buildDetailRow('Role', log['user']['role']),
              _buildDetailRow('User ID', log['user']['id']),
              _buildDetailRow('Action', log['action']),
              _buildDetailRow('Action Type', log['actionType']),
              _buildDetailRow('Module', log['module']),
              _buildDetailRow('Status', log['status']),
              _buildDetailRow('IP Address', log['ipAddress'] ?? 'N/A'),
              const SizedBox(height: 8),
              const Text(
                'Details:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  log['details'],
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Copy log details to clipboard
  void _copyLogDetails(Map<String, dynamic> log) {
    final timestamp = log['timestamp'] as DateTime;
    final dateTimeFormatter = DateFormat('MMM d, yyyy \'at\' HH:mm:ss');
    
    final logText = '''
Log Entry Details:
Timestamp: ${dateTimeFormatter.format(timestamp)}
User: ${log['user']['name']}
Role: ${log['user']['role']}
User ID: ${log['user']['id']}
Action: ${log['action']}
Action Type: ${log['actionType']}
Module: ${log['module']}
Status: ${log['status']}
IP Address: ${log['ipAddress'] ?? 'N/A'}
Details: ${log['details']}
''';

    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log details copied to clipboard'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  // Build quick filter chip
  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2ECC71)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2ECC71),
          ),
        ),
      ),
    );
  }
}
