import 'package:flutter/material.dart';

class DriverProfileTab extends StatelessWidget {
  final VoidCallback logout;

  const DriverProfileTab({required this.logout, Key? key}) : super(key: key);

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
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF19AE61),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF19AE61),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(color: const Color(0xFF000000).withOpacity(0.1)),
          const SizedBox(height: 8),
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: logout,
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
