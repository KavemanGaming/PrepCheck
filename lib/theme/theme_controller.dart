import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AppPalette { teal, coffee }

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController I = ThemeController._();

  AppPalette _palette = AppPalette.teal;
  String? _businessName;

  AppPalette get palette => _palette;
  String? get businessName => _businessName;

  ThemeData get theme {
    final seed = _palette == AppPalette.teal ? const Color(0xFF00897B) : const Color(0xFF6F4E37);
    return ThemeData(colorSchemeSeed: seed, useMaterial3: true);
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString('palette');
      if (p == 'coffee') _palette = AppPalette.coffee; else _palette = AppPalette.teal;
      _businessName = prefs.getString('businessName');
    } catch (_) {}

    try {
      final snap = await FirebaseFirestore.instance.collection('settings').doc('app').get();
      final data = snap.data();
      if (data != null) {
        final remotePal = (data['theme'] ?? '').toString();
        if (remotePal == 'coffee') _palette = AppPalette.coffee;
        if (remotePal == 'teal') _palette = AppPalette.teal;
        if (data['businessName'] is String) _businessName = data['businessName'];
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<void> setPalette(AppPalette p, {bool saveRemote = true}) async {
    _palette = p;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('palette', p == AppPalette.coffee ? 'coffee' : 'teal');
    } catch (_) {}
    if (saveRemote) {
      try {
        await FirebaseFirestore.instance.collection('settings').doc('app').set(
          {'theme': p == AppPalette.coffee ? 'coffee' : 'teal'},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }

  Future<void> setBusinessName(String name) async {
    _businessName = name;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('businessName', name);
    } catch (_) {}
    try {
      await FirebaseFirestore.instance.collection('settings').doc('app').set(
        {'businessName': name},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
