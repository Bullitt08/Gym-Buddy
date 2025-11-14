import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../widgets/post_card.dart';
import '../../widgets/friends_list_modal.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../chat/chat_detail_screen.dart';
import 'post_detail_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? username; // Optional, for display while loading
  final String? heroTag; // Optional, for Hero animation

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.heroTag,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    // Handle null or empty userId
    if (widget.userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Invalid User ID',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Cannot load profile for invalid user.',
                style: TextStyle(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final targetUser = ref.watch(userProfileProvider(widget.userId));
    final userPosts = ref.watch(userPostsProvider(widget.userId));
    final userPostsCount = ref.watch(userPostsCountProvider(widget.userId));
    final userFriendsCount = ref.watch(userFriendsCountProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isFriend = ref.watch(isFriendProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username ?? 'Profile'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all user-related data
          ref.invalidate(userProfileProvider(widget.userId));
          ref.invalidate(userPostsCountProvider(widget.userId));
          ref.invalidate(userPostsProvider(widget.userId));
          ref.invalidate(userFriendsCountProvider(widget.userId));
          ref.invalidate(isFriendProvider(widget.userId));

          // Wait a bit for providers to refresh
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: targetUser.when(
                  data: (user) => user != null
                      ? _buildProfileHeader(
                          user, userPostsCount, userFriendsCount)
                      : _buildUserNotFound(),
                  loading: () => _buildProfileHeaderLoading(),
                  error: (error, _) => _buildProfileError(error.toString()),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons - Only show if not current user
              if (currentUser.hasValue &&
                  currentUser.value != null &&
                  currentUser.value!.id != widget.userId)
                Consumer(
                  builder: (context, ref, child) {
                    return isFriend.when(
                      data: (isAlreadyFriend) =>
                          _buildActionButtons(isAlreadyFriend),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _buildActionButtons(false),
                    );
                  },
                ),

              const SizedBox(height: 16),

              // Posts Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Posts List
                    userPosts.when(
                      data: (posts) {
                        if (posts.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.photo_library_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No posts yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This user hasn\'t shared any workout moments yet.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PostDetailScreen(post: post),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                ),
                                child: post['media_url'] != null
                                    ? Image.network(
                                        post['media_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (error, _) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Error loading posts: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    UserModel user,
    AsyncValue<int> postsCount,
    AsyncValue<int> friendsCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Profile Photo
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  user.profilePhoto != null && user.profilePhoto!.isNotEmpty
                      ? NetworkImage(user.profilePhoto!)
                      : null,
              backgroundColor: Colors.orange.withValues(alpha: 0.2),
              child: user.profilePhoto == null || user.profilePhoto!.isEmpty
                  ? Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Right side - User info and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username
                  Text(
                    user.username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCompactStatItem(
                          postsCount, 'Posts', Icons.photo_library),
                      const SizedBox(width: 40),
                      _buildCompactStatItem(
                          friendsCount, 'Friends', Icons.people,
                          onTap: () => _showFriendsModal(context, user)),
                      const SizedBox(width: 40),
                      _buildCompactStatItem(AsyncValue.data(user.streak),
                          'Streak', Icons.local_fire_department),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Bio below profile photo
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(2),
            child: Text(
              user.bio!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStatItem(
      AsyncValue<int> count, String label, IconData icon,
      {VoidCallback? onTap}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        count.when(
          data: (value) => Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, __) => const Text(
            '0',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildProfileHeaderLoading() {
    return const Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          'Loading...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircularProgressIndicator(),
            CircularProgressIndicator(),
            CircularProgressIndicator(),
          ],
        ),
      ],
    );
  }

  Widget _buildUserNotFound() {
    return Column(
      children: [
        const Icon(
          Icons.person_off,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        Text(
          widget.username ?? 'User not found',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Profile data could not be loaded',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'User ID: ${widget.userId}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileError(String error) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        const Text(
          'Error loading profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error,
          style: const TextStyle(
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isAlreadyFriend) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Only show Add Friend button if not already friends
          if (!isAlreadyFriend) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _sendFriendRequest(),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Friend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: null, // Disabled for now
                icon: const Icon(Icons.check),
                label: const Text('Friends'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Always show Message button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _startChat(),
              icon: const Icon(Icons.message),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendFriendRequest() async {
    try {
      final userService = ref.read(firebaseUserServiceProvider);
      await userService.sendFriendRequest(widget.userId);

      // Refresh friend status and pending requests
      ref.invalidate(isFriendProvider(widget.userId));
      ref.invalidate(pendingFriendRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending friend request: $e');
      if (mounted) {
        String errorMessage = 'Failed to send friend request';

        if (e.toString().contains('Friend request already sent')) {
          errorMessage = 'Friend request already sent!';
        } else if (e.toString().contains('User is not logged in')) {
          errorMessage = 'Please sign in to send friend requests';
        } else if (e.toString().contains('permission-denied')) {
          errorMessage =
              'Permission denied. Please check your internet connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startChat() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );

      // Create or get existing chat
      final chatService = ref.read(chatServiceProvider);
      final chatId = await chatService.createOrGetChat(widget.userId);

      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      if (chatId == null) {
        throw Exception('Failed to create or retrieve chat');
      }

      // Get current user for chat model
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('Current user not found');
      }

      // Get target user info for chat model
      final targetUser =
          await ref.read(userProfileProvider(widget.userId).future);
      if (targetUser == null) {
        throw Exception('Target user not found');
      }

      // Create chat model manually
      final chat = Chat(
        id: chatId,
        user1Id: currentUser.id,
        user2Id: widget.userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        otherUserName: targetUser.username,
        otherUserPhoto: targetUser.profilePhoto,
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(chat: chat),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (mounted) Navigator.of(context).pop();

      print('Error starting chat: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showFriendsModal(BuildContext context, UserModel user) async {
    // Show modal with reactive state management
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Consumer(
        builder: (context, ref, child) {
          final friendsListAsync = ref.watch(userFriendsListProvider(user.id));

          return friendsListAsync.when(
            data: (friends) => FriendsListModal(
              userId: user.id,
              userName: user.username,
              friends: friends,
              isLoading: false,
            ),
            loading: () => FriendsListModal(
              userId: user.id,
              userName: user.username,
              friends: const [],
              isLoading: true,
            ),
            error: (error, _) => FriendsListModal(
              userId: user.id,
              userName: user.username,
              friends: const [],
              isLoading: false,
              error: error.toString(),
            ),
          );
        },
      ),
    );
  }
}
