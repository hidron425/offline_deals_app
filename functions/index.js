const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// ========== (Временно отключено для эмулятора) ==========
// exports.autoSuggestCollabs = functions.pubsub.schedule('0 0 * * 0').onRun(...)
// exports.processPushQueue = functions.pubsub.schedule('every 5 minutes').onRun(...)

// ========== 1. Принятие предложения (вызывается из приложения) ==========
exports.acceptCollabSuggestion = functions.https.onCall(async (data, context) => {
  const { suggestionId, fromShopId, toShopId, discountFrom, discountTo } = data;
  const suggestionRef = db.collection('suggested_collabs').doc(suggestionId);
  const suggestion = (await suggestionRef.get()).data();
  if (!suggestion) throw new functions.https.HttpsError('not-found', 'Suggestion not found');
  
  const update = {};
  if (fromShopId) update.acceptedByFrom = true;
  if (toShopId) update.acceptedByTo = true;
  if (discountFrom) update.discountFrom = discountFrom;
  if (discountTo) update.discountTo = discountTo;
  
  await suggestionRef.update(update);
  
  const updated = (await suggestionRef.get()).data();
  if (updated.acceptedByFrom && updated.acceptedByTo) {
    const activeCollab = {
      fromShopId: updated.fromShopId,
      toShopId: updated.toShopId,
      type: 'auto',
      discountMessage: `Скидка в ${updated.toShopId} для посетителей ${updated.fromShopId}`,
      remainingBudget: 999999,
      clicks: 0,
      expires: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 90*24*3600*1000))
    };
    const collabRef = await db.collection('active_collabs').add(activeCollab);
    await suggestionRef.update({ activeCollabId: collabRef.id, status: 'accepted' });
  }
  return { success: true };
});

// ========== 2. Добавление пуша в очередь (вызывается из админки магазина) ==========
exports.addPushToQueue = functions.https.onCall(async (data, context) => {
  const { shopId, userIds, title, body, urgent, priority } = data;
  if (!userIds || !userIds.length) throw new functions.https.HttpsError('invalid-argument', 'No userIds');
  
  const shopDoc = await db.collection('shops').doc(shopId).get();
  const shop = shopDoc.data();
  if (!shop || shop.pushCredits < userIds.length) {
    throw new functions.https.HttpsError('failed-precondition', 'Not enough push credits');
  }
  
  await db.collection('shops').doc(shopId).update({
    pushCredits: admin.firestore.FieldValue.increment(-userIds.length)
  });
  
  const batch = db.batch();
  for (const userId of userIds) {
    const pushRef = db.collection('push_queue').doc();
    batch.set(pushRef, {
      userId, shopId, title, body,
      priority: priority || 1,
      urgent: urgent || false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending'
    });
  }
  await batch.commit();
  return { success: true, count: userIds.length };
});

// ========== 3. Рассылка пуша по сегменту (вызывается из админ-панели) ==========
exports.sendPushToSegment = functions.https.onCall(async (data, context) => {
  const { segment, message, scheduledAt } = data;
  
  // Строим запрос к user_progress
  let query = db.collection('user_progress');

  if (segment.city) {
    query = query.where('selectedCity', '==', segment.city);
  }
  if (segment.mall) {
    query = query.where('selectedMall', '==', segment.mall);
  }
  // Firestore не поддерживает одновременно несколько range-фильтров на разные поля.
  // Если понадобятся оба фильтра, нужно делать несколько запросов и объединять результаты.
  // Для простоты примера применим только один из них.
  if (segment.minStepsCompleted != null) {
    query = query.where('completedSteps', '>=', segment.minStepsCompleted);
  }
  if (segment.activeWithinDays != null) {
    const activeSince = new Date();
    activeSince.setDate(activeSince.getDate() - segment.activeWithinDays);
    query = query.where('lastActive', '>=', admin.firestore.Timestamp.fromDate(activeSince));
  }

  const snapshot = await query.get();
  const tokens = [];
  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.fcmToken && data.blocked !== true) {   // не отправляем заблокированным
      tokens.push(data.fcmToken);
    }
  });

  if (tokens.length === 0) {
    return { success: false, error: 'Нет подходящих получателей' };
  }

  if (scheduledAt) {
    // Отложенная отправка – сохраняем задание
    await db.collection('scheduled_notifications').add({
      tokens: tokens,
      title: message.title,
      body: message.body,
      scheduledAt: admin.firestore.Timestamp.fromDate(new Date(scheduledAt)),
      status: 'pending'
    });
  } else {
    // Мгновенная отправка
    const payload = {
      notification: {
        title: message.title,
        body: message.body,
      },
      tokens: tokens
    };
    await admin.messaging().sendMulticast(payload);
  }

  return { success: true, count: tokens.length };
});