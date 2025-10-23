PrepCheck - Push Deep Link & Foreground Notifications Patch

Files added:
  lib/routes/push_nav.dart                     # global navigatorKey
  lib/notifications/local_notify.dart          # foreground notifications + payload handling
  lib/notifications/push_router.dart           # FCM permission + tap routing
  lib/pages/order_preview_page.dart            # Route to show an /orders/{orderId} summary
  android/app/src/main/res/values/strings.xml  # default channel strings (safe if already exists)
  android/app/src/main/AndroidManifest.additions.xml # meta-data snippet
  functions/index_sample.js                    # sample Cloud Function to emit deep-link pushes

1) pubspec.yaml (add if missing)
   dependencies:
     firebase_messaging: ^14.9.4
     flutter_local_notifications: ^17.2.1
     share_plus: ^10.0.2

2) lib/main.dart
   // imports
   import 'routes/push_nav.dart';
   import 'notifications/local_notify.dart';
   import 'notifications/push_router.dart';
   import 'pages/order_preview_page.dart';

   // MaterialApp
   return MaterialApp(
     navigatorKey: rootNavigatorKey,
     routes: {
       OrderPreviewPage.route: (ctx) => const OrderPreviewPage(),
     },
     // ...
   );

   // Boot sequence (after Firebase.initializeApp & AppCheck)
   await LocalNotify.init();
   await PushRouter.init();

3) AndroidManifest
   Merge the meta-data snippet from android/app/src/main/AndroidManifest.additions.xml
   into the <application> node of your main AndroidManifest.xml

4) Cloud Functions payload (example)
   data: {
     type: 'order_preview',
     orderId: '<ORDER_DOC_ID>',
     listId: '<INVENTORY_LIST_ID>',
     click_action: 'FLUTTER_NOTIFICATION_CLICK'
   }

5) Foreground vs background
   Foreground: LocalNotify shows a notification you can tap.
   Background/Terminated: The system shows the push; tap routes via PushRouter.

6) Optional: Inventory list route
   OrderPreviewPage tries to push '/inventoryList' when "Open list" is tapped.
   If your app uses a different route, change it or register that route to accept {'listId': ...}.
