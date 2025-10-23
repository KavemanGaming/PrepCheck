import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrap {
  static Future<void> ensureUserDoc() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    await ref.set({
      'email': u.email,
      'displayName': u.displayName,
      'photoURL': u.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
