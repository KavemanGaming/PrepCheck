import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../routes/push_nav.dart';
import 'push_router.dart';

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

class LocalNotify {
  static Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings init = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (resp) {
        final p = resp.payload;
        if (p != null) {
          PushRouter.handlePayloadString(p);
        }
      },
    );
  }

  static Future<void> show(String title, String body, {Map<String, dynamic>? data}) async {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'default_channel', 'General',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    final details = const NotificationDetails(android: android);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = data == null ? null : jsonEncode(data);
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
