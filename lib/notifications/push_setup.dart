import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Registers the device for FCM and stores tokens under:
///   users/{uid}/fcmTokens/{tokenId}
/// Also mirrors into users/{uid}.fcmTokens (array) for legacy reads.
/// If the user is an admin (users/{uid}.isAdmin == true), subscribes to 'admins' topic.
class PushSetup {
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<String>? _tokenSub;

  static Future<void> init() async {
    // Safe to call multiple times.
    final fcm = FirebaseMessaging.instance;
    // Request permission on iOS / Android 13+.
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u == null) return;
      await _ensureTokenStored(u);
      _listenTokenRefresh(u);
      await _maybeSubscribeAdminTopic(u);
    });
  }

  static void _listenTokenRefresh(User u) {
    _tokenSub?.cancel();
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _storeToken(u.uid, token);
    });
  }

  static Future<void> _ensureTokenStored(User u) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _storeToken(u.uid, token);
    }
  }

  static Future<void> _storeToken(String uid, String token) async {
    final db = FirebaseFirestore.instance;
    final ref = db.doc('users/$uid/fcmTokens/$token');
    final now = FieldValue.serverTimestamp();
    final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'));
    await ref.set({
      'createdAt': now,
      'updatedAt': now,
      'platform': platform,
    }, SetOptions(merge: true));
    // Also mirror to array field for legacy readers.
    await db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  static Future<void> _maybeSubscribeAdminTopic(User u) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final isAdmin = (snap.data()?['isAdmin'] == true);
      if (isAdmin) {
        await FirebaseMessaging.instance.subscribeToTopic('admins');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('admins');
      }
    } catch (_) {
      // ignore
    }
  }
}
