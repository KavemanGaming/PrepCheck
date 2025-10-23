import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../pages/order_detail_page.dart';

class NotificationRouter {
  static StreamSubscription<RemoteMessage>? _opened;
  static StreamSubscription<RemoteMessage>? _onMessage;

  static Future<void> init() async {
    final fcm = FirebaseMessaging.instance;

    await fcm.requestPermission(alert: true, badge: true, sound: true, provisional: false);

    final initial = await fcm.getInitialMessage();
    if (initial != null) {
      _handleTap(initial);
    }

    _opened?.cancel();
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    _onMessage?.cancel();
    _onMessage = FirebaseMessaging.onMessage.listen((m) {
      final data = m.data;
      final type = data['type'] as String?;
      if (type == 'order') {
        final ctx = AppNav.key.currentContext;
        if (ctx == null) return;
        final body = (m.notification?.body ?? data['preview'] ?? 'New order');
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () => _openOrder(data),
            ),
          ),
        );
      }
    });
  }

  static void _handleTap(RemoteMessage m) {
    _openOrder(m.data);
  }

  static void _openOrder(Map<String, dynamic> data) {
    final orderId = data['orderId'] as String?;
    final preview = data['preview'] as String?;
    final nav = AppNav.key.currentState;
    if (orderId != null && nav != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => OrderDetailPage(orderId: orderId, initialText: preview),
      ));
    }
  }
}
