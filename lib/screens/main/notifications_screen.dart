import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/providers.dart';
import '../../models/chat_model.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../../services/firestore_post_service.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Mark all as read
          TextButton(
            onPressed: () async {
              final currentUser = ref.read(authStateProvider).value;
              if (currentUser != null) {
                final notificationService =
                    ref.read(notificationServiceProvider);
                await notificationService.markAllAsRead(currentUser.uid);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When you get notifications, they\'ll show up here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading notifications',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(userNotificationsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> notification;

  const NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final body = notification['body'] ?? '';
    final senderUsername = notification['sender_username'] ?? 'Unknown';
    final senderProfilePhoto = notification['sender_profile_photo'];
    final createdAt = notification['created_at'];
    final data = notification['data'] as Map<String, dynamic>? ?? {};

    return InkWell(
      onTap: () async {
        // Mark as read
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.markAsRead(notification['id']);

        // Navigate based on notification type
        if (context.mounted) {
          _handleNotificationTap(context, ref, type, data);
        }
      },
      child: Container(
        color: isRead ? Colors.white : Colors.orange.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile photo
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.orange,
              backgroundImage: (senderProfilePhoto != null &&
                      senderProfilePhoto.toString().isNotEmpty)
                  ? CachedNetworkImageProvider(senderProfilePhoto)
                  : null,
              child: (senderProfilePhoto == null ||
                      senderProfilePhoto.toString().isEmpty)
                  ? Text(
                      senderUsername.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Notification content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      _getNotificationIcon(type),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Body (if exists)
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Time
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Unread indicator
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.comment;
        iconColor = Colors.blue;
        break;
      case 'comment_like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'friend_request':
        iconData = Icons.person_add;
        iconColor = Colors.green;
        break;
      case 'friend_accept':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'message':
        iconData = Icons.message;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Icon(iconData, size: 18, color: iconColor);
  }

  String _formatDate(dynamic dateField) {
    try {
      if (dateField == null) return 'now';

      DateTime dateTime;
      if (dateField is String) {
        dateTime = DateTime.parse(dateField);
      } else if (dateField.runtimeType.toString().contains('Timestamp')) {
        dateTime = dateField.toDate();
      } else {
        return 'now';
      }

      return timeago.format(dateTime);
    } catch (e) {
      return 'now';
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    String type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case 'like':
        // For like, just navigate to post
        final postId = data['post_id'];
        if (postId != null) {
          _navigateToPost(context, ref, postId);
        }
        break;

      case 'comment':
      case 'comment_like':
        // For comment, send both post and comment ID
        final postId = data['post_id'];
        final commentId = data['comment_id'];
        if (postId != null) {
          _navigateToPost(context, ref, postId, commentId: commentId);
        }
        break;

      case 'friend_request':
      case 'friend_accept':
        // Navigate to profile (or friends screen)
        final senderId = notification['sender_id'];
        if (senderId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: senderId,
                username: notification['sender_username'] ?? 'User',
              ),
            ),
          );
        }
        break;

      case 'message':
        // Navigate to chat
        final chatId = data['chat_id'];
        final senderId = notification['sender_id'];
        if (chatId != null && senderId != null) {
          // Create a Chat object for navigation
          final chat = {
            'id': chatId,
            'participants': [
              ref.read(authStateProvider).value?.uid ?? '',
              senderId
            ],
            'otherUserName': notification['sender_username'] ?? 'User',
            'otherUserPhoto': notification['sender_profile_photo'],
          };

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chat: Chat.fromJson(chat),
              ),
            ),
          );
        }
        break;
    }
  }

  Future<void> _navigateToPost(
    BuildContext context,
    WidgetRef ref,
    String postId, {
    String? commentId, // Optional comment ID
  }) async {
    try {
      // Fetch post data with user info
      final postService = ref.read(firestorePostServiceProvider);
      final post = await postService.getPostByIdWithUser(postId);

      if (post != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              post: post,
              highlightCommentId: commentId, // Highlight comment
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post not found or has been deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
