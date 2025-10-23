import 'package:flutter/material.dart';
import '../../theme/theme_controller.dart';

class PaletteToggle extends StatefulWidget {
  const PaletteToggle({super.key});

  @override
  State<PaletteToggle> createState() => _PaletteToggleState();
}

class _PaletteToggleState extends State<PaletteToggle> {
  @override
  void initState() {
    super.initState();
    ThemeController.I.addListener(_update);
  }

  @override
  void dispose() {
    ThemeController.I.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = ThemeController.I.palette;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ThemeController.I.setPalette(AppPalette.teal),
            icon: const Icon(Icons.palette),
            label: const Text('Teal'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: current == AppPalette.teal ? cs.primary : cs.outline),
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
              side: BorderSide(color: current == AppPalette.coffee ? cs.primary : cs.outline),
            ),
          ),
        ),
      ],
    );
  }
}
