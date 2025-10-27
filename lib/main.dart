import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> _initFirebaseSilently() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootApp());
  scheduleMicrotask(_initFirebaseSilently);
}

class _BootApp extends StatelessWidget {
  const _BootApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prep Check',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _BootScreen(),
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen({super.key});
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
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.inventory, size: 64),
                  const SizedBox(height: 12),
                  const Text('Prep Check is booting…', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
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
    );
  }
}
