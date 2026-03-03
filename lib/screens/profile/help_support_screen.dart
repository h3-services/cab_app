import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Help & Support'),
      bottomNavigationBar: BottomNavigation(currentRoute: '/help-support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            answer,
            style: const TextStyle(height: 1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
