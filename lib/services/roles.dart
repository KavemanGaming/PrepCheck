import 'package:firebase_auth/firebase_auth.dart';

Future<bool> loadAdminClaim() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final idToken = await user.getIdTokenResult(true);
  final claims = idToken.claims ?? {};
  return claims['admin'] == true || claims['isAdmin'] == true;
}
