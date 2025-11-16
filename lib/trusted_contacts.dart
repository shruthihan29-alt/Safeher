import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:camera/camera.dart';

class TrustedContactsPage extends StatefulWidget {
  const TrustedContactsPage({super.key});

  @override
  State<TrustedContactsPage> createState() => _TrustedContactsPageState();
}

class _TrustedContactsPageState extends State<TrustedContactsPage> {
  List<String> contacts = [];
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSirenPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _preparePermissions(); // ask early so SOS is faster
    _preloadSiren(); // load siren to memory
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
    setState(() => contacts = prefs.getStringList('trusted_contacts') ?? []);
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trusted_contacts', contacts);
  }

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
    setState(() => contacts.removeAt(index));
    _saveContacts();
  }

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
    await _audioPlayer.resume(); // uses preloaded sound
    if (mounted) setState(() => _isSirenPlaying = true);
  }

  Future<void> _stopSiren() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _isSirenPlaying = false);
  }

  Future<void> _sendSOS() async {
    // 🔊 Siren
    _playSiren();
    Future.delayed(const Duration(seconds: 10), _stopSiren);

    // 1. Location permission
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

    // 2. Get current location
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final mapsUrl =
        'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    final sosText = '🚨 SOS! I need help. My live location: $mapsUrl';

    // 3. Open dialer (119) – user decides to place call
    final callUri = Uri.parse('tel:119');
    if (await canLaunchUrl(callUri)) {
      launchUrl(callUri, mode: LaunchMode.externalApplication);
    }

    // 4. Open SMS app for each trusted contact
    for (final number in contacts) {
      final cleanNumber = number.replaceAll('+', '');
      final smsUri = Uri.parse(
        'sms:$cleanNumber?body=${Uri.encodeComponent(sosText)}',
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(
          smsUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    }

    if (!mounted) return;

    // 5. Show fake incoming police video call
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FakeIncomingPoliceCallPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
            const SizedBox(height: 16),
            Expanded(
              child: contacts.isEmpty
                  ? const Center(child: Text('No trusted contacts yet'))
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(contacts[i]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteContact(i),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),

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

            // 🚨 BIG SOS BUTTON
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
                minimumSize: const Size(double.infinity, 70),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.share_location),
              label: const Text('Send Live Location'),
              onPressed: _shareLiveLocation,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              icon: const Icon(Icons.local_police),
              label: const Text('Call 119 (Police)'),
              onPressed: _callPolice,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= FAKE INCOMING POLICE CALL =======================

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
    // Vibrate every second to simulate ringing
    if ((await Vibration.hasVibrator()) ?? false) {
      _vibrationTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => Vibration.vibrate(duration: 300),
      );
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  void _declineCall() {
    Navigator.pop(context);
  }

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
                  // Decline
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
                  // Accept
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

// ======================= FAKE POLICE VIDEO CALL =======================

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

    // Call duration timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return;
      }

      // Prefer front camera; fallback to first
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false, // we just need preview
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
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
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

            // Main area with fake police video + self-view
            Expanded(
              child: Stack(
                children: [
                  // Background "police" video
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

                  // Small camera preview (your face) in corner
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

            // Bottom controls
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 16),
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
