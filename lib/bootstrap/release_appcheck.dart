import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

/// Call this right after Firebase.initializeApp().
Future<void> activateAppCheck() async {
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider: kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
  );
}
