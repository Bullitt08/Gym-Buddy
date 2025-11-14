import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../utils/notification_handler.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Start Local notifications
  Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // When notification is tapped
        print('📱 Local notification tapped!');
        print('📱 Payload: ${response.payload}');

        if (response.payload != null) {
          // Payload contains notification_id
          final data = {'notification_id': response.payload};
          _handleNotificationNavigation(data);
        }
      },
    );
  }

  // Save FCM token
  Future<void> saveUserFCMToken(String userId) async {
    try {
      print('🔔 Starting FCM token save for user: $userId');

      // Request FCM permission
      print('🔔 Requesting notification permission...');
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('🔔 Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token
        print('🔔 Permission granted, getting FCM token...');
        String? token = await _messaging.getToken();

        if (token != null) {
          print('🔔 FCM Token received: ${token.substring(0, 50)}...');

          // Save to Firestore
          print('🔔 Saving token to Firestore...');
          await _firestore.collection('fcm_tokens').doc(userId).set({
            'user_id': userId,
            'tokens': FieldValue.arrayUnion([token]),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('✅ FCM token saved successfully for user: $userId');
        } else {
          print(
              '❌ FCM token is null! Device may not support FCM or Google Play Services missing');
        }
      } else {
        print(
            '❌ User declined or has not accepted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Remove FCM token (on logout)
  Future<void> removeUserFCMToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('fcm_tokens').doc(userId).update({
          'tokens': FieldValue.arrayRemove([token]),
        });
        print('FCM token removed for user: $userId');
      }
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }

  // Create notification (save to Firestore)
  Future<void> createNotification({
    required String userId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String type,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Do not send notification to self
      if (userId == senderId) {
        print('Skipping notification: user_id == sender_id');
        return;
      }

      // Save notification to Firestore
      final notificationRef = await _firestore.collection('notifications').add({
        'user_id': userId,
        'sender_id': senderId,
        'sender_username': senderUsername,
        'sender_profile_photo': senderProfilePhoto,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
        'fcm_sent': false,
      });

      print('Notification created: ${notificationRef.id}');

      // Send FCM push notification
      await _sendPushNotification(
        userId: userId,
        title: title,
        body: body ?? '',
        data: {
          'notification_id': notificationRef.id,
          'type': type,
          ...?data,
        },
      );

      // Mark as FCM sent
      await notificationRef.update({'fcm_sent': true});
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Send push notification
  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM tokens
      final tokenDoc =
          await _firestore.collection('fcm_tokens').doc(userId).get();

      if (!tokenDoc.exists) {
        print('No FCM tokens found for user: $userId');
        return;
      }

      final tokens = List<String>.from(tokenDoc.data()?['tokens'] ?? []);
      if (tokens.isEmpty) {
        print('Token list is empty for user: $userId');
        return;
      }

      // NOTE: FCM Admin SDK required - should be done with Cloud Functions
      // This part does not work client-side
      // Separate endpoint needed for sending FCM with Cloud Functions

      print('Would send FCM to ${tokens.length} device(s)');
      print('Title: $title');
      print('Body: $body');
      print('Data: $data');

      // TODO: Implement FCM sending with Cloud Functions
      // Şimdilik sadece Firestore'a kaydediyoruz
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // Get Notifications
  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Unread notifications count
  Stream<int> getUnreadNotificationsCount(String userId) {
    // To avoid requiring an index, filter only by user_id
    // Check is_read and type client-side
    // Do not include chat messages in the count
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) =>
                doc.data()['is_read'] == false &&
                doc.data()['type'] != 'message')
            .length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'is_read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      // To avoid requiring an index, filter only by user_id
      // Check is_read client-side
      final allNotifications = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in allNotifications.docs) {
        // Update only unread notifications
        if (doc.data()['is_read'] == false) {
          batch.update(doc.reference, {'is_read': true});
        }
      }
      await batch.commit();

      print('Marked all notifications as read for user: $userId');
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      print('Notification deleted: $notificationId');
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('All notifications deleted for user: $userId');
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // Helper methods for specific notification types

  // Post like notification
  Future<void> sendLikeNotification({
    required String postOwnerId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String postId,
  }) async {
    await createNotification(
      userId: postOwnerId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePhoto: senderProfilePhoto,
      type: 'like',
      title: '$senderUsername liked your post',
      body: 'Tap to view your post',
      data: {'post_id': postId},
    );
  }

  // Comment notification
  Future<void> sendCommentNotification({
    required String postOwnerId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String postId,
    required String commentId,
    required String commentText,
  }) async {
    await createNotification(
      userId: postOwnerId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePhoto: senderProfilePhoto,
      type: 'comment',
      title: '$senderUsername commented on your post',
      body: commentText,
      data: {
        'post_id': postId,
        'comment_id': commentId,
      },
    );
  }

  // Comment like notification
  Future<void> sendCommentLikeNotification({
    required String commentOwnerId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String postId,
    required String commentId,
  }) async {
    await createNotification(
      userId: commentOwnerId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePhoto: senderProfilePhoto,
      type: 'comment_like',
      title: '$senderUsername liked your comment',
      body: 'Tap to view',
      data: {
        'post_id': postId,
        'comment_id': commentId,
      },
    );
  }

  // Friend request notification
  Future<void> sendFriendRequestNotification({
    required String recipientId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String friendRequestId,
  }) async {
    await createNotification(
      userId: recipientId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePhoto: senderProfilePhoto,
      type: 'friend_request',
      title: '$senderUsername sent you a friend request',
      body: 'Tap to view profile',
      data: {'friend_request_id': friendRequestId},
    );
  }

  // Friend accept notification
  Future<void> sendFriendAcceptNotification({
    required String requesterId,
    required String accepterId,
    required String accepterUsername,
    String? accepterProfilePhoto,
    required String friendRequestId,
  }) async {
    await createNotification(
      userId: requesterId,
      senderId: accepterId,
      senderUsername: accepterUsername,
      senderProfilePhoto: accepterProfilePhoto,
      type: 'friend_accept',
      title: '$accepterUsername accepted your friend request',
      body: 'You are now friends!',
      data: {'friend_request_id': friendRequestId},
    );
  }

  // Message notification
  Future<void> sendMessageNotification({
    required String recipientId,
    required String senderId,
    required String senderUsername,
    String? senderProfilePhoto,
    required String chatId,
    required String messagePreview,
  }) async {
    await createNotification(
      userId: recipientId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfilePhoto: senderProfilePhoto,
      type: 'message',
      title: '$senderUsername sent you a message',
      body: messagePreview,
      data: {'chat_id': chatId},
    );
  }

  // Start FCM message listeners
  void setupFCMListeners() {
    // Foreground presentation options - Show notification when app is open
    _messaging.setForegroundNotificationPresentationOptions(
      alert: true, // Show alert
      badge: true, // Show badge
      sound: true, // Play sound
    );

    // Foreground messages - When app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message received!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // Show local notification when app is open
      if (message.notification != null) {
        _showLocalNotification(
          title: message.notification!.title ?? 'GymBuddy',
          body: message.notification!.body ?? '',
          payload: message.data['notification_id'],
        );
      }
    });

    // When app is opened from a background message
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Message clicked!');
      print('Message data: ${message.data}');
      _handleNotificationNavigation(message.data);
    });
  }

  // Handle navigation when notification is tapped
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    print('📱 Handling notification navigation: $data');
    NotificationHandler.handleNotificationTap(data);
  }

  // Show local notification (when app is open)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'GymBuddy Notifications',
      channelDescription: 'Notifications for GymBuddy app',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF9800), // Orange
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // When app is opened from a terminated state notification
  Future<void> handleInitialMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      print('App opened from notification!');
      print('Message data: ${initialMessage.data}');
      _handleNotificationNavigation(initialMessage.data);
    }
  }
}

// Background handler (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received!');
  print('Message data: ${message.data}');
}
