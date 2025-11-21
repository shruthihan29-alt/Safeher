import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _shakeKey = 'shake_sos_enabled';

  bool _shakeEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeEnabled = prefs.getBool(_shakeKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _updateShake(bool value) async {
    setState(() => _shakeEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top info card
                Card(
                  elevation: 0,
                  color: colors.primaryContainer.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.settings_suggest,
                          color: colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personalise SafeHer',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Turn smart safety shortcuts on or off. '
                                'These options only affect how the app behaves on your phone.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onPrimaryContainer
                                      .withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Quick actions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),

                // Shake to SOS
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    title: const Text('Shake phone to open SOS'),
                    subtitle: const Text(
                      'If enabled, a strong shake while SafeHer is open '
                      'will show a confirmation to trigger SOS.',
                    ),
                    value: _shakeEnabled,
                    onChanged: _updateShake,
                    secondary: Icon(
                      Icons.vibration,
                      color: _shakeEnabled
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'SOS behaviour (coming soon)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),

                // Future options (disabled – just for UI / presentation)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    enabled: false,
                    leading: Icon(
                      Icons.campaign_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                    title: const Text('Always play loud siren with SOS'),
                    subtitle: const Text(
                      'This option will be available in a future version.',
                    ),
                    trailing: Switch(
                      value: true,
                      onChanged: null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    enabled: false,
                    leading: Icon(
                      Icons.lock_clock_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                    title: const Text('Auto-stop siren after 2 minutes'),
                    subtitle: const Text(
                      'Planned feature to save battery and avoid accidental noise.',
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '• Shake detection only works while SafeHer is open and on the screen.\n'
                    '• For your privacy and security, the app cannot listen for shakes when the '
                    'phone is locked or the app is completely closed.\n'
                    '• You can still trigger SOS quickly from the main screen at any time.',
                  ),
                ),
              ],
            ),
    );
  }
}
