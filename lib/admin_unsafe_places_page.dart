// lib/admin_unsafe_places_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminUnsafePlacesPage extends StatelessWidget {
  const AdminUnsafePlacesPage({super.key});

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('unsafe_places');

  Future<void> _openInMaps(
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    String docId,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete unsafe place'),
            content: const Text(
              'Are you sure you want to delete this unsafe place report?\n\n'
              'This will remove it from Safe Route warnings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _collection.doc(docId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsafe place deleted.')),
        );
      }
    } on FirebaseException catch (e) {
      // 🔴 If rules block delete, you’ll see the exact error here
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.message ?? e.code}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Unknown time';
    final dt = ts.toDate().toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Unsafe Places'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collection
            .orderBy('createdAt', descending: true)
            .snapshots(), // live updates
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No unsafe places have been reported yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final name = data['name'] as String? ?? 'Unsafe place';
              final description = data['description'] as String? ?? '';
              final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
              final radius =
                  (data['radiusMeters'] as num?)?.toDouble() ?? 200.0;
              final severity = data['severity'] as String? ?? 'Low';
              final reportsCount =
                  (data['reportsCount'] as num?)?.toInt() ?? 1;
              final createdAt = data['createdAt'] as Timestamp?;

              Color iconColor;
              if (severity.toLowerCase().contains('high')) {
                iconColor = Colors.red;
              } else if (severity.toLowerCase().contains('medium')) {
                iconColor = Colors.orange;
              } else {
                iconColor = Colors.amber;
              }

              return Card(
                color: colors.errorContainer.withOpacity(0.15),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: iconColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(description),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${lat.toStringAsFixed(5)}, '
                              'Lng: ${lng.toStringAsFixed(5)}',
                            ),
                            Text(
                              'Radius: ${radius.toStringAsFixed(0)} m, '
                              'Severity: $severity, '
                              'Reports: $reportsCount',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last reported: ${_formatDate(createdAt)}',
                              style: TextStyle(
                                color:
                                    Theme.of(context).textTheme.bodySmall?.color,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Open in Google Maps',
                            onPressed: () => _openInMaps(lat, lng),
                            icon: const Icon(Icons.map_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _confirmAndDelete(
                              context,
                              doc.id,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
