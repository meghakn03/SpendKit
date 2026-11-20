import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import '../core.dart';
import 'screen_body.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _save(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } on Exception {
      if (mounted) {
        setState(() => _error = 'The setting could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return ScreenBody(
      children: [
        const SpendHeading(
          'Settings',
          subtitle: 'Studio North Ltd · Demo workspace',
        ),
        SpendPanel(
          padding: 12,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Biometric unlock'),
                subtitle: const Text(
                  'Requires enrolled biometrics on Android or iOS.',
                ),
                value: session.biometricEnabled,
                onChanged: _saving
                    ? null
                    : (value) => _save(() async {
                        final changed = await session.setBiometrics(value);
                        if (mounted && !changed) {
                          setState(
                            () => _error = 'Biometric verification was unavailable or cancelled.',
                          );
                        }
                      }),
              ),
              SwitchListTile(
                title: const Text('Dark theme'),
                value: session.darkMode,
                onChanged: _saving
                    ? null
                    : (value) => _save(() => session.setDark(value)),
              ),
              SwitchListTile(
                title: const Text('High contrast'),
                value: session.highContrast,
                onChanged: _saving
                    ? null
                    : (value) => _save(() => session.setContrast(value)),
              ),
            ],
          ),
        ),
        if (_error case final error?) SpendNotice(message: error, error: true),
        SpendPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SpendHeading('Design system'),
              const SizedBox(height: 12),
              SpendButton(
                label: 'Open component gallery',
                icon: Icons.widgets_outlined,
                onPressed: () => context.go('/settings/gallery'),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SpendButton(
            label: 'Lock workspace',
            icon: Icons.lock_outline,
            onPressed: _saving ? null : session.lock,
          ),
        ),
      ],
    );
  }
}

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => ScreenBody(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Settings'),
        ),
      ),
      const SpendHeading(
        'Component gallery',
        subtitle: 'Shared widgets in the current theme.',
      ),
      SpendPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buttons', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SpendButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Button activated')),
                    );
                  },
                ),
                const SpendButton(label: 'Disabled'),
                const SpendButton(label: 'Saving', busy: true),
              ],
            ),
          ],
        ),
      ),
      const SpendPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpendHeading('Form field'),
            SizedBox(height: 12),
            SpendField(label: 'Merchant', prefixIcon: Icons.search),
          ],
        ),
      ),
      const SpendNotice(message: 'Your changes have been saved.'),
      const SpendNotice(
        message: 'We could not save your changes.',
        error: true,
      ),
    ],
  );
}
