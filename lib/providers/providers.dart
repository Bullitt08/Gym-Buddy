import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firestore_post_service.dart';
import '../services/firebase_chat_service.dart';
import '../services/google_places_service.dart';
import '../services/gym_service.dart';
import '../services/deezer_service.dart';
import '../services/notification_service.dart';
import '../models/gym_model.dart';

// Location provider export
export 'location_provider.dart';

// Firebase Storage Service provider export
export '../services/firebase_storage_service.dart';

// Firebase Service Providers
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final firebaseUserServiceProvider = Provider<FirebaseUserService>((ref) {
  return FirebaseUserService();
});

final firestorePostServiceProvider = Provider<FirestorePostService>((ref) {
  return FirestorePostService();
});

final googlePlacesServiceProvider = Provider<GooglePlacesService>((ref) {
  return GooglePlacesService();
});

final gymServiceProvider = Provider<GymService>((ref) {
  return GymService();
});

final deezerServiceProvider = Provider<DeezerService>((ref) {
  return DeezerService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Gym-related providers
final gymDetailsProvider =
    FutureProvider.family<Gym?, String>((ref, placeId) async {
  final gymService = ref.read(gymServiceProvider);
  return await gymService.getGymDetails(placeId);
});

// Stable key class for gym search
class GymSearchParams {
  final String name;
  final double? lat;
  final double? lng;

  const GymSearchParams({
    required this.name,
    this.lat,
    this.lng,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymSearchParams &&
          other.name == name &&
          other.lat == lat &&
          other.lng == lng);

  @override
  int get hashCode => Object.hash(name, lat, lng);

  @override
  String toString() => 'GymSearchParams(name: $name, lat: $lat, lng: $lng)';
}

final gymByNameProvider =
    FutureProvider.family<Gym?, GymSearchParams>((ref, params) async {
  final gymService = ref.read(gymServiceProvider);
  return await gymService.getGymByName(
    params.name,
    lat: params.lat,
    lng: params.lng,
  );
});

final gymPostsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, gymId) async {
    // Watch the refresh provider to trigger updates
    ref.watch(gymDataRefreshProvider);
    final gymService = ref.read(gymServiceProvider);
    return await gymService.getGymPosts(gymId);
  },
);

// Provider to refresh gym data when posts change
final gymDataRefreshProvider = StateProvider<int>((ref) => 0);

final gymMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, gymId) async {
  final gymService = ref.read(gymServiceProvider);
  return await gymService.getGymMembers(gymId);
});

final gymStatsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
  (ref, gymId) async {
    try {
      // Watch the refresh provider to trigger updates
      ref.watch(gymDataRefreshProvider);
      final gymService = ref.read(gymServiceProvider);
      final result = await gymService.getGymStats(gymId);
      return result;
    } catch (e) {
      return {
        'posts_count': 0,
        'members_count': 0,
        'this_week_posts': 0,
      };
    }
  },
);

// Auth State Providers
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user == null) {
        print('DEBUG: No authenticated user found');
        return null;
      }

      print(
          'DEBUG: Authenticated user found - UID: ${user.uid}, Email: ${user.email}');

      final userService = ref.watch(firebaseUserServiceProvider);
      try {
        // Wait a bit for Firestore initialization to complete
        await Future.delayed(const Duration(milliseconds: 1500));

        // First attempt to get user profile
        var userProfile = await userService.getUserProfile(user.uid);

        if (userProfile == null) {
          print('DEBUG: No user profile found in Firestore, creating one...');
          // Create a basic profile if it doesn't exist
          // Don't override username here - it should be set during registration
          final newUserModel = UserModel(
            id: user.uid,
            email: user.email ?? '',
            username: user.displayName ?? user.email?.split('@')[0] ?? 'user',
            streak: 0,
            friends: [],
            createdAt: DateTime.now(),
          );

          // Try creating profile, if it fails due to permissions, wait and retry
          try {
            await userService.createUserProfile(newUserModel);
            userProfile = newUserModel;
          } catch (createError) {
            print(
                'DEBUG: Failed to create profile initially, retrying in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
            await userService.createUserProfile(newUserModel);
            userProfile = newUserModel;
          }
        } else if (userProfile.username.isEmpty) {
          print('DEBUG: Username is empty, fixing...');
          await userService.fixMissingUsername(user.uid, user.email ?? '');
          // Try to get profile again after fix
          userProfile = await userService.getUserProfile(user.uid);
        }

        print('DEBUG: Final user profile: ${userProfile?.toJson()}');
        return userProfile;
      } catch (e) {
        print('Error loading user profile: $e');

        // Fallback: Return basic user info from Firebase Auth
        return UserModel(
          id: user.uid,
          email: user.email ?? '',
          username: user.email?.split('@')[0] ?? 'user',
          streak: 0,
          friends: [],
          createdAt: DateTime.now(),
        );
      }
    },
    loading: () => null,
    error: (error, stack) => null,
  );
});

