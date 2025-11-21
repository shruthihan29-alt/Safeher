import 'package:flutter/material.dart';

class SafetyTipsPage extends StatelessWidget {
  const SafetyTipsPage({super.key});

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<String> bullets}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...bullets.map(_buildBullet),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SafeHer',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.shield_moon, size: 40),
      children: const [
        SizedBox(height: 8),
        Text(
          'SafeHer is a safety companion app designed to support women and vulnerable people '
          'when travelling or moving through public spaces.\n',
        ),
        Text(
          'Main features:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '• SOS: Quickly alert trusted contacts, share your live location, and trigger a simulated police call.\n'
          '• Safe Route: Check if your route or destination is near reported unsafe areas.\n'
          '• Reports: Let the community know about unsafe hotspots.\n',
        ),
        Text(
          'Disclaimer:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'This app does not replace the police, ambulance, or any official emergency service. '
          'Data is community-reported and may not always be accurate. In an emergency, always call your local authorities.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Tips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About SafeHer',
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'These tips do not replace professional help or official emergency services, '
            'but they can support you to stay safer while moving around.',
            style: TextStyle(fontSize: 14),
          ),

          _buildSectionTitle('Before you go out'),
          _buildCard(
            title: 'Plan ahead',
            bullets: [
              'Share your destination and expected time of arrival with a trusted contact.',
              'Keep your phone charged and carry a power bank if possible.',
              'Avoid carrying large amounts of cash or valuables.',
            ],
          ),
          _buildCard(
            title: 'Check your route',
            bullets: [
              'Use SafeHer’s Safe Route and unsafe area reports to see any risky hotspots.',
              'Prefer well-lit, busy main roads instead of shortcuts through isolated places.',
            ],
          ),

          _buildSectionTitle('While you are travelling'),
          _buildCard(
            title: 'Stay aware',
            bullets: [
              'Avoid walking while fully distracted by your phone or loud music.',
              'Trust your instincts – if a place or person feels wrong, leave if you can.',
              'Keep your bag closed and in front of you on crowded buses or trains.',
            ],
          ),
          _buildCard(
            title: 'Public places & transport',
            bullets: [
              'Try to sit or stand near other women, families, or staff when possible.',
              'Avoid getting into unmarked vehicles. Use registered taxis or known drivers.',
            ],
          ),

          _buildSectionTitle('If you feel unsafe'),
          _buildCard(
            title: 'Use SafeHer tools',
            bullets: [
              'Use the SOS button to alert your trusted contacts and start the emergency flow.',
              'Send your live location to someone you trust from the SOS screen.',
              'Report unsafe places so other women can avoid them in the future.',
            ],
          ),
          _buildCard(
            title: 'Look for safer options',
            bullets: [
              'Move towards brighter, busier places – shops, restaurants, or bus stands.',
              'If possible, call or voice message someone and keep them on the line.',
            ],
          ),

          _buildSectionTitle('Important numbers (Sri Lanka)'),
          _buildCard(
            title: 'Emergency contacts',
            bullets: [
              'Police emergency: 119',
              'Ambulance / Fire & Rescue: 110',
              'Women & children help lines (check latest numbers for your area).',
            ],
          ),

          const SizedBox(height: 12),
          const Text(
            'Note: This app is a community tool. Reports are user-generated and may not always be verified. '
            'Always prioritise your safety and follow instructions from official authorities.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
