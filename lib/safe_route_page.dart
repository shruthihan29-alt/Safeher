import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'admin_unsafe_places_page.dart';

class UnsafeArea {
  final String id;
  final String name;
  final String description;
  final double lat;
  final double lng;
  final double radiusMeters;
  final int reportsCount;
  final String severity;

  UnsafeArea({
    required this.id,
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.reportsCount,
    required this.severity,
  });

  factory UnsafeArea.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UnsafeArea(
      id: doc.id,
      name: data['name'] as String? ?? 'Unsafe place',
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 200.0,
      reportsCount: (data['reportsCount'] as num?)?.toInt() ?? 1,
      severity: data['severity'] as String? ?? 'Low',
    );
  }
}

class SafeRoutePage extends StatefulWidget {
  const SafeRoutePage({super.key});

  @override
  State<SafeRoutePage> createState() => _SafeRoutePageState();
}

class _SafeRoutePageState extends State<SafeRoutePage> {
  final TextEditingController _destinationController =
      TextEditingController();

  Position? _currentPosition;
  bool _loadingLocation = true;
  bool _loadingUnsafeAreas = true;
  bool _checkingRoute = false;

  List<UnsafeArea> _unsafeAreas = [];
  String? _warningMessage;

  @override
  void initState() {
    super.initState();
    _initLocationAndData();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndData() async {
    await _loadCurrentLocation();
    await _loadUnsafeAreasFromFirestore();
    if (_currentPosition != null) {
      _checkUnsafeZones(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }
  }

  // 1) Get current location
  Future<void> _loadCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _warningMessage = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _warningMessage =
              'Location permission permanently denied. Enable it in settings.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = pos;
      });
    } catch (e) {
      debugPrint('Error loading location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  // 2) Load unsafe areas from Firestore
  Future<void> _loadUnsafeAreasFromFirestore() async {
    setState(() {
      _loadingUnsafeAreas = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('unsafe_places')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final areas =
          snapshot.docs.map((d) => UnsafeArea.fromDoc(d)).toList();

      setState(() {
        _unsafeAreas = areas;
      });

      if (_currentPosition != null) {
        _checkUnsafeZones(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    } catch (e) {
      debugPrint('Error loading unsafe areas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load unsafe areas: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUnsafeAreas = false;
        });
      }
    }
  }

  // 3) Check if user is inside any unsafe area
  void _checkUnsafeZones(double lat, double lng) {
    UnsafeArea? mostSevere;

    for (final area in _unsafeAreas) {
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        area.lat,
        area.lng,
      );

      if (distance <= area.radiusMeters) {
        if (mostSevere == null ||
            _severityWeight(area.severity) >
                _severityWeight(mostSevere.severity)) {
          mostSevere = area;
        }
      }
    }

    if (mostSevere != null) {
      final area = mostSevere;
      setState(() {
        _warningMessage =
            'You are inside an unsafe area: ${area.name}\n'
            'Reason: ${area.description.isEmpty ? 'Not specified' : area.description}\n'
            'Severity: ${area.severity}';
      });
    } else {
      setState(() {
        _warningMessage = null;
      });
    }
  }

  int _severityWeight(String s) {
    final v = s.toLowerCase();
    if (v.contains('high')) return 3;
    if (v.contains('medium')) return 2;
    return 1; // Low or anything else
  }

  Color _severityColor(String s, ColorScheme colors) {
    final v = s.toLowerCase();
    if (v.contains('high')) return Colors.red.shade600;
    if (v.contains('medium')) return Colors.orange.shade700;
    return Colors.amber.shade700;
  }

  // 4) "Smart" route: check if destination is near unsafe areas
  Future<void> _openSafeRoute() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for current location...'),
        ),
      );
      return;
    }

    final dest = _destinationController.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() {
      _checkingRoute = true;
    });

    bool proceedToMaps = true;

    try {
      // 4a) Geocode destination using FREE OpenStreetMap Nominatim
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&limit=1'
        '&q=${Uri.encodeQueryComponent(dest)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'SafeHer/1.0 (safeher.app.example@gmail.com)',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final first = data.first as Map<String, dynamic>;
          final destLat = double.parse(first['lat'] as String);
          final destLng = double.parse(first['lon'] as String);

          // 4b) Check unsafe areas near destination
          final List<UnsafeArea> hits = [];
          for (final area in _unsafeAreas) {
            final d = Geolocator.distanceBetween(
              destLat,
              destLng,
              area.lat,
              area.lng,
            );
            if (d <= area.radiusMeters + 100) {
              // 100m buffer
              hits.add(area);
            }
          }

          if (hits.isNotEmpty && mounted) {
            hits.sort((a, b) =>
                _severityWeight(b.severity)
                    .compareTo(_severityWeight(a.severity)));

            final worst = hits.first;
            final worstSeverity = worst.severity;
            final count = hits.length;

            final message = StringBuffer()
              ..writeln(
                  'Your destination is near $count reported unsafe area(s).')
              ..writeln('Worst severity: $worstSeverity.')
              ..writeln()
              ..writeln(
                  'Example report: ${worst.description.isEmpty ? 'No description provided.' : worst.description}')
              ..writeln()
              ..writeln(
                  'This check is based on community reports and may not be perfect. Do you still want to open this route in Google Maps?');

            final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Safety Warning'),
                    content: Text(message.toString()),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ) ??
                false;

            proceedToMaps = result;
          }
        }
      } else {
        debugPrint(
            'Nominatim error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error checking route safety: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingRoute = false;
        });
      }
    }

    if (!proceedToMaps) return;

    // 4c) Open Google Maps walking route
    final originLat = _currentPosition!.latitude;
    final originLng = _currentPosition!.longitude;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$originLat,$originLng'
      '&destination=${Uri.encodeComponent(dest)}'
      '&travelmode=walking',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = _currentPosition;

    final totalAreas = _unsafeAreas.length;
    final totalReports = _unsafeAreas.fold<int>(
      0,
      (sum, a) => sum + a.reportsCount,
    );

    final highCount = _unsafeAreas
        .where((a) => _severityWeight(a.severity) == 3)
        .length;
    final mediumCount = _unsafeAreas
        .where((a) => _severityWeight(a.severity) == 2)
        .length;
    final lowCount = _unsafeAreas
        .where((a) => _severityWeight(a.severity) == 1)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Route Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin – Manage unsafe places',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminUnsafePlacesPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload unsafe areas',
            onPressed: _loadUnsafeAreasFromFirestore,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location status
            if (_loadingLocation)
              const Text(
                'Getting current location...',
                style: TextStyle(color: Colors.grey),
              )
            else if (current == null)
              const Text(
                'Location unavailable. Please enable GPS & permissions.',
                style: TextStyle(color: Colors.red),
              )
            else
              Text(
                'Your location: '
                '${current.latitude.toStringAsFixed(5)}, '
                '${current.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

            const SizedBox(height: 12),

            // Warning / Safe banner
            if (_warningMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _warningMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No unsafe areas detected near your current location (based on user reports).',
                        style: TextStyle(
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Summary chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: Text('Areas: $totalAreas'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.report, size: 16),
                    label: Text('Reports: $totalReports'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('High: $highCount'),
                    backgroundColor: Colors.red.shade50,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Med: $mediumCount'),
                    backgroundColor: Colors.orange.shade50,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Low: $lowCount'),
                    backgroundColor: Colors.amber.shade50,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Destination input
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination (address or place name)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Open route button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _checkingRoute
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.directions_walk),
                label: Text(
                  _checkingRoute
                      ? 'Checking route safety...'
                      : 'Open Route in Google Maps',
                ),
                onPressed: _checkingRoute ? null : _openSafeRoute,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Reported unsafe places (latest first):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // List of unsafe areas
            Expanded(
              child: _loadingUnsafeAreas
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _unsafeAreas.isEmpty
                      ? const Center(
                          child: Text(
                            'No unsafe places reported yet.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _unsafeAreas.length,
                          itemBuilder: (context, index) {
                            final area = _unsafeAreas[index];
                            final sevColor =
                                _severityColor(area.severity, colors);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: sevColor.withOpacity(0.15),
                                  child: Icon(
                                    Icons.warning_amber,
                                    color: sevColor,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(area.name)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sevColor.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        area.severity,
                                        style: TextStyle(
                                          color: sevColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${area.description}\n'
                                    'Lat: ${area.lat.toStringAsFixed(5)}, '
                                    'Lng: ${area.lng.toStringAsFixed(5)}\n'
                                    'Radius: ${area.radiusMeters.toStringAsFixed(0)} m, '
                                    'Reports: ${area.reportsCount}',
                                  ),
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
