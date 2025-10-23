import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminFix {
  /// Promote caller to admin only if NO admin exists yet (enforced server-side).
  static Future<void> ensure(BuildContext context) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('ensureFirstAdmin');
      final res = await callable.call();
      final ok = (res.data is Map && res.data['granted'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Admin granted.' : 'No change: an admin already exists.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Admin check failed: $e')));
    }
  }
}
