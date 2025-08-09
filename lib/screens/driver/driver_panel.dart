import 'package:flutter/material.dart';

class DriverPanel extends StatefulWidget {
  const DriverPanel({Key? key}) : super(key: key);

  @override
  State<DriverPanel> createState() => _DriverPanelState();
}

class _DriverPanelState extends State<DriverPanel> {
  int selectedIndex = 0;

  static const Color primaryGreen = Color(0xFF19AE61);
  static const Color black = Color(0xFF000000);
  static const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.171);
  static const Color white = Color(0xFFFFFFFF);

  final List<_NavItem> navItems = const [
    _NavItem('Dashboard', Icons.dashboard, 'dashboard'),
    _NavItem('Pick-up/Drop-off', Icons.directions_car, 'pickup'),
    _NavItem('Students', Icons.group, 'students'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar
              Container(
                color: white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(
                        Icons.local_shipping,
                        color: primaryGreen,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    // Notification Bell
                    Stack(
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          color: black,
                          size: 28,
                        ),
                        Positioned(
                          right: 0,
                          top: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const CircleAvatar(
                      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
                      radius: 16,
                      child: Icon(Icons.person, color: primaryGreen, size: 18),
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: _buildTabContent(selectedIndex),
                  ),
                ),
              ),
              // Bottom Navigation Bar
              Container(
                color: white,
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(navItems.length, (i) {
                    final item = navItems[i];
                    final bool selected = i == selectedIndex;
                    return IconButton(
                      icon: Icon(
                        item.icon,
                        color: selected ? primaryGreen : black.withOpacity(0.6),
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() => selectedIndex = i);
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return _EmptySection(label: 'Dashboard');
      case 1:
        return _EmptySection(label: 'Pick-up/Drop-off');
      case 2:
        return _EmptySection(label: 'Students');
      default:
        return const SizedBox.shrink();
    }
  }
}

class _EmptySection extends StatelessWidget {
  final String label;
  const _EmptySection({required this.label, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Text(
        '$label section (empty)',
        style: const TextStyle(fontSize: 20, color: Color(0xFF000000)),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}
