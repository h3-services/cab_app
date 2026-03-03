import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/widgets.dart';
import '../../constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: CustomAppBar(title: 'Help & Support'),
      bottomNavigationBar: BottomNavigation(currentRoute: '/help-support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            _buildContactCard(
              icon: Icons.phone,
              title: 'Call Us',
              subtitle: '+91 1234567890',
              onTap: () => _launchUrl('tel:+911234567890'),
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.email,
              title: 'Email Us',
              subtitle: 'support@cholacabs.in',
              onTap: () => _launchUrl('mailto:support@cholacabs.in'),
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.chat,
              title: 'WhatsApp',
              subtitle: 'Chat with us',
              onTap: () => _launchUrl('https://wa.me/911234567890'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildFAQ(
              'How do I accept a trip?',
              'Go to the Available tab and tap "Request Ride" on any trip. Once approved, it will move to the Approved tab.',
            ),
            _buildFAQ(
              'How do I track my earnings?',
              'Go to the Wallet tab to see your balance and transaction history.',
            ),
            _buildFAQ(
              'What if I have a problem during a trip?',
              'Contact our support team immediately using the contact options above.',
            ),
            _buildFAQ(
              'How do I update my documents?',
              'Go to Profile > Settings to update your KYC documents.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC4C4C4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.greenPrimary, AppColors.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC4C4C4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: const TextStyle(height: 1.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
