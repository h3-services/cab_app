import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationTracking = true;
  bool _autoAcceptTrips = false;
  String _language = 'English';
  String _theme = 'Light';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _locationTracking = prefs.getBool('location_tracking') ?? true;
      _autoAcceptTrips = prefs.getBool('auto_accept_trips') ?? false;
      _language = prefs.getString('language') ?? 'English';
      _theme = prefs.getString('theme') ?? 'Light';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('location_tracking', _locationTracking);
    await prefs.setBool('auto_accept_trips', _autoAcceptTrips);
    await prefs.setString('language', _language);
    await prefs.setString('theme', _theme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSection(
            'Notifications',
            [
              _buildSwitchTile(
                'Push Notifications',
                'Receive trip requests and updates',
                _notificationsEnabled,
                (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            'Location & Tracking',
            [
              _buildSwitchTile(
                'Location Tracking',
                'Allow app to track your location',
                _locationTracking,
                (value) {
                  setState(() {
                    _locationTracking = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            'Trip Preferences',
            [
              _buildSwitchTile(
                'Auto Accept Trips',
                'Automatically accept incoming trip requests',
                _autoAcceptTrips,
                (value) {
                  setState(() {
                    _autoAcceptTrips = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            'App Preferences',
            [
              _buildDropdownTile(
                'Language',
                'Select your preferred language',
                _language,
                ['English', 'Tamil', 'Hindi'],
                (value) {
                  setState(() {
                    _language = value!;
                  });
                  _saveSettings();
                },
              ),
              _buildDropdownTile(
                'Theme',
                'Choose app appearance',
                _theme,
                ['Light', 'Dark', 'System'],
                (value) {
                  setState(() {
                    _theme = value!;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            'Support',
            [
              _buildActionTile(
                'Help & Support',
                'Get help and contact support',
                Icons.help_outline,
                () {
                  // Navigate to help screen or show dialog
                  _showHelpDialog();
                },
              ),
              _buildActionTile(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip_outlined,
                () {
                  // Navigate to privacy policy
                  _showPrivacyDialog();
                },
              ),
              _buildActionTile(
                'Terms of Service',
                'View terms and conditions',
                Icons.description_outlined,
                () {
                  // Navigate to terms of service
                  _showTermsDialog();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsSection(
            'Account',
            [
              _buildActionTile(
                'Clear Cache',
                'Clear app cache and temporary files',
                Icons.cleaning_services_outlined,
                () {
                  _showClearCacheDialog();
                },
              ),
              _buildActionTile(
                'Sign Out',
                'Log out of your account',
                Icons.logout,
                () {
                  _showSignOutDialog();
                },
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppColors.primaryBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For assistance, please contact:\n\n'
          'Email: support@cholacabs.com\n'
          'Phone: +91 9876543210\n\n'
          'Our support team is available 24/7.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'Your privacy is important to us. We collect and use your data to provide the best cab service experience.\n\n'
          'For full privacy policy, visit our website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const Text(
          'By using this app, you agree to our terms and conditions.\n\n'
          'For complete terms, visit our website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary files and may improve app performance. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}