// Navigation State
enum NavigationState { home, map, createPost, friends, profile }

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(NavigationState.home);

  void setIndex(int index) {
    switch (index) {
      case 0:
        state = NavigationState.home;
        break;
      case 1:
        state = NavigationState.map;
        break;
      case 2:
        state = NavigationState.createPost;
        break;
      case 3:
        state = NavigationState.friends;
        break;
      case 4:
        state = NavigationState.profile;
        break;
    }
  }

  void resetToHome() {
    state = NavigationState.home;
  }

  void goToHome() {
    state = NavigationState.home;
  }

  void goToProfile() {
    state = NavigationState.profile;
  }

  void goToUserProfile(String userId) {
    // This method is kept for compatibility but direct Navigator.push
    // is preferred for profile navigation to avoid state management complexity
  }

  void goBack() {
    // Go back logic
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

// Posts Providers
final postsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final postService = ref.watch(firestorePostServiceProvider);
  final currentUser = await ref.watch(authStateProvider.future);

  if (currentUser == null) return [];

  try {
    return await postService.getFriendsPostsMap(currentUser.uid, limit: 50);
  } catch (e) {
    return [];
  }
});

final friendsPostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final postService = ref.watch(firestorePostServiceProvider);
  final authStateAsync = ref.watch(authStateProvider);

  return authStateAsync.when(
    data: (currentUser) {
      if (currentUser == null) return Stream.value([]);

      try {
        return postService.getFriendsPostsStream(currentUser.uid, limit: 30);
      } catch (e) {
        print('Error in friendsPostsProvider: $e');
        return Stream.value([]);
      }
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final userPostsProvider =
    FutureProviderFamily<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    final posts = await postService.getUserPosts(userId, limit: 30);
    final postsWithUserData = <Map<String, dynamic>>[];

    for (final post in posts) {
      final postData = post.toJson();

      // Add user data for the post
      try {
        final userService = ref.watch(firebaseUserServiceProvider);
        final userModel = await userService.getUserProfile(userId);

        if (userModel != null) {
          postData['users'] = userModel.toJson();
        } else {
          postData['users'] = {
            'id': userId,
            'username': 'Unknown User',
            'profile_photo': null,
          };
        }
      } catch (e) {
        print('DEBUG: Error getting user data for post: $e');
        postData['users'] = {
          'id': userId,
          'username': 'Unknown User',
          'profile_photo': null,
        };
      }

      postsWithUserData.add(postData);
    }

    return postsWithUserData;
  } catch (e) {
    print('DEBUG: Error in userPostsProvider: $e');
    return [];
  }
});

final userPostsCountProvider =
    FutureProviderFamily<int, String>((ref, userId) async {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return await postService.getUserPostsCount(userId);
  } catch (e) {
    return 0;
  }
});

final currentUserPostsCountProvider = FutureProvider<int>((ref) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return 0;

  final postService = ref.watch(firestorePostServiceProvider);

  try {
    // Get user posts and count them for accuracy
    final userPosts =
        await postService.getUserPosts(currentUser.uid, limit: 100);
    return userPosts.length;
  } catch (e) {
    print('Error counting user posts: $e');
    return 0;
  }
});

final postLikesCountProvider = StreamProviderFamily<int, String>((ref, postId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.getPostLikesCountStream(postId);
  } catch (e) {
    return Stream.value(0);
  }
});

final postLikeProvider = StreamProviderFamily<bool, String>((ref, postId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.isPostLikedByCurrentUserStream(postId);
  } catch (e) {
    return Stream.value(false);
  }
});

