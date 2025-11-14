import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';
import 'firebase_storage_service.dart';
import 'notification_service.dart';

class FirestorePostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final NotificationService _notificationService = NotificationService();

  // Create a new post
  Future<String> createPost(PostModel post) async {
    try {
      final docRef = await _firestore.collection('posts').add(post.toJson());

      // Update the post with the generated ID
      await docRef.update({'id': docRef.id});

      return docRef.id;
    } catch (e) {
      throw Exception('Error occurred while creating post: $e');
    }
  }

  // Get all posts (feed)
  Future<List<PostModel>> getFeedPosts(
      {int limit = 20, DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return PostModel.fromJson(data);
      }).toList();
    } catch (e) {
      print('DEBUG: Index not ready for feed, using fallback: $e');

      // Fallback to manual sorting
      try {
        final querySnapshot = await _firestore.collection('posts').get();

        final posts = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return PostModel.fromJson(data);
        }).toList();

        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts.take(limit).toList();
      } catch (fallbackError) {
        throw Exception(
            'Error occurred while retrieving feed posts: $fallbackError');
      }
    }
  }

  // Get posts by user ID
  Future<List<PostModel>> getUserPosts(String userId, {int limit = 20}) async {
    try {
      print('DEBUG: Getting posts for user: $userId with limit: $limit');

      List<Map<String, dynamic>> postsData = [];

      try {
        final querySnapshot = await _firestore
            .collection('posts')
            .where('user_id', isEqualTo: userId)
            .orderBy('created_at', descending: true)
            .limit(limit)
            .get();

        postsData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Ensure ID is set
          return data;
        }).toList();

        print(
            'DEBUG: Found ${postsData.length} posts for user $userId (with index)');
      } catch (indexError) {
        print(
            'DEBUG: Index not ready for getUserPosts, using fallback: $indexError');

        final querySnapshot = await _firestore
            .collection('posts')
            .where('user_id', isEqualTo: userId)
            .get();

        postsData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // Sort manually by created_at (newest first)
        postsData.sort((a, b) {
          final aTime =
              (a['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime =
              (b['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        postsData = postsData.take(limit).toList();
        print(
            'DEBUG: Found ${postsData.length} posts for user $userId (manual sort)');
      }

      // Convert to PostModel
      final posts = postsData.map((data) => PostModel.fromJson(data)).toList();
      return posts;
    } catch (e) {
      print('DEBUG: Error in getUserPosts: $e');
      throw Exception('Error occurred while retrieving user posts: $e');
    }
  }

  // Get posts from friends
  Future<List<PostModel>> getFriendsPosts(List<String> friendIds,
      {int limit = 20}) async {
    try {
      if (friendIds.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('posts')
          .where('user_id', whereIn: friendIds)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error occurred while retrieving friends posts: $e');
    }
  }

  // Get a specific post
  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error occurred while retrieving post: $e');
    }
  }

  // Alias for getPost - used in notifications
  // Bring user information as well (profile photo, username etc.)
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;

      final postData = doc.data()!;
      final userId = postData['user_id'];

      // Bring user information as well
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          postData['users'] = userDoc.data();
        }
      }

      return PostModel.fromJson(postData);
    } catch (e) {
      throw Exception('Error occurred while retrieving post: $e');
    }
  }

  // Return post data as Map along with user information
  // Used for notification screen
  Future<Map<String, dynamic>?> getPostByIdWithUser(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;

      final postData = doc.data()!;
      final userId = postData['user_id'];

      // Kullanıcı bilgisini de getir
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          postData['users'] = userDoc.data();
        }
      }

      return postData;
    } catch (e) {
      throw Exception('Error occurred while retrieving post: $e');
    }
  }

  // Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('posts').doc(postId).update(updates);
    } catch (e) {
      throw Exception('Error occurred while updating post: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      print('DEBUG: Attempting to delete post $postId');

      // Check if user owns the post
      final post = await getPost(postId);
      if (post == null) throw Exception('Post not found');

      print(
          'DEBUG: Post found, owner: ${post.userId}, current user: ${currentUser.uid}');

      if (post.userId != currentUser.uid) {
        throw Exception('You do not have permission to delete this post');
      }

      // Delete post media from Firebase Storage if exists
      if (post.mediaUrl.isNotEmpty) {
        try {
          print('DEBUG: Deleting media from storage: ${post.mediaUrl}');

          // Try deleting by URL first (more reliable)
          await _storageService.deleteFile(post.mediaUrl);
          print('DEBUG: Successfully deleted media by URL');
        } catch (storageError) {
          print(
              'DEBUG: Failed to delete by URL, trying by postId: $storageError');

          // Fallback: try deleting by post ID
          try {
            await _storageService.deletePostImage(postId);
            print('DEBUG: Successfully deleted media by postId');
          } catch (fallbackError) {
            print(
                'DEBUG: Warning - Could not delete media from storage: $fallbackError');
            // Continue with post deletion even if media deletion fails
          }
        }
      }

      // Delete post and related data using batch
      final batch = _firestore.batch();

      // Delete the post document
      batch.delete(_firestore.collection('posts').doc(postId));

      // Delete likes
      final likesQuery = await _firestore
          .collection('likes')
          .where('post_id', isEqualTo: postId)
          .get();

      print('DEBUG: Found ${likesQuery.docs.length} likes to delete');
      for (final doc in likesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete comments
      final commentsQuery = await _firestore
          .collection('comments')
          .where('post_id', isEqualTo: postId)
          .get();

      print('DEBUG: Found ${commentsQuery.docs.length} comments to delete');
      for (final doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete comment likes for all comments of this post
      // First get all comment IDs for this post
      final postCommentsQuery = await _firestore
          .collection('comments')
          .where('post_id', isEqualTo: postId)
          .get();

      List<String> commentIds =
          postCommentsQuery.docs.map((doc) => doc.id).toList();

      if (commentIds.isNotEmpty) {
        // Delete comment likes for each comment
        for (final commentId in commentIds) {
          final commentLikesQuery = await _firestore
              .collection('comment_likes')
              .where('comment_id', isEqualTo: commentId)
              .get();

          for (final likeDoc in commentLikesQuery.docs) {
            batch.delete(likeDoc.reference);
          }
        }
        print(
            'DEBUG: Found comment likes for ${commentIds.length} comments to delete');
      }

      await batch.commit();
      print('DEBUG: Post $postId deleted successfully');
    } catch (e) {
      print('DEBUG: Error deleting post: $e');
      throw Exception('Error occurred while deleting post: $e');
    }
  }

  // Like a post
  Future<void> likePost(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User is not logged in');

      // Check if already liked
      final existingLike = await _firestore
          .collection('likes')
          .where('post_id', isEqualTo: postId)
          .where('user_id', isEqualTo: currentUser.uid)
          .get();

      if (existingLike.docs.isNotEmpty) {
        throw Exception('Post already liked');
      }

      await _firestore.collection('likes').add({
        'post_id': postId,
        'user_id': currentUser.uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Send notification to post owner
      try {
        final post = await getPost(postId);
        if (post != null && post.userId != currentUser.uid) {
          // Get current user's details
          final currentUserDoc =
              await _firestore.collection('users').doc(currentUser.uid).get();
          final currentUserData = currentUserDoc.data();

          await _notificationService.sendLikeNotification(
            postOwnerId: post.userId,
            senderId: currentUser.uid,
            senderUsername:
                currentUserData?['username'] ?? currentUser.email ?? 'Someone',
            senderProfilePhoto: currentUserData?['profile_photo'],
            postId: postId,
          );
        }
      } catch (e) {
        print('Failed to send like notification: $e');
        // Don't throw - notification failure shouldn't block the like
      }
    } catch (e) {
      throw Exception('Error occurred while liking post: $e');
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User is not logged in');

      final likeQuery = await _firestore
          .collection('likes')
          .where('post_id', isEqualTo: postId)
          .where('user_id', isEqualTo: currentUser.uid)
          .get();

      if (likeQuery.docs.isEmpty) {
        throw Exception('Post not liked');
      }

      await _firestore
          .collection('likes')
          .doc(likeQuery.docs.first.id)
          .delete();
    } catch (e) {
      throw Exception('Error occurred while unliking post: $e');
    }
  }

  // Get post likes count
  Future<int> getPostLikesCount(String postId) async {
    try {
      final likeQuery = await _firestore
          .collection('likes')
          .where('post_id', isEqualTo: postId)
          .get();

      return likeQuery.docs.length;
    } catch (e) {
      throw Exception('Error occurred while retrieving post likes count: $e');
    }
  }

  // Check if current user liked the post
  Future<bool> isPostLikedByCurrentUser(String postId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final likeQuery = await _firestore
          .collection('likes')
          .where('post_id', isEqualTo: postId)
          .where('user_id', isEqualTo: currentUser.uid)
          .get();

      return likeQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get comments for a post with user data
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      print('DEBUG: Getting comments for post: $postId');

      // First try with ordering, fallback to no ordering if index is not ready
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

      try {
        final querySnapshot = await _firestore
            .collection('comments')
            .where('post_id', isEqualTo: postId)
            .orderBy('created_at', descending: false)
            .get();
        docs = querySnapshot.docs;
      } catch (orderError) {
        print('DEBUG: OrderBy failed, trying without ordering: $orderError');
        final querySnapshot = await _firestore
            .collection('comments')
            .where('post_id', isEqualTo: postId)
            .get();
        docs = querySnapshot.docs;

        // Manual sorting by timestamp
        docs.sort((a, b) {
          final aTime = a.data()['created_at'];
          final bTime = b.data()['created_at'];

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          try {
            final aTimestamp = aTime is Timestamp
                ? aTime.toDate()
                : DateTime.parse(aTime.toString());
            final bTimestamp = bTime is Timestamp
                ? bTime.toDate()
                : DateTime.parse(bTime.toString());
            return aTimestamp.compareTo(bTimestamp);
          } catch (e) {
            return 0;
          }
        });
      }

      print('DEBUG: Found ${docs.length} comments');

      final comments = <Map<String, dynamic>>[];

      for (final doc in docs) {
        final commentData = doc.data();
        commentData['id'] = doc.id;

        // Debug comment data
        print(
            'DEBUG: Processing comment: ${commentData['comment']}, created_at: ${commentData['created_at']}, user_id: ${commentData['user_id']}');

        // Convert timestamp for consistent formatting
        if (commentData['created_at'] != null) {
          try {
            if (commentData['created_at'] is Timestamp) {
              final timestamp = commentData['created_at'] as Timestamp;
              commentData['created_at'] = timestamp.toDate().toIso8601String();
            }
          } catch (e) {
            print('DEBUG: Error converting timestamp: $e');
          }
        }

        // Get user data for the comment
        final userId = commentData['user_id'];
        if (userId != null) {
          try {
            final userDoc =
                await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              commentData['users'] = userDoc.data();
              print(
                  'DEBUG: Found user data for comment: ${userDoc.data()?['username']}');
            } else {
              print('DEBUG: User not found: $userId');
              commentData['users'] = {
                'id': userId,
                'username': 'Unknown User',
                'profile_photo': null,
              };
            }
          } catch (e) {
            print('DEBUG: Error getting user data for comment: $e');
            commentData['users'] = {
              'id': userId,
              'username': 'Unknown User',
              'profile_photo': null,
            };
          }
        }

        // Add like count and current user like status
        commentData['likes_count'] =
            await getCommentLikesCount(commentData['id']);

        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          commentData['is_liked_by_current_user'] =
              await isCommentLikedByUser(commentData['id'], currentUser.uid);
        } else {
          commentData['is_liked_by_current_user'] = false;
        }

        comments.add(commentData);
      }

      print('DEBUG: Returning ${comments.length} enriched comments');
      return comments;
    } catch (e) {
      print('DEBUG: Error getting comments: $e');
      throw Exception('Error occurred while retrieving comments: $e');
    }
  }

  // Add comment to post
  Future<void> addComment(String postId, String userId, String comment) async {
    try {
      print('DEBUG: Adding comment to post $postId by user $userId');

      if (comment.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      final commentRef = await _firestore.collection('comments').add({
        'post_id': postId,
        'user_id': userId,
        'comment': comment.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Comment added successfully');

      // Send notification to post owner
      try {
        final post = await getPost(postId);
        if (post != null && post.userId != userId) {
          // Get comment author's details
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();

          await _notificationService.sendCommentNotification(
            postOwnerId: post.userId,
            senderId: userId,
            senderUsername: userData?['username'] ?? 'Someone',
            senderProfilePhoto: userData?['profile_photo'],
            postId: postId,
            commentId: commentRef.id,
            commentText: comment.trim(),
          );
        }
      } catch (e) {
        print('Failed to send comment notification: $e');
        // Don't throw - notification failure shouldn't block the comment
      }
    } catch (e) {
      print('DEBUG: Error adding comment: $e');
      throw Exception('Error occurred while adding comment: $e');
    }
  }

  // Delete comment
  Future<void> deleteComment(String commentId, String userId) async {
    try {
      print('DEBUG: Deleting comment $commentId by user $userId');

      final commentDoc =
          await _firestore.collection('comments').doc(commentId).get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      if (commentData['user_id'] != userId) {
        throw Exception('You do not have permission to delete this comment');
      }

      // Use batch to delete comment and its likes atomically
      final batch = _firestore.batch();

      // Delete the comment
      batch.delete(_firestore.collection('comments').doc(commentId));

      // Delete all likes for this comment
      final commentLikesQuery = await _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .get();

      print(
          'DEBUG: Found ${commentLikesQuery.docs.length} comment likes to delete');
      for (final likeDoc in commentLikesQuery.docs) {
        batch.delete(likeDoc.reference);
      }

      await batch.commit();
      print('DEBUG: Comment and its likes deleted successfully');
    } catch (e) {
      print('DEBUG: Error deleting comment: $e');
      throw Exception('Error occurred while deleting comment: $e');
    }
  }

  // Delete comment by post owner
  Future<void> deleteCommentByPostOwner(
      String commentId, String postOwnerId) async {
    try {
      print('DEBUG: Post owner $postOwnerId deleting comment $commentId');

      final commentDoc =
          await _firestore.collection('comments').doc(commentId).get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data()!;
      final postId = commentData['post_id'];

      // Check if user owns the post
      final post = await getPost(postId);
      if (post == null || post.userId != postOwnerId) {
        throw Exception('You do not have permission to delete this comment');
      }

      // Use batch to delete comment and its likes atomically
      final batch = _firestore.batch();

      // Delete the comment
      batch.delete(_firestore.collection('comments').doc(commentId));

      // Delete all likes for this comment
      final commentLikesQuery = await _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .get();

      print(
          'DEBUG: Found ${commentLikesQuery.docs.length} comment likes to delete by post owner');
      for (final likeDoc in commentLikesQuery.docs) {
        batch.delete(likeDoc.reference);
      }

      await batch.commit();
      print('DEBUG: Comment and its likes deleted successfully by post owner');
    } catch (e) {
      print('DEBUG: Error deleting comment by post owner: $e');
      throw Exception(
          'Error occurred while deleting comment by post owner: $e');
    }
  }

  // Toggle comment like
  Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      print(
          'DEBUG: Toggling comment like for comment $commentId by user $userId');

      final existingLike = await _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .where('user_id', isEqualTo: userId)
          .get();

      if (existingLike.docs.isNotEmpty) {
        // Unlike
        print('DEBUG: Unliking comment');
        await _firestore
            .collection('comment_likes')
            .doc(existingLike.docs.first.id)
            .delete();
      } else {
        // Like
        print('DEBUG: Liking comment');
        await _firestore.collection('comment_likes').add({
          'comment_id': commentId,
          'user_id': userId,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Send notification to comment owner
        try {
          final commentDoc =
              await _firestore.collection('comments').doc(commentId).get();
          if (commentDoc.exists) {
            final commentData = commentDoc.data()!;
            final commentOwnerId = commentData['user_id'];
            final postId = commentData['post_id'];

            if (commentOwnerId != userId) {
              // Get liker's details
              final userDoc =
                  await _firestore.collection('users').doc(userId).get();
              final userData = userDoc.data();

              await _notificationService.sendCommentLikeNotification(
                commentOwnerId: commentOwnerId,
                senderId: userId,
                senderUsername: userData?['username'] ?? 'Someone',
                senderProfilePhoto: userData?['profile_photo'],
                postId: postId,
                commentId: commentId,
              );
            }
          }
        } catch (e) {
          print('Failed to send comment like notification: $e');
          // Don't throw - notification failure shouldn't block the like
        }
      }

      print('DEBUG: Comment like toggled successfully');
    } catch (e) {
      print('DEBUG: Error toggling comment like: $e');
      throw Exception('Error occurred while toggling comment like: $e');
    }
  }

  // Check if user liked comment
  Future<bool> isCommentLikedByUser(String commentId, String userId) async {
    try {
      final likeQuery = await _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .where('user_id', isEqualTo: userId)
          .get();

      return likeQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get comment likes count
  Future<int> getCommentLikesCount(String commentId) async {
    try {
      final likesQuery = await _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .get();

      return likesQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Legacy methods for compatibility
  Future<bool> isLikedByUser(String postId, String userId) async {
    return await isPostLikedByCurrentUser(postId);
  }

  Future<void> toggleLike(String postId, String userId) async {
    final isLiked = await isPostLikedByCurrentUser(postId);

    if (isLiked) {
      await unlikePost(postId);
    } else {
      await likePost(postId);
    }
  }

  Future<int> getLikesCount(String postId) async {
    return await getPostLikesCount(postId);
  }

  Future<int> getUserPostsCount(String userId) async {
    try {
      // Simple count without ordering
      final querySnapshot = await _firestore
          .collection('posts')
          .where('user_id', isEqualTo: userId)
          .get();

      print('DEBUG: Found ${querySnapshot.docs.length} posts for user $userId');
      return querySnapshot.docs.length;
    } catch (e) {
      print('DEBUG: Error counting user posts: $e');
      return 0;
    }
  }

  Future<bool> testDatabaseConnection() async {
    try {
      await _firestore.collection('posts').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Real-time stream methods for reactive UI

  // Stream post likes count
  Stream<int> getPostLikesCountStream(String postId) {
    return _firestore
        .collection('likes')
        .where('post_id', isEqualTo: postId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream post likes with user details
  Stream<List<Map<String, dynamic>>> getPostLikesStream(String postId) {
    return _firestore
        .collection('likes')
        .where('post_id', isEqualTo: postId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> likes = [];

      for (var doc in snapshot.docs) {
        final likeData = doc.data();
        final userId = likeData['user_id'];

        // Fetch user details
        try {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            likes.add({
              ...likeData,
              'id': doc.id,
              'users': userDoc.data(),
            });
          }
        } catch (e) {
          print('Error fetching user for like: $e');
        }
      }

      return likes;
    });
  }

  // Stream current user's like status for a post
  Stream<bool> isPostLikedByCurrentUserStream(String postId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(false);

    return _firestore
        .collection('likes')
        .where('post_id', isEqualTo: postId)
        .where('user_id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Stream comments count for a post
  Stream<int> getPostCommentsCountStream(String postId) {
    try {
      print('DEBUG: Setting up comments count stream for post: $postId');
      return _firestore
          .collection('comments')
          .where('post_id', isEqualTo: postId)
          .snapshots()
          .map((snapshot) {
        print('DEBUG: Comments count stream: ${snapshot.docs.length} comments');
        return snapshot.docs.length;
      }).handleError((error) {
        print('DEBUG: Comments count stream error: $error');
        return 0;
      });
    } catch (e) {
      print('DEBUG: Error setting up comments count stream: $e');
      return Stream.value(0);
    }
  }

  // Stream comment likes count for a specific comment
  Stream<int> getCommentLikesCountStream(String commentId) {
    try {
      return _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error) {
        print('DEBUG: Comment likes count stream error: $error');
        return 0;
      });
    } catch (e) {
      return Stream.value(0);
    }
  }

  // Stream current user's like status for a comment
  Stream<bool> isCommentLikedByCurrentUserStream(String commentId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(false);

    return _firestore
        .collection('comment_likes')
        .where('comment_id', isEqualTo: commentId)
        .where('user_id', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // Stream comment likes with user details
  Stream<List<Map<String, dynamic>>> getCommentLikesStream(String commentId) {
    return _firestore
        .collection('comment_likes')
        .where('comment_id', isEqualTo: commentId)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> likes = [];

      for (var doc in snapshot.docs) {
        final likeData = doc.data();
        final userId = likeData['user_id'];

        // Fetch user details
        try {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            likes.add({
              ...likeData,
              'id': doc.id,
              'users': userDoc.data(),
            });
          }
        } catch (e) {
          print('Error fetching user for comment like: $e');
        }
      }

      return likes;
    });
  }

  Stream<bool> isCommentLikedByUserStream(String commentId, String userId) {
    try {
      print(
          'DEBUG: Setting up comment like stream for comment: $commentId, user: $userId');
      return _firestore
          .collection('comment_likes')
          .where('comment_id', isEqualTo: commentId)
          .where('user_id', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final isLiked = snapshot.docs.isNotEmpty;
        print(
            'DEBUG: Comment like stream update - commentId: $commentId, isLiked: $isLiked, docsCount: ${snapshot.docs.length}');
        return isLiked;
      }).handleError((error) {
        print('DEBUG: Comment like status stream error: $error');
        return false;
      });
    } catch (e) {
      print('DEBUG: Error setting up comment like stream: $e');
      return Stream.value(false);
    }
  }

  // Stream comments for a post with user data
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('post_id', isEqualTo: postId)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        print('DEBUG: Stream received ${snapshot.docs.length} comments');
        final comments = <Map<String, dynamic>>[];

        // Sort documents manually by created_at
        final sortedDocs = snapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['created_at'];
          final bTime = b.data()['created_at'];

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          try {
            final aDateTime = aTime is Timestamp
                ? aTime.toDate()
                : DateTime.parse(aTime.toString());
            final bDateTime = bTime is Timestamp
                ? bTime.toDate()
                : DateTime.parse(bTime.toString());
            return aDateTime
                .compareTo(bDateTime); // Ascending order (oldest first)
          } catch (e) {
            return 0;
          }
        });

        for (final doc in sortedDocs) {
          final commentData = doc.data();
          commentData['id'] = doc.id;

          // Convert timestamp for consistent formatting
          if (commentData['created_at'] != null) {
            try {
              if (commentData['created_at'] is Timestamp) {
                final timestamp = commentData['created_at'] as Timestamp;
                commentData['created_at'] =
                    timestamp.toDate().toIso8601String();
              }
            } catch (e) {
              print('DEBUG: Error converting timestamp: $e');
            }
          }

          // Get user data for the comment
          final userId = commentData['user_id'];
          if (userId != null) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(userId).get();
              if (userDoc.exists) {
                commentData['users'] = userDoc.data();
              } else {
                commentData['users'] = {
                  'id': userId,
                  'username': 'Unknown User',
                  'profile_photo': null,
                };
              }
            } catch (e) {
              commentData['users'] = {
                'id': userId,
                'username': 'Unknown User',
                'profile_photo': null,
              };
            }
          }

          // Add like count and current user like status
          try {
            commentData['likes_count'] =
                await getCommentLikesCount(commentData['id']);

            final currentUser = _auth.currentUser;
            if (currentUser != null) {
              commentData['is_liked_by_current_user'] =
                  await isCommentLikedByUser(
                      commentData['id'], currentUser.uid);
            } else {
              commentData['is_liked_by_current_user'] = false;
            }
          } catch (e) {
            print('DEBUG: Error getting comment like data: $e');
            commentData['likes_count'] = 0;
            commentData['is_liked_by_current_user'] = false;
          }

          comments.add(commentData);
        }

        print(
            'DEBUG: Returning ${comments.length} enriched comments from stream');
        return comments;
      } catch (e) {
        print('DEBUG: Error in getCommentsStream: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  // Stream friends posts with real-time updates
  Stream<List<Map<String, dynamic>>> getFriendsPostsStream(String userId,
      {int limit = 20}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      List<String> friendIds = [];

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        friendIds = List<String>.from(userData['friends'] ?? []);
      }

      // Always include user's own posts
      friendIds.add(userId);

      try {
        final querySnapshot = await _firestore
            .collection('posts')
            .where('user_id', whereIn: friendIds)
            .orderBy('created_at', descending: true)
            .limit(limit)
            .get();

        final posts = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // Enrich posts with user data
        for (var post in posts) {
          final postUserId = post['user_id'];
          if (postUserId != null) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(postUserId).get();
              if (userDoc.exists) {
                post['users'] = userDoc.data();
              } else {
                post['users'] = {
                  'id': postUserId,
                  'username': 'Unknown User',
                  'profile_photo': null,
                };
              }
            } catch (e) {
              post['users'] = {
                'id': postUserId,
                'username': 'Unknown User',
                'profile_photo': null,
              };
            }
          }
        }

        return posts;
      } catch (e) {
        print('DEBUG: Error in getFriendsPostsStream: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  // Get friends posts (Map format for legacy compatibility)
  Future<List<Map<String, dynamic>>> getFriendsPostsMap(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      List<String> friendIds = [];

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        friendIds = List<String>.from(userData['friends'] ?? []);
      }

      // Always include user's own posts
      friendIds.add(userId);

      print('DEBUG: Getting posts for user IDs: $friendIds');

      List<Map<String, dynamic>> posts = [];

      try {
        // Try with index-optimized query first
        final querySnapshot = await _firestore
            .collection('posts')
            .where('user_id', whereIn: friendIds)
            .orderBy('created_at', descending: true)
            .limit(limit)
            .get();

        posts = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        print('DEBUG: Found ${posts.length} posts in feed (with index)');
      } catch (indexError) {
        print(
            'DEBUG: Index not ready, falling back to manual sort: $indexError');

        // Fallback to manual sorting
        final querySnapshot = await _firestore
            .collection('posts')
            .where('user_id', whereIn: friendIds)
            .get();

        posts = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // Sort manually by created_at (newest first)
        posts.sort((a, b) {
          final aTime =
              (a['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime =
              (b['created_at'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        posts = posts.take(limit).toList();
        print('DEBUG: Found ${posts.length} posts in feed (manual sort)');
      }

      // Enrich posts with user data
      for (var post in posts) {
        final postUserId = post['user_id'];
        if (postUserId != null) {
          try {
            final userDoc =
                await _firestore.collection('users').doc(postUserId).get();
            if (userDoc.exists) {
              post['users'] = userDoc.data();
            } else {
              post['users'] = {
                'id': postUserId,
                'username': 'Unknown User',
                'profile_photo': null,
              };
            }
          } catch (e) {
            print('DEBUG: Error getting user data for $postUserId: $e');
            post['users'] = {
              'id': postUserId,
              'username': 'Unknown User',
              'profile_photo': null,
            };
          }
        }
      }

      return posts;
    } catch (e) {
      print('DEBUG: Error in getFriendsPostsMap: $e');
      throw Exception('Arkadaş postları alınırken hata oluştu: $e');
    }
  }

  // Search posts by caption
  Future<List<PostModel>> searchPosts(String query, {int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .where((post) =>
              post.caption != null &&
              post.caption!.toLowerCase().contains(query.toLowerCase()))
          .take(limit)
          .toList();

      return posts;
    } catch (e) {
      throw Exception('Post search error: $e');
    }
  }
}
