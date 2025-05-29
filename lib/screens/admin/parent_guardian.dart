import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentGuardianPage extends StatefulWidget {
  const ParentGuardianPage({super.key});

  @override
  State<ParentGuardianPage> createState() => _ParentGuardianPageState();
}

class _ParentGuardianPageState extends State<ParentGuardianPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> parents = [];
  bool isLoading = false;
  String _searchQuery = '';

  Map<String, dynamic>? _selectedParent;
  bool _showDetailModal = false;

  @override
  void initState() {
    super.initState();
    _fetchParents();
  }

  Future<void> _fetchParents() async {
    setState(() => isLoading = true);

    // This is mock data for demo purposes
    // In a real app, fetch from Supabase: await supabase.from('parents').select();
    final mockParents = [
      {
        'id': 1,
        'first_name': 'John',
        'last_name': 'Smith',
        'phone': '+1 (555) 123-4567',
        'email': 'john.s@email.com',
        'student_count': 2,
        'students': [
          {
            'first_name': 'Emma',
            'last_name': 'Smith',
            'grade': 2,
            'section': 'C',
            'fetchers': ['John Smith'],
            'drivers': ['James Wilson'],
            'guardians': ['Lisa Smith'],
          },
          {
            'first_name': 'Jacob',
            'last_name': 'Smith',
            'grade': 'Kindergarten',
            'section': 'A',
            'fetchers': ['John Smith'],
            'drivers': ['James Wilson'],
            'guardians': ['Lisa Smith'],
          },
        ],
      },
      {
        'id': 2,
        'first_name': 'Sarah',
        'last_name': 'Johnson',
        'phone': '+1 (555) 234-5678',
        'email': 'sarah.j@email.com',
        'student_count': 1,
        'students': [
          {
            'first_name': 'Michael',
            'last_name': 'Johnson',
            'grade': 1,
            'section': 'B',
            'fetchers': ['Sarah Johnson'],
            'drivers': ['David Johnson'],
            'guardians': ['Sarah Johnson'],
          },
        ],
      },
      {
        'id': 3,
        'first_name': 'Robert',
        'last_name': 'Williams',
        'phone': '+1 (555) 345-6789',
        'email': 'robert.w@email.com',
        'student_count': 2,
        'students': [
          {
            'first_name': 'Sophia',
            'last_name': 'Williams',
            'grade': 3,
            'section': 'A',
            'fetchers': ['Robert Williams'],
            'drivers': ['Patricia Williams'],
            'guardians': ['Robert Williams'],
          },
          {
            'first_name': 'William',
            'last_name': 'Williams',
            'grade': 'Preschool',
            'section': 'B',
            'fetchers': ['Robert Williams'],
            'drivers': ['Patricia Williams'],
            'guardians': ['Robert Williams'],
          },
        ],
      },
      {
        'id': 4,
        'first_name': 'James',
        'last_name': 'Brown',
        'phone': '+1 (555) 456-7890',
        'email': 'james.b@email.com',
        'student_count': 1,
        'students': [
          {
            'first_name': 'Olivia',
            'last_name': 'Brown',
            'grade': 4,
            'section': 'A',
            'fetchers': ['James Brown'],
            'drivers': ['Mary Brown'],
            'guardians': ['James Brown'],
          },
        ],
      },
    ];

    setState(() {
      parents = mockParents;
      isLoading = false;
    });
  }

  void _showParentDetails(Map<String, dynamic> parent) {
    setState(() {
      _selectedParent = parent;
      _showDetailModal = true;
    });
  }

  void _closeDetailModal() {
    setState(() {
      _showDetailModal = false;
      _selectedParent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter parents by search query
    final filteredParents =
        parents.where((parent) {
          final fullName =
              "${parent['first_name']} ${parent['last_name']}".toLowerCase();
          return fullName.contains(_searchQuery.toLowerCase());
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Stack(
        children: [
          // Main Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search and Add button row
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search parents...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF9E9E9E),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.0,
                            ),
                          ),
                          onChanged:
                              (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Add New Parent button
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          "Add New Parent",
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
                        onPressed: () {
                          // Add parent functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Add parent functionality would go here',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Parent Cards Grid
                Expanded(
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2ECC71),
                            ),
                          )
                          : filteredParents.isEmpty
                          ? const Center(child: Text("No parents found"))
                          : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16.0,
                                  mainAxisSpacing: 16.0,
                                  childAspectRatio: 1.5,
                                ),
                            itemCount: filteredParents.length,
                            itemBuilder: (context, index) {
                              final parent = filteredParents[index];
                              final fullName =
                                  "${parent['first_name']} ${parent['last_name']}";
                              final initial = parent['first_name'][0];

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Avatar with initial
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey[300],
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Name
                                      Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),

                                      // Phone
                                      Text(
                                        parent['phone'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Student count
                                      Text(
                                        "${parent['student_count']} Students",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // View Details button
                                      OutlinedButton(
                                        onPressed:
                                            () => _showParentDetails(parent),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Color(0xFF2ECC71),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'View Details',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF2ECC71),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward,
                                              size: 16,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),

          // Parent Details Modal
          if (_showDetailModal && _selectedParent != null)
            _buildParentDetailModal(),
        ],
      ),
    );
  }

  Widget _buildParentDetailModal() {
    final parent = _selectedParent!;
    final students = parent['students'] as List;
    final fullName = "${parent['first_name']} ${parent['last_name']}";
    final initial = parent['first_name'][0];

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with initial
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Name and details
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Parent',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parent['email'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _closeDetailModal,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Associated Students Section
                const Text(
                  'Associated Students',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Student list
                Expanded(
                  child: ListView.separated(
                    itemCount: students.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final studentName =
                          "${student['first_name']} ${student['last_name']}";
                      final studentInitial = student['first_name'][0];
                      final grade = student['grade'];
                      final section = student['section'];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student info row
                          Row(
                            children: [
                              // Student initial
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: Text(
                                  studentInitial,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Student details
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$grade - Section $section',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Fetchers, Drivers, Guardians
                          _buildContactRow('Fetchers:', student['fetchers']),
                          const SizedBox(height: 8),
                          _buildContactRow('Drivers:', student['drivers']),
                          const SizedBox(height: 8),
                          _buildContactRow('Guardians:', student['guardians']),

                          // View more link
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () {
                                // View more functionality
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Text(
                                'View more',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2ECC71),
                                ),
                              ),
                              label: const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Color(0xFF2ECC71),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(String label, List<dynamic> people) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            people.join(', '),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