final postLikesProvider =
    StreamProviderFamily<List<Map<String, dynamic>>, String>((ref, postId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.getPostLikesStream(postId);
  } catch (e) {
    return Stream.value([]);
  }
});

final postCommentsCountProvider =
    StreamProviderFamily<int, String>((ref, postId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService
        .getPostCommentsCountStream(postId)
        .handleError((error, stackTrace) {
      print('DEBUG: Comments count stream error: $error');
      return 0;
    });
  } catch (e) {
    print('DEBUG: Comments count provider error: $e');
    return Stream.value(0);
  }
});

final postCommentsProvider =
    StreamProviderFamily<List<Map<String, dynamic>>, String>((ref, postId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    print('DEBUG: Setting up comments stream for post: $postId');
    return postService
        .getCommentsStream(postId)
        .handleError((error, stackTrace) {
      print('DEBUG: Comments stream error: $error');
      return <Map<String, dynamic>>[];
    });
  } catch (e) {
    print('DEBUG: Comments provider error: $e');
    return Stream.value([]);
  }
});

// Create Post Provider
final createPostProvider = StateProvider<bool>((ref) => false);

// Friends and User Providers
final friendsProvider = FutureProvider<List<UserModel>>((ref) async {
  final userService = ref.watch(firebaseUserServiceProvider);
  final currentUser = await ref.watch(authStateProvider.future);

  if (currentUser == null) return [];

  try {
    final friends = await userService.getUserFriends(currentUser.uid);
    return friends;
  } catch (e) {
    return [];
  }
});

final userFriendsListProvider =
    FutureProviderFamily<List<UserModel>, String>((ref, userId) async {
  // Normal provider - cache korunur, loading döngüsü önlenir
  final userService = ref.watch(firebaseUserServiceProvider);

  print('DEBUG: userFriendsListProvider called for userId: $userId');

  try {
    final friends = await userService.getUserFriends(userId);
    print('DEBUG: Found ${friends.length} friends for user $userId');
    return friends;
  } catch (e) {
    print('DEBUG: Error getting friends: $e');
    return [];
  }
});

// Specific user profile provider
final userProfileProvider =
    FutureProviderFamily<UserModel?, String>((ref, userId) async {
  final userService = ref.watch(firebaseUserServiceProvider);

  try {
    return await userService.getUserProfile(userId);
  } catch (e) {
    print('Error loading user profile for $userId: $e');
    return null;
  }
});

// Check if current user is friends with specific user
final isFriendProvider =
    FutureProviderFamily<bool, String>((ref, userId) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return false;

  final userService = ref.watch(firebaseUserServiceProvider);

  try {
    final currentUserProfile =
        await userService.getUserProfile(currentUser.uid);
    if (currentUserProfile?.friends == null) return false;

    return currentUserProfile!.friends.contains(userId);
  } catch (e) {
    print('Error checking friend status for $userId: $e');
    return false;
  }
});

// Current user's friends count provider
final currentUserFriendsCountProvider = FutureProvider<int>((ref) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return 0;

  final userService = ref.watch(firebaseUserServiceProvider);

  try {
    final friends = await userService.getUserFriends(currentUser.uid);
    return friends.length;
  } catch (e) {
    print('Error counting user friends: $e');
    return 0;
  }
});

// Specific user's friends count provider
final userFriendsCountProvider =
    FutureProviderFamily<int, String>((ref, userId) async {
  final userService = ref.watch(firebaseUserServiceProvider);

  try {
    final friends = await userService.getUserFriends(userId);
    return friends.length;
  } catch (e) {
    print('Error counting friends for user $userId: $e');
    return 0;
  }
});

// Pending Friend Requests Provider
final pendingFriendRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userService = ref.watch(firebaseUserServiceProvider);
  final currentUser = await ref.watch(authStateProvider.future);

  if (currentUser == null) return [];

  try {
    return await userService.getPendingFriendRequests();
  } catch (e) {
    print('Error loading pending friend requests: $e');
    return [];
  }
});

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return {};

  final userService = ref.watch(firebaseUserServiceProvider);

  try {
    final userModel = await userService.getUserProfile(currentUser.uid);
    return userModel?.toJson() ?? {};
  } catch (e) {
    return {};
  }
});

