import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';
import 'routes/push_nav.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'theme/theme_prefs.dart';
import 'services/migration.dart';

Future<void> _initFirebaseSilently() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    // On Web, FirebaseOptions are required; if not configured, surface a friendly error
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      return;
    }
    // Mobile/Desktop attempt with options first, then fallback
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      await Firebase.initializeApp();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  } catch (e) {
    // Allow caller to show error nicely
    rethrow;
  }
}

bool get _isMobileSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_isMobileSupported) {
    runApp(const _NotSupportedApp());
    return;
  }
  runApp(const PrepCheckApp());
}

class PrepCheckApp extends StatelessWidget {
  const PrepCheckApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemePrefs.I.palette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemePrefs.I.mode,
          builder: (context, mode, __) {
            return MaterialApp(
              title: 'Prep Check',
              navigatorKey: rootNavigatorKey,
              themeMode: mode,
              theme: AppTheme.light(palette: palette),
              darkTheme: AppTheme.dark(palette: palette),
              home: const _BootScreen(),
            );
          },
        );
      },
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen();
  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await _initFirebaseSilently();
      // One-time: if a business is selected, migrate any top-level lists into it
      await MigrationService.runOneTimeMigrationIfNeeded();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (e) {
      // On Web, if firebase_options.dart isn't configured, show friendly help screen.
      if (e is UnsupportedError && kIsWeb) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FirebaseConfigHelpPage()),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft gradient background
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.08 * value),
                      cs.secondary.withValues(alpha: 0.06 * value),
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 1,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: cs.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.inventory_2_outlined, color: cs.primary, size: 34),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Prep Check is booting...',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        CircularProgressIndicator(color: cs.primary),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          Text('Startup error:\n$_error', textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                          const SizedBox(height: 12),
                          FilledButton.tonal(onPressed: _start, child: const Text('Retry')),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FirebaseConfigHelpPage extends StatelessWidget {
  const FirebaseConfigHelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Required')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Firebase not configured for Web', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                  'This workspace does not have generated Firebase Web options.\n\n'
                  'To run in Chrome, run the following commands in your project root:',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure\n',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'After configuring, restart the app. On mobile builds, the app can run with native-embedded options.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _NotSupportedApp extends StatelessWidget {
  const _NotSupportedApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prep Check',
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.phone_iphone, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Mobile Only',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This application supports Android and iOS only.\nPlease run on a mobile device or emulator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
