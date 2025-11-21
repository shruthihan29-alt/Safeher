import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ReportUnsafePlacePage extends StatefulWidget {
  const ReportUnsafePlacePage({super.key});

  @override
  State<ReportUnsafePlacePage> createState() => _ReportUnsafePlacePageState();
}

class _ReportUnsafePlacePageState extends State<ReportUnsafePlacePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController =
      TextEditingController();

  Position? _position;
  bool _loadingLocation = true;
  bool _submitting = false;

  double _radiusMeters = 200;
  String _severity = 'High'; // default

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() => _loadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied.'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable it in settings.',
            ),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for your location…'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final desc = _descriptionController.text.trim();

      await FirebaseFirestore.instance.collection('unsafe_places').add({
        'name': 'Unsafe place',
        'description': desc,
        'lat': _position!.latitude,
        'lng': _position!.longitude,
        'radiusMeters': _radiusMeters,
        'severity': _severity,
        'reportsCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your report has been submitted.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error submitting report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  Widget _buildSeverityChips(ColorScheme colors) {
    final severities = ['Low', 'Medium', 'High'];

    return Wrap(
      spacing: 8,
      children: severities.map((s) {
        final selected = _severity == s;
        Color bg;
        Color fg;

        switch (s) {
          case 'High':
            bg = Colors.red.shade100;
            fg = Colors.red.shade800;
            break;
          case 'Medium':
            bg = Colors.orange.shade100;
            fg = Colors.orange.shade800;
            break;
          default:
            bg = Colors.amber.shade100;
            fg = Colors.amber.shade800;
        }

        return ChoiceChip(
          label: Text(s),
          selected: selected,
          onSelected: (_) => setState(() => _severity = s),
          backgroundColor: bg,
          selectedColor: bg,
          labelStyle: TextStyle(
            color: selected ? fg : fg.withOpacity(0.7),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pos = _position;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Unsafe Place'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _loadingLocation
                      ? Row(
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Getting your current location…'),
                          ],
                        )
                      : pos == null
                          ? const Text(
                              'Location unavailable. Please enable GPS and permissions, then try again.',
                              style: TextStyle(color: Colors.red),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You are reporting the place where you are right now.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${pos.latitude.toStringAsFixed(5)}, '
                                  'Lng: ${pos.longitude.toStringAsFixed(5)}',
                                ),
                              ],
                            ),
                ),
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    const Text(
                      'Why does this place feel unsafe?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Example: People drinking / harassment / no lights / etc.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Please describe why this place feels unsafe.';
                        }
                        if (text.length > 500) {
                          return 'Description is too long (max 500 characters).';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Severity
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    _buildSeverityChips(colors),

                    const SizedBox(height: 16),

                    // Radius slider
                    const Text(
                      'Area around you to mark as unsafe (meters)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _radiusMeters,
                      min: 50,
                      max: 500,
                      divisions: 9, // 50–500 step 50
                      label: '${_radiusMeters.toStringAsFixed(0)} m',
                      onChanged: (v) {
                        setState(() => _radiusMeters = v);
                      },
                    ),
                    Text(
                      'Radius: ${_radiusMeters.toStringAsFixed(0)} m',
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.7),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.report),
                        label: Text(
                          _submitting ? 'Submitting…' : 'Submit Unsafe Place Report',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
