/**
 * GymBuddy Firebase Cloud Functions
 * Push Notification Sender
 */

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Firestore'a yeni notification eklendiğinde otomatik olarak
 * push notification gönderen Cloud Function
 */
exports.sendNotificationOnCreate = onDocumentCreated('notifications/{notificationId}', async (event) => {
  try {
    const notification = event.data.data();
    const notificationId = event.params.notificationId;
    
    console.log('New notification created:', notificationId);
    console.log('Notification data:', notification);
      
      // FCM token'larını al
      const tokensDoc = await admin.firestore()
        .collection('fcm_tokens')
        .doc(notification.user_id)
        .get();
      
      if (!tokensDoc.exists) {
        console.log('No FCM tokens found for user:', notification.user_id);
        return null;
      }
      
      const tokens = tokensDoc.data().tokens || [];
      
      if (tokens.length === 0) {
        console.log('Token list is empty for user:', notification.user_id);
        return null;
      }
      
      console.log(`Sending notification to ${tokens.length} device(s)`);
      
      // Push notification mesajını hazırla
      const message = {
        notification: {
          title: notification.title || 'GymBuddy',
          body: notification.body || '',
        },
        data: {
          notification_id: notificationId,
          type: notification.type || 'default',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...notification.data || {},
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            sound: 'default',
            color: '#FF9800', // Orange
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      // Tüm token'lara gönder
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        ...message,
      });
      
      console.log('Successfully sent messages:', response.successCount);
      console.log('Failed to send messages:', response.failureCount);
      
      // Başarısız token'ları temizle
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log('Failed to send to token:', tokens[idx]);
          console.log('Error:', resp.error);
          
          // Token geçersizse kaldır
          if (resp.error?.code === 'messaging/invalid-registration-token' ||
              resp.error?.code === 'messaging/registration-token-not-registered') {
            tokensToRemove.push(tokens[idx]);
          }
        }
      });
      
      // Geçersiz token'ları Firestore'dan kaldır
      if (tokensToRemove.length > 0) {
        console.log('Removing invalid tokens:', tokensToRemove.length);
        await admin.firestore()
          .collection('fcm_tokens')
          .doc(notification.user_id)
          .update({
            tokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
          });
      }
      
      // Notification'ı FCM gönderildi olarak işaretle
      await event.data.ref.update({ 
        fcm_sent: true,
        fcm_sent_at: admin.firestore.FieldValue.serverTimestamp(),
        fcm_success_count: response.successCount,
        fcm_failure_count: response.failureCount,
      });
      
      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
      
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Hata durumunu kaydet
      await event.data.ref.update({ 
        fcm_sent: false,
        fcm_error: error.message,
        fcm_error_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: false,
        error: error.message,
      };
    }
  });

/**
 * Test endpoint - Manual push notification göndermek için
 */
exports.sendTestNotification = onCall(async (request) => {
  // Authentication kontrolü
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }
  
  const userId = request.auth.uid;
  
  try {
    // Test notification oluştur
    await admin.firestore().collection('notifications').add({
      user_id: userId,
      sender_id: 'system',
      sender_username: 'System',
      type: 'test',
      title: 'Test Notification',
      body: 'This is a test notification from Firebase Cloud Functions',
      data: {},
      is_read: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      fcm_sent: false,
    });
    
    return { success: true, message: 'Test notification created' };
  } catch (error) {
    throw new Error(error.message);
  }
});
