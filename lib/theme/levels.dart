import 'package:flutter/material.dart';

enum StockLevel { ok, warn, danger }

class LevelColors {
  static Color bg(BuildContext context, StockLevel l) {
    switch (l) {
      case StockLevel.danger:
        return Theme.of(context).colorScheme.errorContainer.withOpacity(0.35);
      case StockLevel.warn:
        return Colors.amber.withOpacity(0.25);
      case StockLevel.ok:
      default:
        return Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.18);
    }
  }

  static Color fg(BuildContext context, StockLevel l) {
    switch (l) {
      case StockLevel.danger:
        return Theme.of(context).colorScheme.onErrorContainer;
      case StockLevel.warn:
        return Colors.brown.shade900;
      case StockLevel.ok:
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}

StockLevel levelFor(num? par, num? qoh) {
  if (par == null || qoh == null) return StockLevel.ok;
  if (qoh < par * 0.5) return StockLevel.danger;
  if (qoh < par) return StockLevel.warn;
  return StockLevel.ok;
}
