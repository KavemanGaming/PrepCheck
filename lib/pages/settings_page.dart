import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _bizCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bizCtrl.text = ThemeController.I.businessName ?? '';
    ThemeController.I.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    ThemeController.I.removeListener(_onChange);
    _bizCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).colorScheme;
    final current = ThemeController.I.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ThemeController.I.setPalette(AppPalette.teal),
                  icon: const Icon(Icons.palette),
                  label: const Text('Teal'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: current == AppPalette.teal ? t.primary : t.outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ThemeController.I.setPalette(AppPalette.coffee),
                  icon: const Icon(Icons.coffee),
                  label: const Text('Coffee'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: current == AppPalette.coffee ? t.primary : t.outline),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Business name', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _bizCtrl,
            decoration: const InputDecoration(
              labelText: 'Business name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await ThemeController.I.setBusinessName(_bizCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
