import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../routes/push_nav.dart';
import 'local_notify.dart';

class PushRouter {
  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Ask permission on Android 13+ for notifications.
    await messaging.requestPermission(
      alert: true, badge: true, sound: true, announcement: false,
      carPlay: false, criticalAlert: false, provisional: false,
    );

    // Foreground messages -> show local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final n = m.notification;
      if (n != null) {
        await LocalNotify.show(n.title ?? 'Update', n.body ?? '', data: m.data);
      }
    });

    // App opened from background by tapping a notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App launched from terminated by tapping a notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  static void _handleTap(RemoteMessage m) {
    final data = m.data;
    _routeFromData(data);
  }

  /// Also used when a local notification is tapped (payload JSON string).
  static void handlePayloadString(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _routeFromData(data);
    } catch (_) {
      // ignore
    }
  }

  static void _routeFromData(Map<String, dynamic> data) {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    switch (data['type']) {
      case 'order_preview':
        final orderId = data['orderId'];
        final listId = data['listId'];
        nav.pushNamed('/orderPreview', arguments: {
          'orderId': orderId,
          'listId': listId,
        });
        break;
      default:
        break;
    }
  }
}
