import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as ui;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ui.SignInScreen(
            providers: [
              ui.EmailAuthProvider(),
              GoogleProvider(clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'),
            ],
          ),
        ),
      ),
    );
  }
}
