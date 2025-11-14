import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment, color: Colors.black),
            onPressed: () => _showNewChatDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recent Chats Section
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final recentChats = ref.watch(recentChatsProvider);

                return recentChats.when(
                  data: (chats) {
                    if (chats.isEmpty) {
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
                              'No conversations yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start chatting with your gym buddies',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showNewChatDialog(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Start Chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Recent Chats',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: chats.length,
                            itemBuilder: (context, index) {
                              final chat = chats[index];
                              final otherUser = chat['other_user'] ?? {};
                              final lastMessage = chat['last_message'] ?? '';
                              final lastMessageTime = chat['last_message_time'];

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.orange,
                                  backgroundImage: otherUser['profile_image'] !=
                                              null &&
                                          otherUser['profile_image']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(otherUser['profile_image'])
                                      : null,
                                  onBackgroundImageError:
                                      (exception, stackTrace) {
                                    print('Profile image error: $exception');
                                  },
                                  child: otherUser['profile_image'] == null ||
                                          otherUser['profile_image']
                                              .toString()
                                              .isEmpty
                                      ? Text(
                                          (otherUser['username']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true)
                                              ? otherUser['username'][0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  otherUser['username'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: lastMessage.isNotEmpty
                                    ? Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      )
                                    : Text(
                                        'Tap to start chatting',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                trailing: Consumer(
                                  builder: (context, ref, child) {
                                    // Get unread count for this chat
                                    final chatUnreadCount = ref.watch(
                                        chatUnreadCountProvider(chat['id']));

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        // Time information
                                        if (lastMessageTime != null)
                                          Text(
                                            _formatMessageTime(
                                                lastMessageTime.toDate()),
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        // Unread count badge
                                        chatUnreadCount.when(
                                          data: (count) => count > 0
                                              ? Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 20,
                                                    minHeight: 20,
                                                  ),
                                                  child: Text(
                                                    count > 99
                                                        ? '99+'
                                                        : count.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                          loading: () =>
                                              const SizedBox.shrink(),
                                          error: (_, __) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                onTap: () {
                                  final participants = List<String>.from(
                                      chat['participants'] ?? []);

                                  final chatModel = Chat(
                                    id: chat['id'],
                                    user1Id: participants.isNotEmpty
                                        ? participants[0]
                                        : '',
                                    user2Id: participants.length > 1
                                        ? participants[1]
                                        : '',
                                    lastMessage: lastMessage,
                                    lastMessageTime: lastMessageTime?.toDate(),
                                    createdAt: chat['created_at']?.toDate() ??
                                        DateTime.now(),
                                    updatedAt: lastMessageTime?.toDate() ??
                                        DateTime.now(),
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChatDetailScreen(chat: chatModel),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load chats',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => ref.refresh(recentChatsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => NewChatDialog(ref: ref),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show in hour:minute format
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older - show date
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      return '$day.$month';
    }
  }
}

class NewChatDialog extends StatefulWidget {
  final WidgetRef ref;

  const NewChatDialog({super.key, required this.ref});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh providers when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProviders();
    });
  }

  void _refreshProviders() {
    try {
      print('DEBUG: Refreshing all providers...');

      // Clear search query
      widget.ref.read(searchQueryProvider.notifier).state = '';
      _searchController.clear();

      // Invalidate all search providers
      widget.ref.invalidate(simpleSearchUsersProvider);
      widget.ref.invalidate(reactiveSearchUsersProvider);

      // Also refresh chat and user providers
      widget.ref.invalidate(userChatsProvider);
      widget.ref.invalidate(currentUserProvider);
      widget.ref.invalidate(friendsProvider);

      // Get current user and refresh friends providers
      widget.ref.read(currentUserProvider).whenData((user) {
        if (user != null) {
          print('DEBUG: Refreshing friends list for user: ${user.id}');
          widget.ref.invalidate(userFriendsListProvider(user.id));
        }
      });

      print('DEBUG: Providers refreshed successfully');
    } catch (e) {
      print('DEBUG: Error refreshing providers: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = widget.ref.watch(currentUserProvider);

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'New Message',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshProviders,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final currentQuery = ref.watch(searchQueryProvider);

                // Sync controller text with state
                if (_searchController.text != currentQuery) {
                  _searchController.text = currentQuery;
                }

                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: currentQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              ref.read(searchQueryProvider.notifier).state = '';
                              _searchController.clear();
                              _refreshProviders();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    print('DEBUG: Search input changed to: "$value"');

                    // Update StateProvider
                    ref.read(searchQueryProvider.notifier).state = value;

                    // Aggressive cache invalidation
                    ref.invalidate(reactiveSearchUsersProvider);
                    ref.invalidate(simpleSearchUsersProvider);

                    // Immediate UI update
                    setState(() {});
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final currentQuery = ref.watch(searchQueryProvider);
                  print('DEBUG: Building content with query: "$currentQuery"');

                  return currentQuery.isEmpty
                      ? _buildFriendsList(currentUserAsync)
                      : _buildSearchResults();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(AsyncValue<UserModel?> currentUserAsync) {
    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Center(child: Text('Please log in first'));
        }

        // Use global friends provider - more reliable
        final friendsAsync = widget.ref.watch(friendsProvider);

        return friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No friends yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add friends to start chatting!',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Your Friends',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          _refreshProviders();
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.orange,
                          backgroundImage: friend.profilePhoto != null &&
                                  friend.profilePhoto!.isNotEmpty
                              ? NetworkImage(friend.profilePhoto!)
                              : null,
                          onBackgroundImageError: (exception, stackTrace) {
                            print('Friend profile image error: $exception');
                          },
                          child: friend.profilePhoto == null ||
                                  friend.profilePhoto!.isEmpty
                              ? Text(
                                  friend.username.isNotEmpty
                                      ? friend.username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(friend.username),
                        subtitle: friend.bio != null && friend.bio!.isNotEmpty
                            ? Text(
                                friend.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.orange,
                        ),
                        onTap: () => _startChatWithUser(friend),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Error loading friends: \$error'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: \$error'),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, child) {
        final currentQuery = ref.watch(searchQueryProvider);
        print('DEBUG: _buildSearchResults called with query: "$currentQuery"');

        // Get fresh data on every query change
        final searchResults = ref.watch(reactiveSearchUsersProvider);

        print('DEBUG: Search results status: ${searchResults.runtimeType}');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Search Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: searchResults.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No users found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.orange,
                          backgroundImage: user['profile_photo'] != null &&
                                  user['profile_photo'].toString().isNotEmpty
                              ? NetworkImage(user['profile_photo'])
                              : null,
                          onBackgroundImageError: (exception, stackTrace) {
                            print(
                                'Search user profile image error: $exception');
                          },
                          child: user['profile_photo'] == null ||
                                  user['profile_photo'].toString().isEmpty
                              ? Text(
                                  (user['username']?.toString().isNotEmpty ==
                                          true)
                                      ? user['username'][0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(user['username'] ?? 'Unknown User'),
                        subtitle:
                            user['bio'] != null ? Text(user['bio']!) : null,
                        trailing: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.orange,
                        ),
                        onTap: () => _startChatWithSearchUser(user),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'Searching users...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Search Error',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          final query = _searchController.text;
                          // Update SearchQuery provider - this automatically triggers search
                          widget.ref.read(searchQueryProvider.notifier).state =
                              query;
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startChatWithUser(UserModel friend) async {
    Navigator.of(context).pop(); // Close dialog

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat with ${friend.username}...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // Create or get existing chat
      final chatService = widget.ref.read(chatServiceProvider);
      final chatId = await chatService.createOrGetChat(friend.id);

      if (chatId != null) {
        // Get current user
        final currentUser = await widget.ref.read(authStateProvider.future);
        if (currentUser != null) {
          // Navigate to ChatDetailScreen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chat: Chat(
                  id: chatId,
                  user1Id: currentUser.uid,
                  user2Id: friend.id,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  otherUserName: friend.username,
                  otherUserPhoto: friend.profilePhoto,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startChatWithSearchUser(Map<String, dynamic> user) async {
    Navigator.of(context).pop(); // Close dialog

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat with ${user['username']}...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // Create or get existing chat
      final chatService = widget.ref.read(chatServiceProvider);
      final chatId = await chatService.createOrGetChat(user['id']);

      if (chatId != null) {
        // Get current user
        final currentUser = await widget.ref.read(authStateProvider.future);
        if (currentUser != null) {
          // Navigate to ChatDetailScreen
          final userModel = UserModel.fromJson(user);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chat: Chat(
                  id: chatId,
                  user1Id: currentUser.uid,
                  user2Id: userModel.id,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  otherUserName: userModel.username,
                  otherUserPhoto: userModel.profilePhoto,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
