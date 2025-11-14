import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper functions to create initial collections in Firebase Firestore
class FirestoreInitHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create test collections and add initial data
  static Future<void> initializeCollections() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user found for initialization');
        return;
      }

      print('Initializing Firestore collections...');

      // 1. Create Users collection
      await _createUsersCollection(currentUser);

      // 2. Create Posts collection (empty placeholder)
      await _createPostsCollection();

      // 3. Create Friend requests collection
      await _createFriendRequestsCollection();

      print('Firestore collections initialized successfully');
    } catch (e) {
      print('Error initializing Firestore collections: $e');
    }
  }

  static Future<void> _createUsersCollection(User currentUser) async {
    try {
      final userDoc = _firestore.collection('users').doc(currentUser.uid);

      // First check if the document exists
      final existingDoc = await userDoc.get();

      if (!existingDoc.exists) {
        // If user does not exist, create new
        final username = (currentUser.displayName ??
                currentUser.email?.split('@')[0] ??
                'user')
            .toLowerCase();

        await userDoc.set({
          'id': currentUser.uid,
          'email': currentUser.email ?? '',
          'username': username,
          'profile_photo': currentUser.photoURL,
          'bio': '',
          'user_code': null,
          'streak': 0,
          'friends': [],
          'created_at': DateTime.now().toIso8601String(),
        });

        print('New user document created with username: $username');
      } else {
        // If user exists, update only missing fields
        final data = existingDoc.data() as Map<String, dynamic>;
        final updates = <String, dynamic>{};

        if (data['email'] == null) updates['email'] = currentUser.email ?? '';
        if (data['bio'] == null) updates['bio'] = '';
        if (data['streak'] == null) updates['streak'] = 0;
        if (data['friends'] == null) updates['friends'] = [];

        if (updates.isNotEmpty) {
          await userDoc.update(updates);
          print('Updated missing fields for existing user');
        }

        print('User already exists with username: ${data['username']}');
      }
    } catch (e) {
      print('Error creating users collection: $e');
    }
  }

  static Future<void> _createPostsCollection() async {
    try {
      // Create placeholder document for Posts collection
      await _firestore.collection('posts').doc('_placeholder').set({
        'type': 'placeholder',
        'created_at': DateTime.now().toIso8601String(),
        'note': 'This is a placeholder document to create the posts collection',
      });

      print('Posts collection created');
    } catch (e) {
      print('Error creating posts collection: $e');
    }
  }

  static Future<void> _createFriendRequestsCollection() async {
    try {
      // Create placeholder document for Friend requests collection
      await _firestore.collection('friend_requests').doc('_placeholder').set({
        'type': 'placeholder',
        'created_at': DateTime.now().toIso8601String(),
        'note':
            'This is a placeholder document to create the friend_requests collection',
      });

      print('Friend requests collection created');
    } catch (e) {
      print('Error creating friend_requests collection: $e');
    }
  }

  /// Clean up placeholder documents
  static Future<void> cleanupPlaceholders() async {
    try {
      // Delete Posts placeholder
      await _firestore.collection('posts').doc('_placeholder').delete();

      // Delete Friend requests placeholder
      await _firestore
          .collection('friend_requests')
          .doc('_placeholder')
          .delete();

      print('Placeholder documents cleaned up');
    } catch (e) {
      print('Error cleaning up placeholders: $e');
    }
  }
}
