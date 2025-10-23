import 'package:flutter/material.dart';

ColorScheme schemeFor(String? name) {
  switch ((name ?? 'teal').toLowerCase()) {
    case 'coffee':
      // A warm coffee-like seed
      return ColorScheme.fromSeed(seedColor: const Color(0xFF6F4E37), brightness: Brightness.light);
    case 'teal':
    default:
      return ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);
  }
}
