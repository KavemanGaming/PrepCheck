import 'package:flutter/material.dart';

class OrderPill extends StatelessWidget {
  final num value;
  const OrderPill({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool zero = value <= 0;
    final bg = zero ? cs.surfaceVariant : cs.primaryContainer;
    final fg = zero ? cs.onSurfaceVariant : cs.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        zero ? '0' : (value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2)),
        style: TextStyle(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