// Chat Service Provider
final chatServiceProvider = Provider<FirebaseChatService>((ref) {
  return FirebaseChatService();
});

// Chat Providers
final userChatsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return [];

  final chatService = ref.watch(chatServiceProvider);
  try {
    final chats = await chatService.getUserChats(currentUser.uid);

    // Her chat için other user bilgilerini getir
    final List<Map<String, dynamic>> enrichedChats = [];

    for (final chat in chats) {
      final participants = List<String>.from(chat['participants'] ?? []);
      final otherUserId = participants.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty) {
        try {
          final userService = ref.watch(firebaseUserServiceProvider);
          final otherUser = await userService.getUserProfile(otherUserId);

          final enrichedChat = Map<String, dynamic>.from(chat);
          enrichedChat['otherUserName'] = otherUser?.username ?? 'Unknown User';
          enrichedChat['otherUserPhoto'] = otherUser?.profilePhoto;
          enrichedChat['otherUserId'] = otherUserId;

          // Unread count hesapla
          final unreadCount =
              await chatService.getUnreadMessageCount(currentUser.uid);
          enrichedChat['unreadCount'] = unreadCount;

          enrichedChats.add(enrichedChat);
        } catch (e) {
          // Hata durumunda basic chat ekle
          final basicChat = Map<String, dynamic>.from(chat);
          basicChat['otherUserName'] = 'Unknown User';
          basicChat['otherUserId'] = otherUserId;
          basicChat['unreadCount'] = 0;
          enrichedChats.add(basicChat);
        }
      }
    }

    return enrichedChats;
  } catch (e) {
    throw Exception('Chat system not available: $e');
  }
});

// User Search Provider
final searchUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Bu provider search query'ye göre güncellenecek
  return [];
});

// Search Query State Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Simple Search Provider - StateNotifier yerine basit FutureProvider kullanalım
final simpleSearchUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  print('DEBUG: Simple search provider called with query: "$query"');

  if (query.isEmpty || query.length < 2) {
    print('DEBUG: Query too short, returning empty list');
    return [];
  }

  final currentUser = await ref.read(authStateProvider.future);
  if (currentUser == null) {
    print('DEBUG: No current user, returning empty list');
    return [];
  }

  try {
    print('DEBUG: Starting search for: "$query"');

    final userService = ref.read(firebaseUserServiceProvider);
    final users = await userService.searchUsers(query);

    final filteredUsers = users
        .where((user) => user.id != currentUser.uid)
        .map((user) => {
              'id': user.id,
              'username': user.username,
              'profile_photo': user.profilePhoto,
              'bio': user.bio,
            })
        .toList();

    print(
        'DEBUG: Simple search found ${filteredUsers.length} users for query "$query"');
    return filteredUsers;
  } catch (e) {
    print('DEBUG: Simple search error: $e');
    throw e;
  }
});

// Search Users with Query Provider (Family kullanarak cache sorununu çöz)
final searchUsersWithQueryProvider =
    FutureProviderFamily<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  print('DEBUG: Search provider called with query: "$query"');

  if (query.isEmpty || query.length < 2) {
    print('DEBUG: Query too short or empty, returning empty list');
    return [];
  }

  final currentUser = await ref.read(authStateProvider.future);
  if (currentUser == null) {
    print('DEBUG: No current user, returning empty list');
    return [];
  }

  print('DEBUG: Current user: ${currentUser.uid}');

  try {
    print('DEBUG: Starting search for: "$query"');

    // Firebase User Service kullanarak gerçek search yapalım
    final userService = ref.read(firebaseUserServiceProvider);
    final users = await userService.searchUsers(query);

    // Current user'ı filtreleyelim ve Map formatına çevirelim
    final filteredUsers = users
        .where((user) => user.id != currentUser.uid)
        .map((user) => {
              'id': user.id,
              'username': user.username,
              'profile_photo': user.profilePhoto,
              'bio': user.bio,
            })
        .toList();

    print('DEBUG: Found ${filteredUsers.length} users for query "$query"');
    return filteredUsers;
  } catch (e) {
    print('Search error: $e');
    return [];
  }
});

