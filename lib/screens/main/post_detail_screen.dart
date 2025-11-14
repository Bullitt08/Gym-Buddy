import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/providers.dart';
import '../../services/firestore_post_service.dart';
import '../main/user_profile_screen.dart';
import '../main/gym_profile_screen.dart' as gym_profile;
import '../../widgets/likes_bottom_sheet.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final String? highlightCommentId; // For scrolling to comment

  const PostDetailScreen({
    super.key,
    required this.post,
    this.highlightCommentId,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isCommentEmpty = true;
  final Map<String, GlobalKey> _commentKeys = {}; // Key for each comment
  bool _shouldHighlight = true; // Highlight state
  bool _hasScrolledToComment = false; // Check if scroll was done

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  void _scrollToComment(String commentId) {
    if (_hasScrolledToComment)
      return; // Don't scroll again if already scrolled once

    final key = _commentKeys[commentId];
    if (key?.currentContext != null) {
      _hasScrolledToComment = true;

      // Scroll operation
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2, // Show comment close to the top of screen
      );

      // Remove highlight after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _shouldHighlight = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    final trackId = widget.post['music_track_id'];
    if (trackId == null || trackId.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müzik bilgisi bulunamadı'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final deezerService = ref.read(deezerServiceProvider);
      final track = await deezerService.getTrack(trackId.toString());

      if (track == null ||
          track.previewUrl == null ||
          track.previewUrl!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu şarkı için önizleme mevcut değil'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(track.previewUrl!));

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müzik çalınamadı. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'];
    if (postId == null) return;

    try {
      final currentUser = await ref.read(authStateProvider.future);
      if (currentUser?.uid == null) return;

      final postService = ref.read(firestorePostServiceProvider);
      await postService.toggleLike(postId, currentUser!.uid);
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final commentText = _commentController.text.trim();
      _commentController.clear();

      setState(() {
        _isCommentEmpty = true;
      });

      final postService = ref.read(firestorePostServiceProvider);
      await postService.addComment(
        widget.post['id'],
        currentUser!.id,
        commentText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) return;

      final postService = ref.read(firestorePostServiceProvider);
      await postService.toggleCommentLike(
          commentId.toString(), currentUser!.id.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCommentAction(
      String action, String commentId, bool isCurrentUserComment) async {
    if (action == 'delete') {
      try {
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser?.id == null) return;

        final postService = ref.read(firestorePostServiceProvider);

        if (isCurrentUserComment) {
          await postService.deleteComment(commentId, currentUser!.id);
        } else if (currentUser!.id == widget.post['user_id']) {
          await postService.deleteCommentByPostOwner(commentId, currentUser.id);
        } else {
          throw Exception('You do not have permission to delete this comment');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'report':
        _showReportDialog();
        break;
      case 'hide':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post hidden')),
        );
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post reported')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePost();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    final postId = widget.post['id'];
    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Post ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Deleting post...'),
          ],
        ),
        duration: Duration(milliseconds: 100),
      ),
    );

    try {
      final currentUser = await ref.read(authStateProvider.future);
      if (currentUser?.uid == null) {
        throw Exception('User not authenticated');
      }

      final postService = ref.read(firestorePostServiceProvider);
      await postService.deletePost(postId);

      ref.invalidate(friendsPostsProvider);
      ref.invalidate(postsProvider);
      ref.invalidate(userPostsProvider(currentUser!.uid));
      ref.invalidate(currentUserPostsCountProvider);

      final refreshNotifier = ref.read(gymDataRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.of(context).pop(); // Go back after deletion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getUserInitial(String? username) {
    if (username == null || username.isEmpty) return 'U';
    return username.substring(0, 1).toUpperCase();
  }

  String _formatDate(dynamic dateField) {
    try {
      if (dateField == null) return 'Unknown time';

      DateTime dateTime;
      if (dateField is String) {
        dateTime = DateTime.parse(dateField);
      } else if (dateField.runtimeType.toString().contains('Timestamp')) {
        dateTime = dateField.toDate();
      } else {
        return 'Unknown time';
      }

      return timeago.format(dateTime);
    } catch (e) {
      return 'Unknown time';
    }
  }

  void _showLikes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LikesBottomSheet(
        postId: widget.post['id'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['users'] as Map<String, dynamic>? ??
        {
          'id': widget.post['user_id'] ?? '',
          'username': 'Unknown User',
          'profile_photo': null,
        };

    final currentUserAsync = ref.watch(currentUserProvider);
    final likesCount =
        ref.watch(postLikesCountProvider(widget.post['id'] ?? ''));
    final isLiked = ref.watch(postLikeProvider(widget.post['id'] ?? ''));
    final commentsCount =
        ref.watch(postCommentsCountProvider(widget.post['id'] ?? ''));
    final comments = ref.watch(postCommentsProvider(widget.post['id'] ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          currentUserAsync.when(
            data: (currentUser) {
              if (currentUser?.id != widget.post['user_id']) {
                return PopupMenuButton<String>(
                  onSelected: (value) async {
                    await Future.delayed(const Duration(milliseconds: 50));
                    if (context.mounted) {
                      _handleMenuAction(value);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, size: 20),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off, size: 20),
                          SizedBox(width: 8),
                          Text('Hide'),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return PopupMenuButton<String>(
                  onSelected: (value) async {
                    await Future.delayed(const Duration(milliseconds: 50));
                    if (context.mounted) {
                      _handleMenuAction(value);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info header
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    dense: true,
                    onTap: () {
                      // Use navigation provider to go to user profile with navbar
                      final container = ProviderScope.containerOf(context);
                      container
                          .read(navigationProvider.notifier)
                          .goToUserProfile(
                            user['id'],
                          );
                    },
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange,
                      backgroundImage: (user['profile_photo'] != null &&
                              user['profile_photo'].toString().isNotEmpty)
                          ? CachedNetworkImageProvider(user['profile_photo'])
                          : null,
                      child: (user['profile_photo'] == null ||
                              user['profile_photo'].toString().isEmpty)
                          ? Text(
                              _getUserInitial(user['username']),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            )
                          : null,
                    ),
                    title: Text(
                      user['username'] ?? 'Unknown User',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tagged Users with location in header
                        if (widget.post['tagged_users'] != null &&
                            (widget.post['tagged_users'] as List)
                                .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          _buildTaggedUsersWithLocation(
                            widget.post['tagged_users'] as List,
                            widget.post['location_name'],
                          ),
                        ] else if (widget.post['location_name'] != null &&
                            widget.post['location_name']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          _buildLocationOnly(widget.post['location_name']),
                        ],
                      ],
                    ),
                  ),

                  // Music player
                  if (widget.post['music_track_name'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade50,
                            Colors.orange.shade100
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (widget.post['music_album_art'] != null &&
                                    widget.post['music_album_art']
                                        .toString()
                                        .isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: widget.post['music_album_art'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.music_note,
                                          size: 24),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.music_note,
                                          size: 24),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.orange.shade200,
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.post['music_track_name'] ??
                                      'Unknown Track',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.post['music_artist'] ??
                                      'Unknown Artist',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final trackId = widget.post['music_track_id'];
                              if (trackId != null &&
                                  trackId.toString().isNotEmpty) {
                                _toggleMusic();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Müzik bilgisi bulunamadı'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              widget.post['music_track_id'] != null
                                  ? (_isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled)
                                  : Icons.music_off,
                              size: 40,
                              color: widget.post['music_track_id'] != null
                                  ? (_isPlaying
                                      ? Colors.orange.shade700
                                      : Colors.orange)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Post media
                  if (widget.post['media_url'] != null)
                    AspectRatio(
                      aspectRatio: 0.7,
                      child: CachedNetworkImage(
                        imageUrl: widget.post['media_url'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child:
                                Icon(Icons.error, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),

                  // Caption - centered
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Caption - moved above action buttons
                        if (widget.post['caption'] != null &&
                            widget.post['caption'].isNotEmpty) ...[
                          Text(
                            widget.post['caption'],
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Action buttons row
                        Row(
                          children: [
                            // Like button
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                children: [
                                  isLiked.when(
                                    data: (liked) => Icon(
                                      liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 24,
                                      color:
                                          liked ? Colors.red : Colors.grey[700],
                                    ),
                                    loading: () => Icon(
                                      Icons.favorite_border,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                    error: (_, __) => Icon(
                                      Icons.favorite_border,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showLikes(),
                                    child: likesCount.when(
                                      data: (count) => Text(
                                        count.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      loading: () => Text(
                                        '0',
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      ),
                                      error: (_, __) => Text(
                                        '0',
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Comment button
                            GestureDetector(
                              onTap: () {
                                _commentFocusNode.requestFocus();
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 24,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  commentsCount.when(
                                    data: (count) => Text(
                                      count.toString(),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    loading: () => Text(
                                      '0',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    error: (_, __) => Text(
                                      '0',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Timestamp
                        Text(
                          _formatDate(widget.post['created_at']),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        comments.when(
                          data: (commentsList) {
                            if (commentsList.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    'No comments yet\nBe the first to comment!',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: commentsList.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final comment = commentsList[index];
                                final commentUser = comment['users'] ?? {};
                                final commentId = comment['id'];

                                // Create key for each comment
                                if (!_commentKeys.containsKey(commentId)) {
                                  _commentKeys[commentId] = GlobalKey();
                                }
                                final isHighlighted =
                                    widget.highlightCommentId == commentId &&
                                        _shouldHighlight;

                                // If this comment should be highlighted and scroll hasn't been done yet
                                if (widget.highlightCommentId == commentId &&
                                    !_hasScrolledToComment) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollToComment(commentId);
                                  });
                                }

                                return currentUserAsync.when(
                                  data: (currentUser) {
                                    final isCurrentUserComment =
                                        currentUser?.id == comment['user_id'];
                                    final likesCount = ref.watch(
                                        commentLikesCountProvider(commentId));
                                    final isLiked = ref.watch(
                                        commentLikeProvider(
                                            commentId.toString()));

                                    return AnimatedContainer(
                                      key: _commentKeys[commentId],
                                      duration:
                                          const Duration(milliseconds: 800),
                                      curve: Curves.easeOut,
                                      padding: isHighlighted
                                          ? const EdgeInsets.all(8)
                                          : EdgeInsets.zero,
                                      decoration: isHighlighted
                                          ? BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.orange.shade200,
                                                width: 2,
                                              ),
                                            )
                                          : null,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.orange,
                                            backgroundImage: (commentUser[
                                                            'profile_photo'] !=
                                                        null &&
                                                    commentUser['profile_photo']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? CachedNetworkImageProvider(
                                                    commentUser[
                                                        'profile_photo'])
                                                : null,
                                            child: (commentUser[
                                                            'profile_photo'] ==
                                                        null ||
                                                    commentUser['profile_photo']
                                                        .toString()
                                                        .isEmpty)
                                                ? Text(
                                                    _getUserInitial(commentUser[
                                                        'username']),
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            commentUser[
                                                                    'username'] ??
                                                                'Unknown User',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            _formatDate(comment[
                                                                'created_at']),
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                                fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        comment['comment']
                                                                ?.toString() ??
                                                            'No comment text',
                                                        style: const TextStyle(
                                                            fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  children: [
                                                    if (currentUser != null &&
                                                        (isCurrentUserComment ||
                                                            currentUser.id ==
                                                                widget.post[
                                                                    'user_id']))
                                                      PopupMenuButton<String>(
                                                        icon: Icon(
                                                            Icons.more_vert,
                                                            size: 16,
                                                            color: Colors
                                                                .grey[600]),
                                                        onSelected: (value) =>
                                                            _handleCommentAction(
                                                                value,
                                                                commentId,
                                                                isCurrentUserComment),
                                                        itemBuilder:
                                                            (context) => [
                                                          const PopupMenuItem<
                                                              String>(
                                                            value: 'delete',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .delete,
                                                                    size: 16,
                                                                    color: Colors
                                                                        .red),
                                                                SizedBox(
                                                                    width: 8),
                                                                Text('Delete',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    else
                                                      const SizedBox(
                                                          height: 24),
                                                    GestureDetector(
                                                      onTap: currentUser != null
                                                          ? () =>
                                                              _toggleCommentLike(
                                                                  commentId)
                                                          : null,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          isLiked.when(
                                                            data: (liked) =>
                                                                Icon(
                                                              liked
                                                                  ? Icons
                                                                      .favorite
                                                                  : Icons
                                                                      .favorite_border,
                                                              size: 16,
                                                              color: liked
                                                                  ? Colors.red
                                                                  : Colors.grey[
                                                                      600],
                                                            ),
                                                            loading: () => Icon(
                                                                Icons
                                                                    .favorite_border,
                                                                size: 16,
                                                                color: Colors
                                                                    .grey[600]),
                                                            error: (_, __) => Icon(
                                                                Icons
                                                                    .favorite_border,
                                                                size: 16,
                                                                color: Colors
                                                                    .grey[600]),
                                                          ),
                                                          if (likesCount
                                                                      .value !=
                                                                  null &&
                                                              likesCount
                                                                      .value! >
                                                                  0) ...[
                                                            const SizedBox(
                                                                width: 4),
                                                            likesCount.when(
                                                              data: (count) =>
                                                                  Text(
                                                                count
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600],
                                                                    fontSize:
                                                                        12),
                                                              ),
                                                              loading: () =>
                                                                  const SizedBox
                                                                      .shrink(),
                                                              error: (_, __) =>
                                                                  const SizedBox
                                                                      .shrink(),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stackTrace) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text('Error loading comments',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ref.invalidate(postCommentsProvider(
                                          widget.post['id']));
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    onChanged: (text) {
                      setState(() {
                        _isCommentEmpty = text.trim().isEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.orange),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isCommentEmpty ? null : _addComment,
                  icon: Icon(
                    Icons.send,
                    color: _isCommentEmpty ? Colors.grey : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationOnly(String locationName) {
    return GestureDetector(
      onTap: () => _navigateToGymProfile(
        context,
        widget.post,
        widget.post['location'] ?? {},
      ),
      child: Wrap(
        children: [
          Text(
            'in ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
          Text(
            '@$locationName',
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaggedUsersWithLocation(List taggedUsers, String? locationName) {
    if (taggedUsers.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTaggedUsersInfo(taggedUsers),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text(
            'Loading...',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          );
        }

        final users = snapshot.data!;

        return Wrap(
          spacing: 1,
          children: [
            Text(
              'with ',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
            ...users.map((user) => GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: user['id'],
                          username: user['username'],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '@${user['username'] ?? 'Unknown'}${users.indexOf(user) < users.length - 1 ? ', ' : ''}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
            if (locationName != null && locationName.isNotEmpty) ...[
              Text(
                ' in ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToGymProfile(
                  context,
                  widget.post,
                  widget.post['location'] ?? {},
                ),
                child: Text(
                  '@$locationName',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _navigateToGymProfile(BuildContext context, Map<String, dynamic> post,
      Map<String, dynamic> location) {
    String gymName = 'Unknown Gym';
    if (post['location_name'] != null &&
        post['location_name'].toString().isNotEmpty) {
      gymName = post['location_name'].toString();
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => gym_profile.GymProfileScreen(
          gymId: gymName,
          gymName: gymName,
          placeId: post['place_id'], // This might be null
          lat: location['lat']?.toDouble(),
          lng: location['lng']?.toDouble(),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTaggedUsersInfo(
      List taggedUsers) async {
    try {
      final userService = ref.read(firebaseUserServiceProvider);
      final List<Map<String, dynamic>> users = [];

      for (String userId in taggedUsers) {
        try {
          final userModel = await userService.getUserProfile(userId);
          if (userModel != null) {
            users.add({
              'id': userModel.id,
              'username': userModel.username,
              'profile_photo': userModel.profilePhoto,
            });
          }
        } catch (e) {
          // If user not found, add placeholder
          users.add({
            'id': userId,
            'username': 'Unknown User',
            'profile_photo': null,
          });
        }
      }

      return users;
    } catch (e) {
      return [];
    }
  }
}
