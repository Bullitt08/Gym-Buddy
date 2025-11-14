import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/providers.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasMarkedAsDelivered = false; // Flag to ensure marking only once
  String? _currentUserId; // Store user ID

  @override
  void initState() {
    super.initState();
    // Mark messages from the other party as delivered when entering chat
    // Use flag to ensure it runs only once
    if (!_hasMarkedAsDelivered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markMessagesAsDelivered();
        _setActiveChatId();
        _hasMarkedAsDelivered = true;
      });
    }
  }

  @override
  void dispose() {
    // Can't use ref in dispose, so clean up directly with user ID
    if (_currentUserId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'active_chat_id': null});
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Mark that the user is actively in this chat
  Future<void> _setActiveChatId() async {
    try {
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser != null) {
        _currentUserId = currentUser.uid; // Store ID
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'active_chat_id': widget.chat.id});
      }
    } catch (e) {
      print('Error setting active chat id: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chat.id));
    final currentUserAsync = ref.watch(currentUserProvider);
    final otherUserAsync = ref.watch(chatOtherUserProvider(widget.chat.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Consumer(
          builder: (context, ref, child) {
            return otherUserAsync.when(
              data: (otherUser) {
                final username = otherUser?['username'] ??
                    widget.chat.otherUserName ??
                    'Unknown User';
                final profileImage =
                    otherUser?['profile_photo'] ?? widget.chat.otherUserPhoto;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange,
                      backgroundImage: profileImage != null &&
                              profileImage.toString().isNotEmpty
                          ? NetworkImage(profileImage)
                          : null,
                      onBackgroundImageError: (exception, stackTrace) {
                        print('Profile image error: $exception');
                      },
                      child: profileImage == null ||
                              profileImage.toString().isEmpty
                          ? Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange,
                    child: widget.chat.otherUserPhoto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.chat.otherUserPhoto!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.chat.otherUserName ?? 'Loading...',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              error: (error, stack) => Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.chat.otherUserName ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messagesData) {
                final messages = messagesData
                    .map((messageMap) => Message(
                          id: messageMap['id'] ?? '',
                          chatId: widget.chat.id,
                          senderId: messageMap['sender_id'] ?? '',
                          content: messageMap['message'] ?? '',
                          type: MessageType.text,
                          createdAt: messageMap['timestamp'] != null
                              ? (messageMap['timestamp'] as Timestamp).toDate()
                              : DateTime.now(),
                          isDelivered: !(messageMap['is_read'] == false),
                        ))
                    .toList()
                  ..sort((a, b) => a.createdAt
                      .compareTo(b.createdAt)); // Sort from oldest to newest
                return _buildMessageList(
                    messages, currentUserAsync, otherUserAsync);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load messages',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.refresh(chatMessagesProvider(widget.chat.id)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildMessageInput(currentUserAsync),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, AsyncValue currentUserAsync,
      AsyncValue otherUserAsync) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previousMessage = index > 0 ? messages[index - 1] : null;
        final showDateHeader = _shouldShowDateHeader(message, previousMessage);

        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(message.createdAt),
            _buildMessageBubble(message, currentUserAsync, otherUserAsync),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Message message, AsyncValue currentUserAsync, AsyncValue otherUserAsync) {
    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) return const SizedBox.shrink();

        final isFromCurrentUser = message.isFromCurrentUser(currentUser.id);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 8), // Dış padding ekledik
          child: Row(
            mainAxisAlignment: isFromCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isFromCurrentUser) ...[
                // Get other user's profile photo from otherUserAsync
                otherUserAsync.when(
                  data: (otherUser) => CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange,
                    backgroundImage: otherUser?['profile_photo'] != null &&
                            otherUser!['profile_photo'].toString().isNotEmpty
                        ? NetworkImage(otherUser['profile_photo'])
                        : null,
                    child: otherUser?['profile_photo'] == null ||
                            otherUser!['profile_photo'].toString().isEmpty
                        ? Text(
                            otherUser['username']?.toString().isNotEmpty == true
                                ? otherUser['username'][0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          )
                        : null,
                  ),
                  loading: () => const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  error: (_, __) => const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.orange,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      0.75, // 75% of screen width
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFromCurrentUser ? Colors.orange : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isFromCurrentUser ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isFromCurrentUser
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.grey[600],
                            ),
                          ),
                          // Show checkmarks only for our own messages
                          if (isFromCurrentUser) ...[
                            const SizedBox(width: 4),
                            _buildMessageStatusTicks(
                                message, isFromCurrentUser),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Space for incoming messages on the left
              if (!isFromCurrentUser) const SizedBox(width: 16),
              // Less space for outgoing messages on the right
              if (isFromCurrentUser) const SizedBox(width: 16),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMessageInput(AsyncValue currentUserAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(currentUserAsync),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendMessage(currentUserAsync),
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(AsyncValue currentUserAsync) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    currentUserAsync.when(
      data: (currentUser) async {
        if (currentUser == null) return;

        _messageController.clear();

        try {
          // Send message using the service directly
          final chatService = ref.read(chatServiceProvider);
          await chatService.sendMessage(widget.chat.id, content);

          // Refresh the messages provider to show the new message
          ref.invalidate(chatMessagesProvider(widget.chat.id));
          ref.invalidate(userChatsProvider);
          ref.invalidate(unreadMessagesCountProvider);

          // Scroll to bottom after a small delay to ensure message is added
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send message: $e')),
            );
          }
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Widget _buildMessageStatusTicks(Message message, bool isFromCurrentUser) {
    if (!isFromCurrentUser) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First checkmark - message sent (always show)
        Icon(
          Icons.check,
          size: 12,
          color: isFromCurrentUser
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.grey[600],
        ),
        // Second checkmark - message delivered (when other party enters chat)
        if (message.isDelivered)
          Icon(
            Icons.check,
            size: 12,
            color: isFromCurrentUser
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.grey[600],
          ),
      ],
    );
  }

  void _markMessagesAsDelivered() async {
    if (_hasMarkedAsDelivered) {
      // Messages already marked as delivered for this session
      return;
    }

    final currentUser = await ref.read(authStateProvider.future);
    if (currentUser == null) return;

    try {
      // Mark only messages in this chat that were sent to me and not yet delivered
      final chatService = ref.read(chatServiceProvider);
      await chatService.markMessagesAsRead(widget.chat.id, currentUser.uid);

      // Refresh providers
      ref.invalidate(userChatsProvider);
      ref.invalidate(unreadMessagesCountProvider);
      ref.invalidate(chatMessagesProvider(widget.chat.id));

      // Messages marked as delivered for chat
      _hasMarkedAsDelivered = true;
    } catch (e) {
      // Error marking messages as delivered
    }
  }

  bool _shouldShowDateHeader(Message message, Message? previousMessage) {
    if (previousMessage == null) return true;

    final messageDate = DateTime(
      message.createdAt.year,
      message.createdAt.month,
      message.createdAt.day,
    );
    final previousDate = DateTime(
      previousMessage.createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );

    return !messageDate.isAtSameMomentAs(previousDate);
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
