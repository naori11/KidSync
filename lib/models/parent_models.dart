// Update your AuthorizedFetcher model to include profileImageUrl
class AuthorizedFetcher {
  final String id;
  final String name;
  final String relationship;
  final String? phone;
  final String? email;
  final bool isPrimary;
  final bool isActive;
  final String? profileImageUrl;

  AuthorizedFetcher({
    required this.id,
    required this.name,
    required this.relationship,
    this.phone,
    this.email,
    required this.isPrimary,
    required this.isActive,
    this.profileImageUrl,
  });

  factory AuthorizedFetcher.fromJson(Map<String, dynamic> json) {
    final parent = json['parents'];
    final users = parent['users'];

    return AuthorizedFetcher(
      id: parent['id'].toString(),
      name:
          '${parent['fname'] ?? ''} ${parent['mname'] ?? ''} ${parent['lname'] ?? ''}'
              .trim(),
      relationship: json['relationship_type'] ?? 'Parent',
      phone: parent['phone'],
      email: parent['email'],
      isPrimary: json['is_primary'] ?? false,
      isActive: parent['status'] == 'active',
      profileImageUrl: users['profile_image_url'], // Extract profile image URL
    );
  }
}
