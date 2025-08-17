import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverAssignmentPage extends StatefulWidget {
  const DriverAssignmentPage({Key? key}) : super(key: key);

  @override
  State<DriverAssignmentPage> createState() => _DriverAssignmentPageState();
}

class _DriverAssignmentPageState extends State<DriverAssignmentPage> {
  final supabase = Supabase.instance.client;
  String _selectedView = 'assignments'; // 'assignments', 'students', 'drivers'
  String _searchQuery = '';
  String _selectedGradeFilter = 'All Grades';
  String _selectedDriverFilter = 'All Drivers';
  String _selectedStatusFilter = 'All Status';
  String _sortOption = 'Student Name (A-Z)';
  bool isLoading = false;

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalPages = 1;

  // Mock data
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> drivers = [];

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  void _initializeMockData() {
    assignments = [
      {
        'id': 1,
        'student_id': '1',
        'student_name': 'Emma Johnson',
        'student_grade': 'Grade 1',
        'student_section': 'Section A',
        'driver_id': '1',
        'driver_name': 'John Smith',
        'vehicle': 'Bus A1',
        'route': 'Route A-1',
        'status': 'active',
        'pickup_time': '07:30',
        'dropoff_time': '15:30',
        'student_address': '123 Maple Street',
      },
      {
        'id': 2,
        'student_id': '2',
        'student_name': 'Liam Smith',
        'student_grade': 'Grade 2',
        'student_section': 'Section B',
        'driver_id': '2',
        'driver_name': 'Sarah Johnson',
        'vehicle': 'Van B2',
        'route': 'Route B-2',
        'status': 'active',
        'pickup_time': '07:45',
        'dropoff_time': '15:45',
        'student_address': '456 Oak Avenue',
      },
      {
        'id': 3,
        'student_id': '3',
        'student_name': 'Olivia Brown',
        'student_grade': 'Grade 1',
        'student_section': 'Section A',
        'driver_id': null,
        'driver_name': null,
        'vehicle': null,
        'route': null,
        'status': 'pending',
        'pickup_time': null,
        'dropoff_time': null,
        'student_address': '789 Pine Road',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.userMetadata?['role'] == 'Admin';

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with title and search/add buttons
                  Row(
                    children: [
                      const Text(
                        "Driver Assignment Management",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const Spacer(),
                      // Search bar
                      Container(
                        width: 300,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search students, drivers...",
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged:
                              (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Add Assignment button
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            "Add Assignment",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed:
                              isAdmin ? () => _showAssignmentDialog() : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bulk Assign button
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.group_add,
                            color: Color(0xFF333333),
                          ),
                          label: const Text(
                            "Bulk Assign",
                            style: TextStyle(color: Color(0xFF333333)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed:
                              isAdmin ? () => _showBulkAssignDialog() : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Export button
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Color(0xFF333333),
                          ),
                          label: const Text(
                            "Export",
                            style: TextStyle(color: Color(0xFF333333)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _exportData(),
                        ),
                      ),
                    ],
                  ),

                  // Enhanced Breadcrumb / subtitle
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 20.0),
                    child: Text(
                      "Home / Driver Assignment Management",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Quick Stats
                  Row(
                    children: [
                      _buildStatCard(
                        'Total Students',
                        '245',
                        Icons.school,
                        const Color(0xFF2ECC71),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Active Drivers',
                        '12',
                        Icons.directions_bus,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Unassigned',
                        '8',
                        Icons.warning,
                        Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Pending',
                        '3',
                        Icons.schedule,
                        Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // View Tabs and Filter row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // View Tabs
                  Row(
                    children: [
                      _buildViewTab(
                        'assignments',
                        'Assignment View',
                        Icons.assignment,
                      ),
                      const SizedBox(width: 16),
                      _buildViewTab('students', 'Students View', Icons.school),
                      const SizedBox(width: 16),
                      _buildViewTab(
                        'drivers',
                        'Drivers View',
                        Icons.directions_bus,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Enhanced Filter row
                  Row(
                    children: [
                      // Grade filter dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGradeFilter,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items:
                                [
                                  'All Grades',
                                  'Grade 1',
                                  'Grade 2',
                                  'Grade 3',
                                  'Grade 4',
                                  'Grade 5',
                                ].map((String item) {
                                  return DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGradeFilter = newValue!;
                                _currentPage = 1;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Driver filter dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDriverFilter,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items:
                                [
                                  'All Drivers',
                                  'John Smith',
                                  'Sarah Johnson',
                                  'Mike Wilson',
                                  'Unassigned',
                                ].map((String item) {
                                  return DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDriverFilter = newValue!;
                                _currentPage = 1;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Status filter dropdown (only for assignments view)
                      if (_selectedView == 'assignments') ...[
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatusFilter,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              items:
                                  [
                                    'All Status',
                                    'Active',
                                    'Pending',
                                    'Inactive',
                                  ].map((String item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text(item),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedStatusFilter = newValue!;
                                  _currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],

                      // Sort by dropdown
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortOption,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items:
                                <String>[
                                  'Student Name (A-Z)',
                                  'Student Name (Z-A)',
                                  'Grade Level',
                                  'Date Created',
                                ].map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text("Sort by: $value"),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              setState(() => _sortOption = newValue!);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content Area
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(String value, String label, IconData icon) {
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedView = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ECC71) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedView) {
      case 'students':
        return _buildStudentsView();
      case 'drivers':
        return _buildDriversView();
      default:
        return _buildAssignmentsView();
    }
  }

  Widget _buildAssignmentsView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: TableHeaderCell(text: 'Student')),
                Expanded(child: TableHeaderCell(text: 'Grade')),
                Expanded(flex: 2, child: TableHeaderCell(text: 'Driver')),
                Expanded(child: TableHeaderCell(text: 'Route')),
                Expanded(child: TableHeaderCell(text: 'Status')),
                Expanded(child: TableHeaderCell(text: 'Schedule')),
                SizedBox(width: 100, child: TableHeaderCell(text: 'Actions')),
              ],
            ),
          ),

          // Table content
          Expanded(
            child: ListView.builder(
              itemCount: 10, // Mock data count
              itemBuilder: (context, index) => _buildAssignmentRow(index),
            ),
          ),

          // Pagination (simplified for now)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Showing 1 to 10 of 10 entries',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: null,
                      color: const Color(0xFFCCCCCC),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: null,
                      color: const Color(0xFFCCCCCC),
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

  Widget _buildAssignmentRow(int index) {
    final students = [
      'Emma Johnson',
      'Liam Smith',
      'Olivia Brown',
      'Noah Davis',
    ];
    final grades = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4'];
    final drivers = [
      'John Smith',
      'Sarah Johnson',
      'Mike Wilson',
      'Unassigned',
    ];
    final routes = ['Route A-1', 'Route B-2', 'Route C-3', 'Not Assigned'];
    final statuses = ['Active', 'Active', 'Active', 'Pending'];

    Color getStatusColor() {
      switch (statuses[index % 4].toLowerCase()) {
        case 'active':
          return Colors.green;
        case 'pending':
          return Colors.orange;
        case 'inactive':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Student Info
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2ECC71).withOpacity(0.1),
                  child: Text(
                    students[index % 4][0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF2ECC71),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        students[index % 4],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        'Student ID: S00${index + 1}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grade
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                grades[index % 4],
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Driver
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drivers[index % 4],
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color:
                        drivers[index % 4] == 'Unassigned'
                            ? Colors.red
                            : const Color(0xFF333333),
                  ),
                ),
                if (drivers[index % 4] != 'Unassigned')
                  Text(
                    'Bus A${index + 1}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Route
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    routes[index % 4] == 'Not Assigned'
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                routes[index % 4],
                style: TextStyle(
                  color:
                      routes[index % 4] == 'Not Assigned'
                          ? Colors.red
                          : Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Status
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: getStatusColor(),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statuses[index % 4].toUpperCase(),
                    style: TextStyle(
                      color: getStatusColor(),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Schedule
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup: 07:${30 + index}0',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'Dropoff: 15:${30 + index}0',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _editAssignment(index),
                  icon: const Icon(Icons.edit, size: 18),
                  color: const Color(0xFF2ECC71),
                  tooltip: 'Edit Assignment',
                ),
                IconButton(
                  onPressed: () => _deleteAssignment(index),
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  tooltip: 'Delete Assignment',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 9, // Mock data
      itemBuilder: (context, index) => _buildStudentCard(index),
    );
  }

  Widget _buildStudentCard(int index) {
    final students = ['Emma Johnson', 'Liam Smith', 'Olivia Brown'];
    final grades = ['Grade 1', 'Grade 2', 'Grade 3'];
    final isAssigned = index % 3 != 0; // Mock assignment status

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF2ECC71).withOpacity(0.1),
              child: Text(
                students[index % 3][0],
                style: const TextStyle(
                  color: Color(0xFF2ECC71),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              students[index % 3],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              grades[index % 3],
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isAssigned
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isAssigned ? 'Assigned' : 'Unassigned',
                style: TextStyle(
                  color: isAssigned ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _assignStudent(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(isAssigned ? 'Reassign' : 'Assign'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6, // Mock data
      itemBuilder: (context, index) => _buildDriverCard(index),
    );
  }

  Widget _buildDriverCard(int index) {
    final drivers = ['John Smith', 'Sarah Johnson', 'Mike Wilson'];
    final studentCounts = [15, 23, 18];
    final routeCounts = [2, 3, 2];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF2ECC71).withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF2ECC71),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drivers[index % 3],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        'Driver ID: D${(index + 1).toString().padLeft(3, '0')}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildDriverStat(
                  '${studentCounts[index % 3]}',
                  'Students',
                  Icons.school,
                  Colors.blue,
                ),
                const SizedBox(width: 20),
                _buildDriverStat(
                  '${routeCounts[index % 3]}',
                  'Routes',
                  Icons.route,
                  Colors.green,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _viewDriverDetails(index),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2ECC71),
                  side: const BorderSide(color: Color(0xFF2ECC71)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverStat(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  // Placeholder methods for functionality (keeping existing implementations)
  void _showAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialog(isEdit: false),
    ).then((result) {
      if (result != null) {
        print('New assignment created: $result');
      }
    });
  }

  void _showBulkAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => const _BulkAssignmentDialog(),
    ).then((result) {
      if (result != null) {
        print('Bulk assignment: $result');
      }
    });
  }

  void _exportData() {
    // TODO: Export functionality
  }

  void _editAssignment(int index) {
    final mockData = {
      'student_id': '1',
      'driver_id': '1',
      'route_id': '1',
      'pickup_address': '123 Main St',
      'dropoff_address': '456 School Ave',
      'status': 'active',
    };

    showDialog(
      context: context,
      builder:
          (context) =>
              _AssignmentDialog(isEdit: true, existingAssignment: mockData),
    ).then((result) {
      if (result != null) {
        print('Assignment updated: $result');
      }
    });
  }

  void _deleteAssignment(int index) {
    final students = [
      'Emma Johnson',
      'Liam Smith',
      'Olivia Brown',
      'Noah Davis',
    ];
    final drivers = [
      'John Smith',
      'Sarah Johnson',
      'Mike Wilson',
      'Unassigned',
    ];

    showDialog(
      context: context,
      builder:
          (context) => _DeleteAssignmentDialog(
            studentName: students[index % 4],
            driverName: drivers[index % 4],
          ),
    ).then((result) {
      if (result == true) {
        print('Assignment deleted for ${students[index % 4]}');
      }
    });
  }

  void _assignStudent(int index) {
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialog(isEdit: false),
    ).then((result) {
      if (result != null) {
        print('Student assigned: $result');
      }
    });
  }

  void _viewDriverDetails(int index) {
    // TODO: Show driver details
  }
}

// Custom header cell for table
class TableHeaderCell extends StatelessWidget {
  final String text;

  const TableHeaderCell({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Color(0xFF666666),
        ),
      ),
    );
  }
}

// 1. CREATE/EDIT Assignment Modal - Remade fields
class _AssignmentDialog extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? existingAssignment;

  const _AssignmentDialog({
    Key? key,
    this.isEdit = false,
    this.existingAssignment,
  }) : super(key: key);

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF2E7D32);

  // Form controllers
  String? selectedStudentId;
  String? selectedDriverId;
  String _status = 'active';
  String _pickupTime = '';
  String _dropoffTime = '';
  String _studentAddress = '';
  List<String> _studentScheduleDays = [];

  // Mock data
  final List<Map<String, dynamic>> _students = [
    {
      'id': '1',
      'name': 'Emma Johnson',
      'grade': 'Grade 1',
      'section': 'Section A',
      'section_id': '3',
      'address': '123 Maple Street, Subdivision A, City',
      'phone': '+1234567890',
    },
    {
      'id': '2',
      'name': 'Liam Smith',
      'grade': 'Grade 2',
      'section': 'Section B',
      'section_id': '4',
      'address': '456 Oak Avenue, Village Heights, City',
      'phone': '+1234567891',
    },
    {
      'id': '3',
      'name': 'Olivia Brown',
      'grade': 'Grade 3',
      'section': 'Section C',
      'section_id': '5',
      'address': '789 Pine Road, Riverside District, City',
      'phone': '+1234567892',
    },
  ];

  final List<Map<String, dynamic>> _drivers = [
    {
      'id': '1',
      'name': 'John Smith',
      'vehicle': 'Bus A1',
      'license': 'DL-12345',
      'phone': '+1987654321',
    },
    {
      'id': '2',
      'name': 'Sarah Johnson',
      'vehicle': 'Van B2',
      'license': 'DL-67890',
      'phone': '+1987654322',
    },
    {
      'id': '3',
      'name': 'Mike Wilson',
      'vehicle': 'Bus C3',
      'license': 'DL-54321',
      'phone': '+1987654323',
    },
  ];

  // Mock schedule data based on section_teachers table
  final Map<String, List<Map<String, dynamic>>> _studentSchedules = {
    '3': [
      // Section A schedule
      {
        'subject': 'Math 101',
        'days': ['Mon', 'Wed', 'Fri'],
        'start_time': '08:00:00',
        'end_time': '09:00:00',
      },
      {
        'subject': 'English 101',
        'days': ['Tue', 'Thu'],
        'start_time': '09:00:00',
        'end_time': '10:00:00',
      },
      {
        'subject': 'Science 101',
        'days': ['Mon', 'Wed', 'Fri'],
        'start_time': '10:00:00',
        'end_time': '11:00:00',
      },
    ],
    '4': [
      // Section B schedule
      {
        'subject': 'Math 102',
        'days': ['Tue', 'Thu'],
        'start_time': '08:00:00',
        'end_time': '09:00:00',
      },
      {
        'subject': 'English 102',
        'days': ['Mon', 'Wed', 'Fri'],
        'start_time': '09:30:00',
        'end_time': '10:30:00',
      },
    ],
    '5': [
      // Section C schedule
      {
        'subject': 'Math 103',
        'days': ['Mon', 'Wed', 'Fri'],
        'start_time': '07:30:00',
        'end_time': '08:30:00',
      },
      {
        'subject': 'English 103',
        'days': ['Tue', 'Thu'],
        'start_time': '08:30:00',
        'end_time': '09:30:00',
      },
      {
        'subject': 'History 103',
        'days': ['Mon', 'Wed', 'Fri'],
        'start_time': '10:00:00',
        'end_time': '11:00:00',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.existingAssignment != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final assignment = widget.existingAssignment!;
    selectedStudentId = assignment['student_id'];
    selectedDriverId = assignment['driver_id'];
    _status = assignment['status'] ?? 'active';

    // Load student data when editing
    if (selectedStudentId != null) {
      _updateStudentData(selectedStudentId!);
    }
  }

  void _updateStudentData(String studentId) {
    final student = _students.firstWhere((s) => s['id'] == studentId);
    final sectionId = student['section_id'];
    final schedule = _studentSchedules[sectionId] ?? [];

    setState(() {
      _studentAddress = student['address'];

      // Get all unique days from student's schedule
      Set<String> allDays = {};
      for (var subject in schedule) {
        allDays.addAll(List<String>.from(subject['days']));
      }
      _studentScheduleDays = allDays.toList()..sort();

      // Calculate pickup and dropoff times
      if (schedule.isNotEmpty) {
        // Earliest start time (pickup should be 30 minutes before)
        var earliestTime = schedule
            .map((s) => s['start_time'] as String)
            .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

        // Latest end time (dropoff should be this time)
        var latestTime = schedule
            .map((s) => s['end_time'] as String)
            .reduce((a, b) => a.compareTo(b) > 0 ? a : b);

        // Convert times and subtract 30 minutes for pickup
        var earliestParts = earliestTime.split(':');
        var earliestMinutes =
            int.parse(earliestParts[0]) * 60 + int.parse(earliestParts[1]);
        var pickupMinutes = earliestMinutes - 30; // 30 minutes before class

        if (pickupMinutes < 0) pickupMinutes = 0; // Don't go before midnight

        var pickupHours = pickupMinutes ~/ 60;
        var pickupMins = pickupMinutes % 60;

        _pickupTime =
            '${pickupHours.toString().padLeft(2, '0')}:${pickupMins.toString().padLeft(2, '0')}';
        _dropoffTime = latestTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isEdit ? Icons.edit : Icons.add_circle,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(widget.isEdit ? 'Edit Assignment' : 'Create Assignment'),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            iconSize: 20,
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Selection
                const Text(
                  'Student Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Select Student',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator:
                      (value) =>
                          value == null ? 'Please select a student' : null,
                  items:
                      _students.map((student) {
                        return DropdownMenuItem<String>(
                          value: student['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                student['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${student['grade']} - ${student['section']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => selectedStudentId = value);
                    if (value != null) {
                      _updateStudentData(value);
                    }
                  },
                ),

                // Student Address Display
                if (_studentAddress.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Student Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _studentAddress,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Driver Selection
                const Text(
                  'Driver Assignment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDriverId,
                  decoration: const InputDecoration(
                    labelText: 'Select Driver',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_bus),
                  ),
                  validator:
                      (value) =>
                          value == null ? 'Please select a driver' : null,
                  items:
                      _drivers.map((driver) {
                        return DropdownMenuItem<String>(
                          value: driver['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                driver['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${driver['vehicle']} - ${driver['license']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged:
                      (value) => setState(() => selectedDriverId = value),
                ),

                const SizedBox(height: 20),

                // Schedule Information (Auto-calculated)
                const Text(
                  'Schedule Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (_studentScheduleDays.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'Auto-Generated Schedule',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'School Days',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _studentScheduleDays.join(', '),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pickup Time',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _pickupTime.isNotEmpty
                                        ? _pickupTime
                                        : 'Not set',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dropoff Time',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _dropoffTime.isNotEmpty
                                        ? _dropoffTime
                                        : 'Not set',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* Pickup time is set 30 minutes before the first class. Dropoff time matches the end of the last class.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Select a student to view schedule',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Student Schedule Details
                if (selectedStudentId != null &&
                    _studentSchedules.containsKey(
                      _students.firstWhere(
                        (s) => s['id'] == selectedStudentId,
                      )['section_id'],
                    )) ...[
                  const Text(
                    'Class Schedule Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Subject',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Days',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Time',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...(_studentSchedules[_students.firstWhere(
                                  (s) => s['id'] == selectedStudentId,
                                )['section_id']] ??
                                [])
                            .map((schedule) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        schedule['subject'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        (schedule['days'] as List).join(', '),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${schedule['start_time']} - ${schedule['end_time']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Status Selection
                const Text(
                  'Assignment Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 12),
                          SizedBox(width: 8),
                          Text('Active'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          SizedBox(width: 8),
                          Text('Inactive'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.orange, size: 12),
                          SizedBox(width: 8),
                          Text('Pending'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAssignment,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            widget.isEdit ? 'Update Assignment' : 'Create Assignment',
          ),
        ),
      ],
    );
  }

  void _saveAssignment() {
    if (_formKey.currentState?.validate() ?? false) {
      if (selectedStudentId == null || selectedDriverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both student and driver'),
          ),
        );
        return;
      }

      final selectedStudent = _students.firstWhere(
        (s) => s['id'] == selectedStudentId,
      );
      final selectedDriver = _drivers.firstWhere(
        (d) => d['id'] == selectedDriverId,
      );

      final assignmentData = {
        'student_id': selectedStudentId,
        'driver_id': selectedDriverId,
        'student_address': _studentAddress,
        'pickup_time': _pickupTime,
        'dropoff_time': _dropoffTime,
        'schedule_days': _studentScheduleDays,
        'status': _status,
        'student_name': selectedStudent['name'],
        'student_phone': selectedStudent['phone'],
        'driver_name': selectedDriver['name'],
        'driver_vehicle': selectedDriver['vehicle'],
        'driver_phone': selectedDriver['phone'],
      };

      Navigator.of(context).pop(assignmentData);
    }
  }
}

// 2. Bulk Assignment Modal - Updated to remove routes
class _BulkAssignmentDialog extends StatefulWidget {
  const _BulkAssignmentDialog({Key? key}) : super(key: key);

  @override
  State<_BulkAssignmentDialog> createState() => _BulkAssignmentDialogState();
}

class _BulkAssignmentDialogState extends State<_BulkAssignmentDialog> {
  final Color primaryColor = const Color(0xFF2E7D32);
  String? selectedDriverId;
  String _filterGrade = 'All';
  String _filterSection = 'All';
  final Set<String> _selectedStudents = {};

  final List<Map<String, dynamic>> _students = [
    {
      'id': '1',
      'name': 'Emma Johnson',
      'grade': 'Grade 1',
      'section': 'Section A',
      'assigned': false,
      'address': '123 Maple Street',
    },
    {
      'id': '2',
      'name': 'Liam Smith',
      'grade': 'Grade 2',
      'section': 'Section B',
      'assigned': true,
      'address': '456 Oak Avenue',
    },
    {
      'id': '3',
      'name': 'Olivia Brown',
      'grade': 'Grade 1',
      'section': 'Section A',
      'assigned': false,
      'address': '789 Pine Road',
    },
    {
      'id': '4',
      'name': 'Noah Davis',
      'grade': 'Grade 3',
      'section': 'Section C',
      'assigned': false,
      'address': '321 Elm Street',
    },
    {
      'id': '5',
      'name': 'Ava Wilson',
      'grade': 'Grade 2',
      'section': 'Section B',
      'assigned': false,
      'address': '654 Birch Lane',
    },
    {
      'id': '6',
      'name': 'William Brown',
      'grade': 'Grade 1',
      'section': 'Section A',
      'assigned': false,
      'address': '987 Cedar Ave',
    },
  ];

  final List<Map<String, dynamic>> _drivers = [
    {'id': '1', 'name': 'John Smith', 'vehicle': 'Bus A1', 'capacity': 25},
    {'id': '2', 'name': 'Sarah Johnson', 'vehicle': 'Van B2', 'capacity': 15},
    {'id': '3', 'name': 'Mike Wilson', 'vehicle': 'Bus C3', 'capacity': 30},
  ];

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((student) {
      if (_filterGrade != 'All' && student['grade'] != _filterGrade)
        return false;
      if (_filterSection != 'All' && student['section'] != _filterSection)
        return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.group_add, color: primaryColor, size: 24),
          const SizedBox(width: 8),
          const Text('Bulk Assignment'),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            iconSize: 20,
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Selection
            const Text(
              'Select Driver',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedDriverId,
              decoration: const InputDecoration(
                labelText: 'Choose Driver for Bulk Assignment',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_bus),
              ),
              items:
                  _drivers.map((driver) {
                    return DropdownMenuItem<String>(
                      value: driver['id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            driver['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${driver['vehicle']} - Capacity: ${driver['capacity']} students',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => selectedDriverId = value),
            ),
            const SizedBox(height: 20),

            // Filters
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _filterGrade,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Grade',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Grades')),
                      DropdownMenuItem(
                        value: 'Grade 1',
                        child: Text('Grade 1'),
                      ),
                      DropdownMenuItem(
                        value: 'Grade 2',
                        child: Text('Grade 2'),
                      ),
                      DropdownMenuItem(
                        value: 'Grade 3',
                        child: Text('Grade 3'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _filterGrade = value!),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _filterSection,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Section',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('All Sections'),
                      ),
                      DropdownMenuItem(
                        value: 'Section A',
                        child: Text('Section A'),
                      ),
                      DropdownMenuItem(
                        value: 'Section B',
                        child: Text('Section B'),
                      ),
                      DropdownMenuItem(
                        value: 'Section C',
                        child: Text('Section C'),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() => _filterSection = value!),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selectedStudents.length} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Student List
            const Text(
              'Select Students:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Select All Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value:
                                _filteredStudents.isNotEmpty &&
                                _filteredStudents
                                    .where((s) => !s['assigned'])
                                    .every(
                                      (s) =>
                                          _selectedStudents.contains(s['id']),
                                    ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedStudents.addAll(
                                    _filteredStudents
                                        .where((s) => !s['assigned'])
                                        .map((s) => s['id'] as String),
                                  );
                                } else {
                                  for (final student in _filteredStudents.where(
                                    (s) => !s['assigned'],
                                  )) {
                                    _selectedStudents.remove(student['id']);
                                  }
                                }
                              });
                            },
                          ),
                          const Text(
                            'Select All Unassigned',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Student List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final isAssigned = student['assigned'] as bool;
                          final isSelected = _selectedStudents.contains(
                            student['id'],
                          );

                          return ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged:
                                  isAssigned
                                      ? null
                                      : (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedStudents.add(
                                              student['id'],
                                            );
                                          } else {
                                            _selectedStudents.remove(
                                              student['id'],
                                            );
                                          }
                                        });
                                      },
                            ),
                            title: Text(
                              student['name'],
                              style: TextStyle(
                                color: isAssigned ? Colors.grey : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${student['grade']} - ${student['section']}',
                                ),
                                Text(
                                  student['address'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing:
                                isAssigned
                                    ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Assigned',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                    : null,
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedStudents.isNotEmpty && selectedDriverId != null
                  ? _performBulkAssignment
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text('Assign ${_selectedStudents.length} Students'),
        ),
      ],
    );
  }

  void _performBulkAssignment() {
    final selectedDriver = _drivers.firstWhere(
      (d) => d['id'] == selectedDriverId,
    );
    final assignmentData = {
      'driver_id': selectedDriverId,
      'driver_name': selectedDriver['name'],
      'driver_vehicle': selectedDriver['vehicle'],
      'student_ids': _selectedStudents.toList(),
      'student_count': _selectedStudents.length,
    };
    Navigator.of(context).pop(assignmentData);
  }
}

// 3. Delete Confirmation Dialog - Simplified
class _DeleteAssignmentDialog extends StatelessWidget {
  final String studentName;
  final String driverName;

  const _DeleteAssignmentDialog({
    Key? key,
    required this.studentName,
    required this.driverName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text('Confirm Deletion'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Are you sure you want to remove this assignment?'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student: $studentName',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Driver: $driverName',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This action cannot be undone.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
