import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Create user profile in Firestore
  Future<void> createUserProfile(UserModel userModel) async {
    try {
      print('DEBUG: Creating user profile in Firestore collection "users"');
      print('DEBUG: User data: ${userModel.toJson()}');

      await _firestore
          .collection('users')
          .doc(userModel.id)
          .set(userModel.toJson());

      print('DEBUG: User profile created successfully');
    } catch (e) {
      print('DEBUG: Error creating user profile: $e');
      throw Exception('Error occurred while creating user profile: $e');
    }
  }

  // Get current user profile
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception(
          'Error occurred while retrieving current user profile: $e');
    }
  }

  // Get user profile by ID
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      print('DEBUG: Fetching user profile for userId: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        print('DEBUG: Retrieved user data: $data');
        return UserModel.fromJson(data);
      } else {
        print('DEBUG: No document found for userId: $userId');
        return null;
      }
    } catch (e) {
      print('DEBUG: Error retrieving user profile: $e');
      throw Exception('Error occurred while retrieving user profile by ID: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      throw Exception('Error occurred while updating user profile: $e');
    }
  }

  // Check if username is available (unique)
  Future<bool> isUsernameAvailable(String username) async {
    if (username.isEmpty) {
      print('DEBUG: Empty username provided');
      return false;
    }

    try {
      print('DEBUG: Checking username availability: $username');

      // Case-insensitive unique kontrolü için optimize edilmiş yaklaşım
      final lowercaseUsername = username.toLowerCase();
      print('DEBUG: Checking against lowercase version: $lowercaseUsername');

      // Collection referansı
      final collectionRef = _firestore.collection('users');
      print('DEBUG: Collection reference created');

      // Önce lowercase halini direkt sorgula
      final directQuery = await collectionRef
          .where('username', isEqualTo: lowercaseUsername)
          .limit(1)
          .get();

      if (directQuery.docs.isNotEmpty) {
        final existingData = directQuery.docs.first.data();
        print('DEBUG: Found exact lowercase match: $existingData');
        return false;
      }

      // Sonra original halini sorgula
      final originalQuery = await collectionRef
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (originalQuery.docs.isNotEmpty) {
        final existingData = originalQuery.docs.first.data();
        print('DEBUG: Found exact original match: $existingData');
        return false;
      }

      print('DEBUG: Username is available');
      return true;
    } catch (e) {
      print('DEBUG: Username availability query failed: $e');
      print('DEBUG: Error type: ${e.runtimeType}');

      // Permission hatası varsa, güvenli tarafta kal
      if (e.toString().contains('permission-denied')) {
        print('DEBUG: PERMISSION ERROR - Firestore rules not configured');
        print('DEBUG: For security, assuming username is NOT available');
        return false; // Güvenlik için false döndür
      }

      // Diğer hatalarda güvenli tarafta kal
      print('DEBUG: Other error occurred, returning false for security');
      return false;
    }
  }

  // Validate username format
  bool isValidUsernameFormat(String username) {
    // Username rules:
    // - Between 3-20 characters
    // - Only letters, numbers, and underscores
    // - Cannot start or end with an underscore
    // - No consecutive underscores

    if (username.length < 3 || username.length > 20) {
      return false;
    }

    // Regex: starts with a letter, can contain letters/numbers/underscores, cannot end with an underscore
    final RegExp usernameRegex =
        RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*[a-zA-Z0-9]$|^[a-zA-Z0-9]{3}$');

    if (!usernameRegex.hasMatch(username)) {
      return false;
    }

    // Consecutive underscore check
    if (username.contains('__')) {
      return false;
    }

    return true;
  }

  // Fix missing username for existing users
  Future<void> fixMissingUsername(String userId, String email) async {
    try {
      print('DEBUG: Attempting to fix username for user: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        print('DEBUG: Existing user data: $data');
        if (data['username'] == null || data['username'].toString().isEmpty) {
          final username = email.split('@')[0];
          await _firestore.collection('users').doc(userId).update({
            'username': username,
          });
          print('DEBUG: Fixed missing username for user: $userId -> $username');
        } else {
          print('DEBUG: Username already exists: ${data['username']}');
        }
      } else {
        print('DEBUG: No document found for user: $userId, creating one...');
        final username = email.split('@')[0];
        final newUserModel = UserModel(
          id: userId,
          email: email,
          username: username,
          streak: 0,
          friends: [],
          createdAt: DateTime.now(),
        );
        await createUserProfile(newUserModel);
      }
    } catch (e) {
      print('DEBUG: Error fixing username: $e');
    }
  }

  // Search users by username
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('User search error: $e');
    }
  }

  // Get user's friends
  Future<List<UserModel>> getUserFriends(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final friendIds = List<String>.from(userData['friends'] ?? []);

      if (friendIds.isEmpty) return [];

      final friendsQuery = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();

      return friendsQuery.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error occurred while retrieving friends: $e');
    }
  }

  // Send friend request
  Future<void> sendFriendRequest(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User is not logged in');

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: currentUser.uid)
          .where('receiver_id', isEqualTo: targetUserId)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Friend request already sent');
      }

      // Create friend request
      final requestRef = await _firestore.collection('friend_requests').add({
        'sender_id': currentUser.uid,
        'receiver_id': targetUserId,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Send notification
      try {
        final currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final currentUserData = currentUserDoc.data();

        await _notificationService.sendFriendRequestNotification(
          recipientId: targetUserId,
          senderId: currentUser.uid,
          senderUsername:
              currentUserData?['username'] ?? currentUser.email ?? 'Someone',
          senderProfilePhoto: currentUserData?['profile_photo'],
          friendRequestId: requestRef.id,
        );
      } catch (e) {
        print('Failed to send friend request notification: $e');
        // Don't throw - notification failure shouldn't block the request
      }
    } catch (e) {
      throw Exception('Error occurred while sending friend request: $e');
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String senderId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User is not logged in');

      final batch = _firestore.batch();

      // Update request status
      final requestRef =
          _firestore.collection('friend_requests').doc(requestId);
      batch.update(requestRef, {'status': 'accepted'});

      // Add to both users' friends lists
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayUnion([senderId])
      });

      final senderRef = _firestore.collection('users').doc(senderId);
      batch.update(senderRef, {
        'friends': FieldValue.arrayUnion([currentUser.uid])
      });

      await batch.commit();

      // Send notification
      try {
        final currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        final currentUserData = currentUserDoc.data();

        await _notificationService.sendFriendAcceptNotification(
          requesterId: senderId,
          accepterId: currentUser.uid,
          accepterUsername:
              currentUserData?['username'] ?? currentUser.email ?? 'Someone',
          accepterProfilePhoto: currentUserData?['profile_photo'],
          friendRequestId: requestId,
        );
      } catch (e) {
        print('Failed to send friend accept notification: $e');
        // Don't throw - notification failure shouldn't block the accept
      }
    } catch (e) {
      throw Exception('Error occurred while accepting friend request: $e');
    }
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
      });
    } catch (e) {
      throw Exception('Error occurred while rejecting friend request: $e');
    }
  }

  // Get pending friend requests
  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final querySnapshot = await _firestore
          .collection('friend_requests')
          .where('receiver_id', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final senderId = data['sender_id'];

        // Get sender's profile
        final senderDoc =
            await _firestore.collection('users').doc(senderId).get();
        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          requests.add({
            'request_id': doc.id,
            'sender': UserModel.fromJson(senderData),
            'created_at': data['created_at'],
          });
        }
      }

      return requests;
    } catch (e) {
      throw Exception('Error occurred while retrieving friend requests: $e');
    }
  }

  // Remove friend
  Future<void> removeFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User is not logged in');

      final batch = _firestore.batch();

      // Remove from current user's friends list
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([friendId])
      });

      // Remove from friend's friends list
      final friendRef = _firestore.collection('users').doc(friendId);
      batch.update(friendRef, {
        'friends': FieldValue.arrayRemove([currentUser.uid])
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error occurred while removing friend: $e');
    }
  }

  // Update user streak
  Future<void> updateUserStreak(String userId, int streak) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'streak': streak,
      });
    } catch (e) {
      throw Exception('Error occurred while updating user streak: $e');
    }
  }

  // Delete user account
  Future<void> deleteUserAccount(String userId) async {
    try {
      // Delete user document
      await _firestore.collection('users').doc(userId).delete();

      // Delete friend requests
      final sentRequests = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: userId)
          .get();

      final receivedRequests = await _firestore
          .collection('friend_requests')
          .where('receiver_id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (final doc in sentRequests.docs) {
        batch.delete(doc.reference);
      }

      for (final doc in receivedRequests.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error occurred while deleting user account: $e');
    }
  }
}

// Provider
final firebaseUserServiceProvider = Provider<FirebaseUserService>((ref) {
  return FirebaseUserService();
});
