import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'local_notify.dart';

class FcmForeground {
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;

    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.requestPermission();
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final n = m.notification;
      final t = n?.title ?? m.data['title'] ?? 'PrepCheck';
      final b = n?.body ?? m.data['body'] ?? 'New message';
      await LocalNotify.show(title: t, body: b, payload: m.data['orderId'] ?? '');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      debugPrint('Notification opened (foreground handler): ${m.data}');
    });
  }
}
