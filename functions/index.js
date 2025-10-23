const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
try { admin.app(); } catch { admin.initializeApp(); }

exports.sendOrderSms = onCall(async (req) => {
  const db = admin.firestore();
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign-in required.');

  const orderId = typeof req.data?.orderId === 'string' ? req.data.orderId : null;
  const text = typeof req.data?.text === 'string' ? req.data.text : null;

  if (!orderId && !text) throw new HttpsError('invalid-argument', 'orderId or text required');

  let payload = text;
  if (!payload) {
    const ord = await db.collection('orders').doc(orderId).get();
    if (!ord.exists) throw new HttpsError('not-found', 'Order not found');
    payload = String(ord.data().text || '');
  }

  // gather admin tokens
  const admins = await db.collection('users').where('isAdmin', '==', true).get();
  const tokenRefs = [];
  const tokens = [];

  for (const doc of admins.docs) {
    const uid = doc.id;
    const tks = await db.collection(`users/${uid}/fcmTokens`).listDocuments();
    for (const t of tks) { tokenRefs.push(t); tokens.push(t.id); }
    const arr = doc.data().fcmTokens;
    if (Array.isArray(arr)) {
      for (const t of arr) if (typeof t === 'string' && t) tokens.push(t);
    }
    const single = doc.data().fcmToken;
    if (typeof single === 'string' && single) tokens.push(single);
  }

  // remove duplicates
  const uniqueTokens = Array.from(new Set(tokens));

  const data = {
    type: 'order',
    orderId: orderId ?? '',
    preview: payload.slice(0, 1000),
    click_action: 'FLUTTER_NOTIFICATION_CLICK'
  };

  let requested = 0, success = 0, failed = 0;

  if (uniqueTokens.length > 0) {
    requested = uniqueTokens.length;
    const res = await admin.messaging().sendEachForMulticast({
      tokens: uniqueTokens,
      notification: { title: 'PrepCheck — Order', body: payload.slice(0, 120) },
      data,
      android: {
        priority: 'HIGH',
        notification: {
          channelId: 'orders',
          sound: 'default',
          defaultSound: true,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', contentAvailable: 1 }
        }
      }
    });

    const deletions = [];
    res.responses.forEach((r, idx) => {
      if (r.success) success++;
      else {
        failed++;
        const code = r.error?.code || 'unknown';
        if (code.includes('registration-token-not-registered') || code.includes('invalid-argument')) {
          const bad = uniqueTokens[idx];
          const match = tokenRefs.find(ref => ref.id === bad);
          if (match) deletions.push(match.delete().catch(() => {}));
        }
      }
    });
    if (deletions.length) await Promise.all(deletions);
  }

  console.log(`[sendOrderSms] requested=${requested} success=${success} failed=${failed} tokens=${uniqueTokens.length}`);
  return { requested, success, failed, tokens: uniqueTokens.length };
});
