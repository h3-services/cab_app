import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _name = 'Driver';
  String? _profilePhotoPath;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'Driver';
      _profilePhotoPath = prefs.getString('profile_photo_path');
      _profilePhotoUrl = prefs.getString('profile_photo_url');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/chola_cabs_logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade400,
                  backgroundImage: _profilePhotoUrl != null
                      ? NetworkImage(_profilePhotoUrl!)
                      : (_profilePhotoPath != null
                          ? FileImage(File(_profilePhotoPath!)) as ImageProvider
                          : null),
                  child: (_profilePhotoUrl == null && _profilePhotoPath == null)
                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDrawerMenuItem(
                    context,
                    Icons.person_outline,
                    'Profile',
                    'View and edit your personal details',
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    'App preferences, notifications, and privacy',
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                    context,
                    Icons.help_outline,
                    'Help',
                    'Get help and contact the admin for support',
                  ),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                    context,
                    Icons.logout,
                    'Sign out',
                    'Log out of your account safely',
                    isSignOut: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    bool isSignOut = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          if (title == 'Profile') {
            Navigator.pushNamed(context, '/profile');
          } else if (title == 'Settings') {
            Navigator.pushNamed(context, '/settings');
          } else if (title == 'Help') {
            Navigator.pushNamed(context, '/contact-admin');
          } else if (title == 'Sign out') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            }
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignOut ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSignOut ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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
}
