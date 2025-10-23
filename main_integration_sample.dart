import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'notifications/push_router.dart';
import 'notifications/local_notify.dart';
import 'notifications/fcm_foreground.dart';

import 'pages/home_shell.dart'; // make sure this exists

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotify.init();
  await FcmForeground.init();
  await PushRouter.init(_navKey);
  runApp(PrepCheckApp(navigatorKey: _navKey));
}

class PrepCheckApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const PrepCheckApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepCheck',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomeShell(),
    );
  }
}
