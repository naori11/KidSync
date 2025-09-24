import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverProfileTab extends StatefulWidget {
  final VoidCallback logout;

  const DriverProfileTab({required this.logout, Key? key}) : super(key: key);

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  String driverName = 'Loading...';
  String? profileImageUrl;
  String? plateNumber;
  bool isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    final supabase = Supabase.instance.client;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoadingProfile = false);
        return;
      }

      final response =
          await supabase
              .from('users')
              .select('fname, mname, lname, profile_image_url, plate_number')
              .eq('id', user.id)
              .maybeSingle();

      if (response != null) {
        String firstName = response['fname'] ?? '';
        String middleName = response['mname'] ?? '';
        String lastName = response['lname'] ?? '';

        String fullName = '';
        if (firstName.isNotEmpty) fullName += firstName;
        if (middleName.isNotEmpty) fullName += ' $middleName';
        if (lastName.isNotEmpty) fullName += ' $lastName';

        if (fullName.trim().isEmpty) {
          fullName = user.email?.split('@')[0] ?? 'Driver';
        }

        setState(() {
          driverName = fullName.trim();
          profileImageUrl = response['profile_image_url'];
          plateNumber = response['plate_number'];
          isLoadingProfile = false;
        });
      } else {
        setState(() {
          driverName = user.email?.split('@')[0] ?? 'Driver';
          isLoadingProfile = false;
        });
      }
    } catch (error) {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      setState(() {
        driverName = user?.email?.split('@')[0] ?? 'Driver';
        isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color.fromRGBO(25, 174, 97, 0.171),
                radius: 20,
                backgroundImage:
                    profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                child:
                    profileImageUrl == null
                        ? Icon(
                          Icons.person,
                          color: const Color(0xFF19AE61),
                          size: 24,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoadingProfile ? 'Loading...' : driverName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF000000),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF19AE61),
                      ),
                    ),
                    if (plateNumber != null && plateNumber!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Plate: $plateNumber',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF000000).withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: const Color(0xFF000000).withOpacity(0.1)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.logout,
              icon: Icon(
                Icons.logout,
                color: const Color(0xFF19AE61),
                size: 20,
              ),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: const Color(0xFF19AE61),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
