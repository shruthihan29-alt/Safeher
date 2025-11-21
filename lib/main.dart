import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'trusted_contacts.dart';
import 'safe_route_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeHer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      // Start on welcome screen
      home: const WelcomeScreen(),
    );
  }
}

// ----------------------------------------------------------------------
// MAIN NAVIGATION (unchanged)
// ----------------------------------------------------------------------

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final _screens = const [
    TrustedContactsPage(), // SOS + fake video call + contacts
    SafeRoutePage(), // Safe navigation + unsafe areas
  ];

  void _showSafetyTips() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SafetyTipsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],

      // Bottom navigation with center Safety Tips button
      bottomNavigationBar: SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The regular navigation bar (SOS + Safe Route)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: NavigationBar(
                height: 70,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.sos_outlined),
                    selectedIcon: Icon(Icons.sos),
                    label: "SOS",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: "Safe Route",
                  ),
                ],
              ),
            ),

            // Center Safety Tips button, visually inside the bar
            Positioned(
              bottom: 30,
              child: GestureDetector(
                onTap: _showSafetyTips,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade600,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.health_and_safety,
                          color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        "Safety Tips",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with simple safety tips
class SafetyTipsSheet extends StatelessWidget {
  const SafetyTipsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16).copyWith(bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // little drag handle
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(30),
            ),
            margin: const EdgeInsets.only(bottom: 10),
          ),
          const Text(
            "Safety Tips",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          _tip(
            Icons.location_on,
            "Share your location",
            "Always let a trusted person know where you're going and when you'll be back.",
          ),
          _tip(
            Icons.group,
            "Stay with people",
            "Avoid walking alone in dark or isolated areas whenever possible.",
          ),
          _tip(
            Icons.phone_android,
            "Keep your phone ready",
            "Charge your phone and keep mobile data on for emergency calls and navigation.",
          ),
          _tip(
            Icons.warning_amber,
            "Trust your instincts",
            "If something feels wrong, leave and move to a safer, busier place.",
          ),
          _tip(
            Icons.report,
            "Report unsafe places",
            "Use the app to report dangerous locations so others can stay safe too.",
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String title, String desc) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepOrange),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(desc),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Welcome screen WITH logo – scrollable version to avoid overflow
// ----------------------------------------------------------------------

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _goToApp(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigation(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 16),

                      // Logo + title
                      Column(
                        children: [
                          Container(
                            width: constraints.maxWidth * 0.55,
                            height: constraints.maxWidth * 0.55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7C4DFF),
                                  Color(0xFFF06292)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                'assets/images/safeher_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shield,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'SafeHer',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart protection for women on the move.\n'
                            'SOS, safe routes, and trusted contacts in one place.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      colors.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),

                      // Buttons + small text
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _goToApp(context),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text(
                                'Get started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                minimumSize:
                                    const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => _goToApp(context),
                            child: Text(
                              'Skip for now',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'In an emergency, press the SOS button or shake your phone (if enabled).',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      colors.onSurface.withOpacity(0.6),
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
