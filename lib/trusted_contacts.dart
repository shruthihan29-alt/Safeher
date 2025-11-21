import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import 'report_unsafe_place_page.dart';
import 'safe_route_page.dart';
import 'safety_tips_page.dart';
import 'settings_page.dart';

class TrustedContactsPage extends StatefulWidget {
  const TrustedContactsPage({super.key});

  @override
  State<TrustedContactsPage> createState() => _TrustedContactsPageState();
}

class _TrustedContactsPageState extends State<TrustedContactsPage> {
  // ---------- STATE ----------
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> contacts = [];
  bool _isSirenPlaying = false;

  // Shake-to-SOS
  bool _shakeEnabled = true;
  static const _shakeKey = 'shake_sos_enabled';
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime? _lastShakeTime;

  // Bottom nav
  int _selectedTab = 0;

  // ---------- INIT / DISPOSE ----------
  @override
  void initState() {
    super.initState();
    _loadContacts();
    _preparePermissions();
    _preloadSiren();
    _loadShakeSetting();
    _startShakeListener();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _preparePermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _preloadSiren() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setSource(AssetSource('sounds/siren.mp3'));
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      contacts = prefs.getStringList('trusted_contacts') ?? [];
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trusted_contacts', contacts);
  }

  // ---------- SHAKE SETTINGS ----------
  Future<void> _loadShakeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeEnabled = prefs.getBool(_shakeKey) ?? true;
    });
  }

  void _startShakeListener() {
    _accelSub = accelerometerEvents.listen((event) {
      if (!_shakeEnabled) return;

      final gX = event.x / 9.81;
      final gY = event.y / 9.81;
      final gZ = event.z / 9.81;
      final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      const threshold = 2.2; // ≈ moderate shake
      if (gForce > threshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null ||
            now.difference(_lastShakeTime!) > const Duration(seconds: 3)) {
          _lastShakeTime = now;
          _onShakeDetected();
        }
      }
    });
  }

  Future<void> _onShakeDetected() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Shake detected'),
            content: const Text(
              'Do you want to trigger SOS now?\n'
              'This will open the Police dialer and SMS for your trusted contacts.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, SOS'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      _sendSOS();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    // Reload setting when returning
    _loadShakeSetting();
  }

  // ---------- CONTACTS ----------
  void _addContact() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      contacts.add(text);
      _controller.clear();
    });
    _saveContacts();
  }

  void _deleteContact(int index) {
    setState(() {
      contacts.removeAt(index);
    });
    _saveContacts();
  }

  // ---------- ACTIONS ----------
  Future<void> _shareLiveLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final googleMapsUrl =
        'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    await Share.share('🚨 SOS! Here is my live location: $googleMapsUrl');
  }

  Future<void> _callPolice() async {
    final uri = Uri.parse('tel:119'); // Sri Lanka Police emergency
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _playSiren() async {
    await _audioPlayer.resume();
    if (mounted) {
      setState(() => _isSirenPlaying = true);
    }
  }

  Future<void> _stopSiren() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() => _isSirenPlaying = false);
    }
  }

  Future<void> _sendSOS() async {
    // 1) Siren (non-blocking)
    _playSiren();
    Future.delayed(const Duration(seconds: 10), _stopSiren);

    // 2) Location
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission permanently denied'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final mapsUrl =
        'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    final sosText = '🚨 SOS! I need help. My live location: $mapsUrl';

    // 3) Open dialer (119)
    final callUri = Uri.parse('tel:119');
    if (await canLaunchUrl(callUri)) {
      launchUrl(callUri, mode: LaunchMode.externalApplication);
    }

    // 4) Open SMS app for each trusted contact
    for (final number in contacts) {
      final smsUri = Uri.parse(
        'sms:$number?body=${Uri.encodeComponent(sosText)}',
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(
          smsUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    }

    if (!mounted) return;

    // 5) Fake incoming call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FakeIncomingPoliceCallPage(),
      ),
    );
  }

  // ---------- UI HELPERS ----------
  Widget _buildShakeBanner(ColorScheme colors) {
    final text = _shakeEnabled
        ? 'Shake-to-SOS is ON. Add at least one trusted contact so SOS can also open SMS with your location.'
        : 'Shake-to-SOS is OFF. You can enable it from Settings.';

    // Use a different icon for OFF (since vibration_disabled may not exist)
    final icon = _shakeEnabled ? Icons.vibration : Icons.phonelink_erase;

    return Card(
      color: colors.tertiaryContainer.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: colors.onTertiaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustedContactsCard(ColorScheme colors) {
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trusted Contacts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Add contact number (e.g. +9471XXXXXXX)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addContact,
                ),
              ),
              onSubmitted: (_) => _addContact(),
            ),
            const SizedBox(height: 12),
            contacts.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined,
                              color: colors.onSurface.withOpacity(0.4),
                              size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'No trusted contacts yet',
                            style: TextStyle(
                              color: colors.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add at least one phone number so SOS can notify them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: contacts.length,
                    itemBuilder: (context, i) => Card(
                      elevation: 0,
                      color: colors.surfaceVariant.withOpacity(0.4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colors.primary.withOpacity(0.15),
                          child: Icon(Icons.person,
                              color: colors.primary, size: 20),
                        ),
                        title: Text(contacts[i]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent),
                          onPressed: () => _deleteContact(i),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(ColorScheme colors) {
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigation & safety',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.route),
              label: const Text('Safe Route Navigation'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SafeRoutePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: colors.surfaceVariant,
                foregroundColor: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.report_problem),
              label: const Text('Report Unsafe Place'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportUnsafePlacePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(ColorScheme colors) {
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency actions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // SOS big button
            ElevatedButton.icon(
              onPressed: _sendSOS,
              icon: const Icon(Icons.emergency, color: Colors.white, size: 30),
              label: const Text(
                'SOS – Alert Police & Contacts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 209, 3, 3),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Siren STOP (if playing)
            if (_isSirenPlaying) ...[
              OutlinedButton.icon(
                onPressed: _stopSiren,
                icon: const Icon(Icons.volume_off),
                label: const Text('Stop Siren'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.share_location),
              label: const Text('Send Live Location'),
              onPressed: _shareLiveLocation,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.local_police),
              label: const Text('Call 119 (Police)'),
              onPressed: _callPolice,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Small logo next to title
            Image.asset(
              'assets/images/safeher_logo.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.shield, size: 22),
            ),
            const SizedBox(width: 8),
            const Text('SOS & Trusted Contacts'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Emergency dashboard',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'SOS, trusted contacts, and quick safety tools.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          _buildShakeBanner(colors),
          const SizedBox(height: 16),

          _buildTrustedContactsCard(colors),
          const SizedBox(height: 16),

          _buildNavigationCard(colors),
          const SizedBox(height: 16),

          _buildEmergencyCard(colors),
          const SizedBox(height: 16),
        ],
      ),

      // Bottom nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) {
          setState(() => _selectedTab = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SafetyTipsPage(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SafeRoutePage(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sos),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_moon_outlined),
            label: 'Safety Tips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Safe Route',
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// FAKE INCOMING POLICE CALL
// ===================================================================

class FakeIncomingPoliceCallPage extends StatefulWidget {
  const FakeIncomingPoliceCallPage({super.key});

  @override
  State<FakeIncomingPoliceCallPage> createState() =>
      _FakeIncomingPoliceCallPageState();
}

class _FakeIncomingPoliceCallPageState
    extends State<FakeIncomingPoliceCallPage> {
  int _seconds = 0;
  Timer? _timer;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  Future<void> _startRinging() async {
    if ((await Vibration.hasVibrator()) ?? false) {
      _vibrationTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        Vibration.vibrate(duration: 300);
      });
    }

    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibrationTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  String _formatRingingTime() {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _acceptCall() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const FakePoliceVideoCallPage(),
      ),
    );
  }

  void _declineCall() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'Police Emergency',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Incoming video call…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatRingingTime(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.local_police,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 40),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _declineCall,
                    child: Column(
                      children: const [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.call_end, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Decline',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Column(
                      children: const [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.video_call, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Accept',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
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

// ===================================================================
// FAKE POLICE VIDEO CALL
// ===================================================================

class FakePoliceVideoCallPage extends StatefulWidget {
  const FakePoliceVideoCallPage({super.key});

  @override
  State<FakePoliceVideoCallPage> createState() =>
      _FakePoliceVideoCallPageState();
}

class _FakePoliceVideoCallPageState extends State<FakePoliceVideoCallPage> {
  int _seconds = 0;
  Timer? _timer;

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;

  @override
  void initState() {
    super.initState();

    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _cameraInitFuture = _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  String _formatDuration() {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  children: [
                    const Text(
                      'Police Emergency',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDuration(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF263238), Color(0xFF000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            Icons.local_police,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Connected to Police',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This is a simulated video call',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 24,
                    width: 110,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.black,
                        child: _cameraController == null
                            ? const Center(
                                child: Icon(
                                  Icons.videocam_off,
                                  color: Colors.white54,
                                ),
                              )
                            : FutureBuilder<void>(
                                future: _cameraInitFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    return CameraPreview(_cameraController!);
                                  } else if (snapshot.hasError) {
                                    return const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.redAccent,
                                      ),
                                    );
                                  } else {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(bottom: 24, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _RoundCallButton(icon: Icons.mic_off, label: 'Mute'),
                  _RoundCallButton(icon: Icons.videocam_off, label: 'Video'),
                  _EndCallButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoundCallButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 4),
          const Text('End', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