// Reactive Search Provider - searchQueryProvider'ı dinler ve otomatik güncellenir
final reactiveSearchUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  print('DEBUG: Reactive provider triggered with query: "$query"');

  if (query.isEmpty || query.length < 2) {
    print('DEBUG: Query too short, returning empty list');
    return [];
  }

  // Family provider'ı çağır
  final result = await ref.watch(searchUsersWithQueryProvider(query).future);
  print('DEBUG: Reactive provider returning ${result.length} results');
  return result;
});

// Alternative Chat Search Provider (Firebase Chat Service kullanır)
final chatSearchUsersProvider =
    FutureProviderFamily<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty || query.length < 2) {
    return [];
  }

  final currentUser = await ref.read(authStateProvider.future);
  if (currentUser == null) return [];

  final chatService = ref.read(chatServiceProvider);
  try {
    return await chatService.searchUsersForChat(query, currentUser.uid);
  } catch (e) {
    print('Chat search error: $e');
    return [];
  }
});

// Create or Get Chat Provider
final createOrGetChatProvider =
    FutureProviderFamily<String, String>((ref, otherUserId) async {
  final chatService = ref.watch(chatServiceProvider);
  try {
    final chatId = await chatService.createOrGetChat(otherUserId);
    return chatId ?? '';
  } catch (e) {
    throw Exception('Could not create chat: $e');
  }
});

// Chat Messages Provider
final chatMessagesProvider =
    StreamProviderFamily<List<Map<String, dynamic>>, String>((ref, chatId) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessages(chatId);
});

// Recent Chats Provider
final recentChatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final chatService = ref.watch(chatServiceProvider);

  try {
    return chatService.getRecentChatsStream(currentUser.uid);
  } catch (e) {
    print('Error in recentChatsProvider: $e');
    return Stream.value([]);
  }
});

// Chat Participants Provider
final chatParticipantsProvider =
    FutureProviderFamily<List<Map<String, dynamic>>, String>(
        (ref, chatId) async {
  final chatService = ref.watch(chatServiceProvider);
  try {
    return await chatService.getChatParticipants(chatId);
  } catch (e) {
    print('Error getting chat participants: $e');
    return [];
  }
});

// Get Other User in Chat Provider
final chatOtherUserProvider =
    FutureProviderFamily<Map<String, dynamic>?, String>((ref, chatId) async {
  final currentUser = await ref.watch(authStateProvider.future);
  if (currentUser == null) return null;

  final participants = await ref.watch(chatParticipantsProvider(chatId).future);

  // Find the other user (not current user)
  for (final participant in participants) {
    if (participant['id'] != currentUser.uid) {
      return participant;
    }
  }

  return null;
});

// Unread Messages Count Provider (Stream-based for real-time updates)
final unreadMessagesCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) {
    return Stream.value(0);
  }

  final chatService = ref.watch(chatServiceProvider);
  return chatService.getUnreadMessageCountStream(currentUser.uid);
});

// Chat-specific unread count provider
final chatUnreadCountProvider =
    StreamProviderFamily<int, String>((ref, chatId) {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) {
    return Stream.value(0);
  }

  final chatService = ref.watch(chatServiceProvider);
  return chatService.getChatUnreadCountStream(chatId, currentUser.uid);
});
final commentProvider = StateProvider<String>((ref) => "");

// Comment like providers with real-time updates
final commentLikesCountProvider =
    StreamProviderFamily<int, String>((ref, commentId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.getCommentLikesCountStream(commentId);
  } catch (e) {
    return Stream.value(0);
  }
});

final commentLikeProvider =
    StreamProviderFamily<bool, String>((ref, commentId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.isCommentLikedByCurrentUserStream(commentId);
  } catch (e) {
    return Stream.value(false);
  }
});

final commentLikesProvider =
    StreamProviderFamily<List<Map<String, dynamic>>, String>((ref, commentId) {
  final postService = ref.watch(firestorePostServiceProvider);

  try {
    return postService.getCommentLikesStream(commentId);
  } catch (e) {
    return Stream.value([]);
  }
});

// Notification Providers
final userNotificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService
      .getUserNotifications(currentUser.uid)
      .map((notifications) {
    // Filter out chat (message) notifications - remove them only from in-app
    return notifications
        .where((notification) => notification['type'] != 'message')
        .toList();
  });
});

final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) {
    return Stream.value(0);
  }

  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getUnreadNotificationsCount(currentUser.uid);
});
