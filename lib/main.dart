import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// FirebaseUI (aliased to avoid symbol name clashes)
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as ui;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart' as ui_google;

import 'firebase_options.dart';
import 'pages/home_shell.dart';
import 'bootstrap/release_appcheck.dart';

/// Hardcode your Google Web Client ID so Google shows up without --dart-define.
const String kGoogleClientId =
    '940912900661-fc39eot3dft12ae4k7i5kdb3qb82c818.apps.googleusercontent.com';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await activateAppCheck();

  // ---- App Check FIRST (before any Firestore/Storage/Auth calls) ----
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:   kReleaseMode ? AppleProvider.deviceCheck   : AppleProvider.debug,
  );
  debugPrint('APPCHECK provider (android) = ${kReleaseMode ? 'PlayIntegrity' : 'Debug'}');

  // Try to fetch a token so you can verify it's issuing one (null-safe).
  try {
    final tok = await FirebaseAppCheck.instance.getToken(true);
    if (tok != null && tok.isNotEmpty) {
      final prefix = tok.substring(0, tok.length < 12 ? tok.length : 12);
      debugPrint('AppCheck token (prefix): $prefix...');
    } else {
      debugPrint('AppCheck token: <null/empty>');
    }
  } catch (e) {
    debugPrint('AppCheck getToken error: $e');
  }
  // -------------------------------------------------------

  runApp(const PrepCheckApp());
}

class PrepCheckApp extends StatelessWidget {
  const PrepCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ui.AuthProvider> providers = <ui.AuthProvider>[
      ui.EmailAuthProvider(),
      ui_google.GoogleProvider(clientId: kGoogleClientId),
    ];

    return MaterialApp(
      title: 'PrepCheck',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = snap.data;
          if (user == null) {
            return ui.SignInScreen(
              providers: providers,
              actions: [
                ui.AuthStateChangeAction<ui.SignedIn>((context, state) {}),
              ],
            );
          }
          return const HomeShell();
        },
      ),
    );
  }
}
