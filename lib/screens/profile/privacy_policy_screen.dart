import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: CustomAppBar(title: 'Privacy Policy'),
      bottomNavigationBar: BottomNavigation(currentRoute: '/privacy-policy'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Information We Collect',
              'We collect personal information including name, phone number, email, location data, and vehicle details to provide our cab services.',
            ),
            _buildSection(
              'How We Use Your Information',
              'Your information is used to facilitate trip bookings, process payments, track location for safety, and improve our services.',
            ),
            _buildSection(
              'Location Data',
              'We collect real-time location data to match you with riders and ensure safety. Location tracking continues in the background when you are available for trips.',
            ),
            _buildSection(
              'Data Security',
              'We implement security measures to protect your personal information. However, no method of transmission over the internet is 100% secure.',
            ),
            _buildSection(
              'Third-Party Services',
              'We use Firebase for authentication, Razorpay for payments, and Google Maps for location services. These services have their own privacy policies.',
            ),
            _buildSection(
              'Your Rights',
              'You have the right to access, update, or delete your personal information. Contact us for any privacy-related requests.',
            ),
            _buildSection(
              'Contact Us',
              'For privacy concerns, contact us at support@cholacabs.in',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
