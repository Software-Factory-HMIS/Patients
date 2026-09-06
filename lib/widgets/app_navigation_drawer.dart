import 'package:flutter/material.dart';

class AppNavigationDrawer extends StatelessWidget {
  final Map<String, dynamic> patient;

  const AppNavigationDrawer({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final name = (patient['fullName'] ?? patient['FullName'] ?? 'Patient')
        .toString();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF5B6B9E)),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Close'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
