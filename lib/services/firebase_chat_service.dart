import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

class FirebaseChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get user chats
  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    try {
      // Use only participants filter to avoid requiring an index
      final querySnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      final chats = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort client-side
      chats.sort((a, b) {
        final aTime = a['last_message_time'] as Timestamp?;
        final bTime = b['last_message_time'] as Timestamp?;

        // If both are null, sort by created_at
        if (aTime == null && bTime == null) {
          final aCreated = a['created_at'] as Timestamp?;
          final bCreated = b['created_at'] as Timestamp?;
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return bCreated.compareTo(aCreated);
        }

        // If only one is null, put the null one last
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        // If both exist, sort by last_message_time (newest first)
        return bTime.compareTo(aTime);
      });

      return chats;
    } catch (e) {
      print('Error getting user chats: $e');
      return [];
    }
  }

  // Get recent chats with user info (Stream for real-time updates)
  Stream<List<Map<String, dynamic>>> getRecentChatsStream(String userId) {
    try {
      print('DEBUG: Getting recent chats for user: $userId');

      // Use only participants filter to avoid requiring an index
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .snapshots()
          .handleError((error) {
        print('ERROR: Firestore stream error: $error');
      }).asyncMap((snapshot) async {
        List<Map<String, dynamic>> chats = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          // Get other user's info
          final participants = List<String>.from(data['participants'] ?? []);
          final otherUserId = participants.firstWhere(
            (id) => id != userId,
            orElse: () => '',
          );

          if (otherUserId.isNotEmpty) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(otherUserId).get();

              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};
                data['other_user'] = {
                  'id': otherUserId,
                  'username': userData['username'] ?? 'Unknown User',
                  'profile_image': userData['profile_photo'] ?? '',
                };
                chats.add(data);
              }
            } catch (e) {
              print('Error getting user data for chat: $e');
              // Even if there is an error, add the chat without user info
              data['other_user'] = {
                'id': otherUserId,
                'username': 'Unknown User',
                'profile_image': '',
              };
              chats.add(data);
            }
          }
        }

        // Sort chats by last_message_time (newest first)
        chats.sort((a, b) {
          final aTime = a['last_message_time'] as Timestamp?;
          final bTime = b['last_message_time'] as Timestamp?;

          // If both are null, sort by created_at
          if (aTime == null && bTime == null) {
            final aCreated = a['created_at'] as Timestamp?;
            final bCreated = b['created_at'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated);
          }

          // If only one is null, put the null one last
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          // If both exist, sort by last_message_time (newest first)
          return bTime.compareTo(aTime);
        });

        // Take only the first 20 chats (most recent)
        if (chats.length > 20) {
          chats = chats.take(20).toList();
        }

        return chats;
      });
    } catch (e) {
      print('ERROR: Exception in getRecentChatsStream: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  } // Create or get chat between two users

  Future<String?> createOrGetChat(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final participants = [currentUser.uid, otherUserId]..sort();

      // Check if chat already exists
      final existingChat = await _firestore
          .collection('chats')
          .where('participants', isEqualTo: participants)
          .get();

      if (existingChat.docs.isNotEmpty) {
        return existingChat.docs.first.id;
      }

      // Create new chat
      final chatDoc = await _firestore.collection('chats').add({
        'participants': participants,
        'created_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_time': FieldValue.serverTimestamp(),
        'last_message_sender': '',
      });

      return chatDoc.id;
    } catch (e) {
      print('Error creating/getting chat: $e');
      return null;
    }
  }

  // Send message
  Future<bool> sendMessage(String chatId, String message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final batch = _firestore.batch();

      // Add message to messages subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'sender_id': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'message_type': 'text',
        'is_read': false,
      });

      // Update chat's last message
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'last_message': message,
        'last_message_time': FieldValue.serverTimestamp(),
        'last_message_sender': currentUser.uid,
      });

      await batch.commit();

      // Send notification to other user
      try {
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();
        if (chatDoc.exists) {
          final participants =
              List<String>.from(chatDoc.data()?['participants'] ?? []);
          final otherUserId =
              participants.firstWhere((id) => id != currentUser.uid);

          // Check if the recipient is currently in this chat screen
          final otherUserDoc =
              await _firestore.collection('users').doc(otherUserId).get();
          final otherUserData = otherUserDoc.data();

          // If active_chat_id field is missing, it will be null, so notification should be sent
          final otherUserActiveChatId =
              otherUserData?['active_chat_id'] as String?;

          print('💬 Chat notification check:');
          print('  - Chat ID: $chatId');
          print('  - Recipient ID: $otherUserId');
          print(
              '  - Recipient active_chat_id: ${otherUserActiveChatId ?? "null (not in any chat)"}');

          // If the recipient is currently in this chat screen, do not send notification
          if (otherUserActiveChatId != null &&
              otherUserActiveChatId == chatId) {
            print('  ⏭️ User is currently in this chat, skipping notification');
            return true;
          }

          // Get current user's details
          final currentUserDoc =
              await _firestore.collection('users').doc(currentUser.uid).get();
          final currentUserData = currentUserDoc.data();

          // Truncate message for preview
          final messagePreview =
              message.length > 50 ? '${message.substring(0, 50)}...' : message;

          print('  📤 Sending message notification...');
          await _notificationService.sendMessageNotification(
            recipientId: otherUserId,
            senderId: currentUser.uid,
            senderUsername:
                currentUserData?['username'] ?? currentUser.email ?? 'Someone',
            senderProfilePhoto: currentUserData?['profile_photo'],
            chatId: chatId,
            messagePreview: messagePreview,
          );
          print('  ✅ Message notification sent successfully');
        }
      } catch (e) {
        print('❌ Failed to send message notification: $e');
        print('Stack trace: ${StackTrace.current}');
        // Don't throw - notification failure shouldn't block the message
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get messages for a chat
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // First get all messages, then filter client-side
      final allMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in allMessages.docs) {
        final data = doc.data();
        // Client-side sender check
        if (data['sender_id'] != userId) {
          batch.update(doc.reference, {'is_read': true});
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('DEBUG: Marked $updateCount messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // Get all chats for user
      final chats = await getUserChats(userId);
      int totalUnread = 0;

      for (final chat in chats) {
        // Only get unread messages, then client-side sender check
        final unreadMessages = await _firestore
            .collection('chats')
            .doc(chat['id'])
            .collection('messages')
            .where('is_read', isEqualTo: false)
            .get();

        // Client-side sender check
        for (final doc in unreadMessages.docs) {
          final data = doc.data();
          if (data['sender_id'] != userId) {
            totalUnread++;
          }
        }
      }

      return totalUnread;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Search users for chat
  Future<List<Map<String, dynamic>>> searchUsersForChat(
      String query, String currentUserId) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: query.toLowerCase() + 'z')
          .limit(20)
          .get();

      return usersSnapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Delete message
  Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check if user is the sender of the message
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return false;

      final messageData = messageDoc.data()!;
      if (messageData['sender_id'] != currentUser.uid) return false;

      await messageDoc.reference.delete();
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Get chat participants info
  Future<List<Map<String, dynamic>>> getChatParticipants(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) return [];

      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);

      final List<Map<String, dynamic>> participantInfo = [];

      for (final participantId in participants) {
        final userDoc =
            await _firestore.collection('users').doc(participantId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userData['id'] = userDoc.id;
          participantInfo.add(userData);
        }
      }

      return participantInfo;
    } catch (e) {
      print('Error getting chat participants: $e');
      return [];
    }
  }

  // Send image message
  Future<bool> sendImageMessage(String chatId, String imageUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final batch = _firestore.batch();

      // Add image message
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'sender_id': currentUser.uid,
        'message': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'message_type': 'image',
        'is_read': false,
      });

      // Update chat's last message
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'last_message': '📷 Photo',
        'last_message_time': FieldValue.serverTimestamp(),
        'last_message_sender': currentUser.uid,
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error sending image message: $e');
      return false;
    }
  }

  // Delete entire chat
  Future<bool> deleteChat(String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Delete all messages first
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();

      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(_firestore.collection('chats').doc(chatId));

      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting chat: $e');
      return false;
    }
  }

  // Real-time unread message count stream
  Stream<int> getUnreadMessageCountStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;

      for (var chatDoc in chatsSnapshot.docs) {
        final unreadSnapshot = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('is_read', isEqualTo: false)
            .get();

        // Client-side sender check
        for (var messageDoc in unreadSnapshot.docs) {
          final data = messageDoc.data();
          if (data['sender_id'] != userId) {
            totalUnread++;
          }
        }
      }

      return totalUnread;
    }).handleError((error) {
      print('Error in unread count stream: $error');
      return 0;
    });
  }

  // Chat-specific unread count stream
  Stream<int> getChatUnreadCountStream(String chatId, String userId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['sender_id'] != userId) {
          unreadCount++;
        }
      }

      return unreadCount;
    }).handleError((error) {
      print('Error in chat unread count stream: $error');
      return 0;
    });
  }
}

// Provider
final firebaseChatServiceProvider = Provider<FirebaseChatService>((ref) {
  return FirebaseChatService();
});
