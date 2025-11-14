import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/main/post_detail_screen.dart';
import '../screens/main/user_profile_screen.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../models/chat_model.dart';
import '../services/firestore_post_service.dart';

class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    print('📱 handleNotificationTap called with data: $data');

    final context = navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ Navigator context is null, cannot navigate');
      return;
    }

    print('✅ Navigator context found');

    // Fetch notification document by Notification ID
    final notificationId = data['notification_id'];
    if (notificationId == null) {
      print('⚠️ No notification_id in data');
      return;
    }

    print('📱 Fetching notification document: $notificationId');

    try {
      // Fetch notification document from Firestore
      final notificationDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (!notificationDoc.exists) {
        print('⚠️ Notification document not found');
        return;
      }

      final notificationData = notificationDoc.data()!;
      final type = notificationData['type'];
      final notifData = notificationData['data'] as Map<String, dynamic>? ?? {};

      print('📱 Notification type: $type');
      print('📱 Notification data: $notifData');

      switch (type) {
        case 'like':
          print('🚀 Navigating to post (like)');
          await _navigateToPost(context, notifData);
          break;

        case 'comment':
        case 'comment_like':
          print('🚀 Navigating to post with comment (${type})');
          await _navigateToPost(context, notifData,
              commentId: notifData['comment_id']);
          break;

        case 'friend_request':
        case 'friend_accept':
          print('🚀 Navigating to profile (${type})');
          _navigateToProfile(context, notificationData);
          break;

        case 'message':
          print('🚀 Navigating to chat');
          _navigateToChat(context, notificationData, notifData);
          break;
      }
    } catch (e, stackTrace) {
      print('❌ Error handling notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> _navigateToPost(
    BuildContext context,
    Map<String, dynamic> data, {
    String? commentId,
  }) async {
    final postId = data['post_id'];
    if (postId == null) return;

    try {
      // Fetch post data along with user information
      final postService = FirestorePostService();
      final post = await postService.getPostByIdWithUser(postId);

      if (post != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: post,
              highlightCommentId: commentId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error navigating to post: $e');
    }
  }

  static void _navigateToProfile(
    BuildContext context,
    Map<String, dynamic> notificationData,
  ) {
    final senderId = notificationData['sender_id'];
    final senderUsername = notificationData['sender_username'];

    if (senderId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: senderId,
            username: senderUsername ?? 'User',
          ),
        ),
      );
    }
  }

  static void _navigateToChat(
    BuildContext context,
    Map<String, dynamic> notificationData,
    Map<String, dynamic> data,
  ) {
    final chatId = data['chat_id'];
    final senderId = notificationData['sender_id'];
    final currentUser = FirebaseAuth.instance.currentUser;

    if (chatId != null &&
        senderId != null &&
        currentUser != null &&
        context.mounted) {
      final chat = {
        'id': chatId,
        'participants': [currentUser.uid, senderId],
        'otherUserName': notificationData['sender_username'] ?? 'User',
        'otherUserPhoto': notificationData['sender_profile_photo'],
      };

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chat: Chat.fromJson(chat),
          ),
        ),
      );
    }
  }
}
