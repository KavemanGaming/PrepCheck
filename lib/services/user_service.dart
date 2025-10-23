import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

StreamSubscription<User?>? _sub;

void startUserBootstrapper() {
  _sub ??= FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    await ensureUserDoc(user);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('maybeInitFirstAdmin');
      await callable.call();
      await user.getIdToken(true); // refresh claims in case we just became admin
    } catch (_) {}
  });
}

Future<void> ensureUserDoc(User user) async {
  final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoURL': user.photoURL,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
