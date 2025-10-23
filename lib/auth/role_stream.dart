import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Role {
  static Future<bool> isAdminOnce() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    final snap = await FirebaseFirestore.instance.doc('users/${u.uid}').get();
    final data = snap.data();
    return data != null && data['isAdmin'] == true;
  }

  static Stream<bool> isAdminStream() async* {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      yield false;
      return;
    }
    yield* FirebaseFirestore.instance
        .doc('users/${u.uid}')
        .snapshots()
        .map((s) => (s.data()?['isAdmin'] == true));
  }
}
