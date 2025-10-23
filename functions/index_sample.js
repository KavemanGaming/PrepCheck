const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onOrderCreate = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, ctx) => {
    const data = snap.data();
    const orderId = ctx.params.orderId;
    const listId = data.listId || '';
    const summary = (data.summary || '').slice(0, 1000);

    const message = {
      topic: 'admins',
      notification: {
        title: 'New Order Preview',
        body: summary.substring(0, 120)
      },
      data: {
        type: 'order_preview',
        orderId,
        listId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    await admin.messaging().send(message);
    return true;
  });
