class AuthorizedFetcher {
  final int id;
  final String name;
  final String relationship;
  final String contact;
  final bool isPrimary;
  final bool isActive;

  AuthorizedFetcher({
    required this.id,
    required this.name,
    required this.relationship,
    required this.contact,
    required this.isPrimary,
    required this.isActive,
  });

  factory AuthorizedFetcher.fromJson(Map<String, dynamic> json) {
    final parentData = json['parents'];
    final fname = parentData['fname'] ?? '';
    final mname = parentData['mname'] ?? '';
    final lname = parentData['lname'] ?? '';
    final fullName = '$fname${mname.isNotEmpty ? ' $mname' : ''} $lname'.trim();
    
    return AuthorizedFetcher(
      id: parentData['id'],
      name: fullName,
      relationship: json['relationship_type'] ?? 'Parent',
      contact: parentData['phone'] ?? parentData['email'] ?? 'No contact',
      isPrimary: json['is_primary'] ?? false,
      isActive: (parentData['status'] ?? 'active') == 'active',
    );
  }
}