import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../services/firestore_post_service.dart';
import '../screens/main/user_profile_screen.dart';
import '../screens/main/gym_profile_screen.dart' as gym_profile;
import '../screens/main/post_detail_screen.dart';
import 'likes_bottom_sheet.dart';

class PostCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      print('DEBUG PLAYER STATE CHANGED: $state');
      if (mounted) {
        setState(() {
          final wasPlaying = _isPlaying;
          _isPlaying = state == PlayerState.playing;
          print('DEBUG: _isPlaying changed from $wasPlaying to $_isPlaying');
        });
      }
    });

    // Also listen to player complete events
    _audioPlayer.onPlayerComplete.listen((event) {
      print('DEBUG: Player completed playback');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    print('DEBUG: _toggleMusic called');

    // Check if currently playing - if so, just pause
    if (_isPlaying) {
      print('DEBUG: Pausing music...');
      await _audioPlayer.pause();
      return;
    }

    // Get track ID to fetch fresh preview URL
    final trackId = widget.post['music_track_id'];
    print('DEBUG: Track ID = $trackId');

    if (trackId == null || trackId.toString().isEmpty) {
      print('DEBUG: Track ID is null or empty');
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
      // Fetch fresh track data from Deezer API
      print('DEBUG: Fetching fresh preview URL from Deezer API...');
      final deezerService = ref.read(deezerServiceProvider);
      final track = await deezerService.getTrack(trackId.toString());

      if (track == null ||
          track.previewUrl == null ||
          track.previewUrl!.isEmpty) {
        print('DEBUG: No preview URL available from Deezer');
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

      print('DEBUG: Fresh preview URL obtained: ${track.previewUrl}');

      // Stop any previous playback first
      await _audioPlayer.stop();

      // Play the new source with fresh URL
      print('DEBUG: Playing music...');
      await _audioPlayer.play(UrlSource(track.previewUrl!));
      print('DEBUG: Play command sent successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    } catch (e, stackTrace) {
      print('Music playback error: $e');
      print('DEBUG: Full error: ${e.toString()}');
      print('DEBUG: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Music playback failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _autoPlayMusic() async {
    if (_hasAutoPlayed) return;

    final previewUrl = widget.post['music_preview_url'];
    if (previewUrl == null || previewUrl.toString().isEmpty) return;

    try {
      _hasAutoPlayed = true;
      await _audioPlayer.play(UrlSource(previewUrl));
    } catch (e) {
      print('Auto-play error: $e');
    }
  }

  Future<void> _stopMusic() async {
    try {
      await _audioPlayer.stop();
      _hasAutoPlayed = false;
    } catch (e) {
      print('Stop music error: $e');
    }
  }

  Future<void> _openInDeezer(String trackId) async {
    try {
      final deezerUri = 'deezer://www.deezer.com/track/$trackId';
      final webUrl = 'https://www.deezer.com/track/$trackId';

      // Try to open in Deezer app first
      final uri = Uri.parse(deezerUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web player
        final webUri = Uri.parse(webUrl);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening Deezer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-play disabled - emulator has audio issues
    // Music can be played manually by tapping the play button

    // Debug: Print post data to check music fields
    if (widget.post['music_track_name'] != null) {
      print('DEBUG POST MUSIC DATA:');
      print('Track Name: ${widget.post['music_track_name']}');
      print('Artist: ${widget.post['music_artist']}');
      print('Album Art: ${widget.post['music_album_art']}');
      print('Preview URL: ${widget.post['music_preview_url']}');
    }

    // Safe handling of user data
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Stack(
        children: [
          Column(
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
                  container.read(navigationProvider.notifier).goToUserProfile(
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
                        (widget.post['tagged_users'] as List).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _buildTaggedUsersWithLocation(
                        widget.post['tagged_users'] as List,
                        widget.post['location_name'],
                      ),
                    ] else if (widget.post['location_name'] != null &&
                        widget.post['location_name'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _buildLocationOnly(widget.post['location_name']),
                    ],
                  ],
                ),
              ),

              // Music player box (compact version in header)
              if (widget.post['music_track_name'] != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.orange.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      // Album art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: (widget.post['music_album_art'] != null &&
                                widget.post['music_album_art']
                                    .toString()
                                    .isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: widget.post['music_album_art'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.music_note, size: 20),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.music_note, size: 20),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: Colors.orange.shade200,
                                child: const Icon(
                                  Icons.music_note,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),

                      // Track info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post['music_track_name'] ??
                                  'Unknown Track',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.post['music_artist'] ?? 'Unknown Artist',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause button
                      IconButton(
                        onPressed: () {
                          print('DEBUG: IconButton onPressed called');
                          print(
                              'DEBUG: music_track_id = ${widget.post['music_track_id']}');

                          final trackId = widget.post['music_track_id'];

                          if (trackId != null &&
                              trackId.toString().isNotEmpty) {
                            print('DEBUG: Calling _toggleMusic()');
                            _toggleMusic();
                          } else {
                            print('DEBUG: No music track ID available');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Müzik bilgisi bulunamadı'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          widget.post['music_track_id'] != null
                              ? (_isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled)
                              : Icons.music_off,
                          size: 36,
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
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PostDetailScreen(post: widget.post),
                      ),
                    );
                  },
                  child: AspectRatio(
                    aspectRatio: 0.7,
                    child: CachedNetworkImage(
                      imageUrl: widget.post['media_url'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.error,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Post actions and info
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
                                  color: liked ? Colors.red : Colors.grey[700],
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
                                onTap: () => _showLikes(context),
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
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  error: (_, __) => Text(
                                    '0',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Comment button
                        GestureDetector(
                          onTap: () => _showComments(context),
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
            ],
          ),

          // Popup menu button positioned at top right
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              onSelected: (value) async {
                // Add delay to prevent widget lifecycle issues
                await Future.delayed(const Duration(milliseconds: 50));
                if (context.mounted) {
                  _handleMenuAction(context, value);
                }
              },
              itemBuilder: (BuildContext context) {
                return currentUserAsync.when(
                  data: (currentUser) {
                    if (currentUser?.id != widget.post['user_id']) {
                      return [
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
                      ];
                    } else {
                      return [
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ];
                    }
                  },
                  loading: () => <PopupMenuEntry<String>>[],
                  error: (_, __) => <PopupMenuEntry<String>>[],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateField) {
    try {
      if (dateField == null) return 'Unknown time';

      DateTime dateTime;
      if (dateField is String) {
        dateTime = DateTime.parse(dateField);
      } else if (dateField.runtimeType.toString().contains('Timestamp')) {
        // Handle Firestore Timestamp
        dateTime = dateField.toDate();
      } else {
        return 'Unknown time';
      }

      return timeago.format(dateTime);
    } catch (e) {
      return 'Unknown time';
    }
  }

  String _getUserInitial(String? username) {
    if (username == null || username.isEmpty) return 'U';
    return username.substring(0, 1).toUpperCase();
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

  Widget _buildLocationInfo(
      Map<String, dynamic> location, Map<String, dynamic> post) {
    // Prioritize location name over coordinates
    String locationText = 'Unknown location';

    if (post['location_name'] != null &&
        post['location_name'].toString().isNotEmpty) {
      locationText = post['location_name'].toString();
    } else if (location['lat'] != null && location['lng'] != null) {
      locationText =
          '${location['lat'].toStringAsFixed(4)}, ${location['lng'].toStringAsFixed(4)}';
    }

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _navigateToGymProfile(context, post, location),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.red[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationText,
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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

  void _toggleLike() async {
    final postId = widget.post['id'];
    if (postId == null) return;

    try {
      final currentUser = await ref.read(authStateProvider.future);
      if (currentUser?.uid == null) {
        return;
      }

      // Use Firebase service to toggle like
      // StreamProviders will automatically update when data changes
      final postService = ref.read(firestorePostServiceProvider);
      await postService.toggleLike(postId, currentUser!.uid);
    } catch (e) {
      // Optionally show error to user
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: widget.post['id'],
        postOwnerId: widget.post['user_id'],
      ),
    );
  }

  void _showLikes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LikesBottomSheet(
        postId: widget.post['id'],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'report':
        _showReportDialog(context);
        break;
      case 'hide':
        // Hide post logic
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post hidden')),
        );
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
    }
  }

  void _showReportDialog(BuildContext context) {
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
              // Report logic here
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

  void _showDeleteDialog(BuildContext context) {
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
              await _deletePost(context);
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

  Future<void> _deletePost(BuildContext context) async {
    final postId = widget.post['id'];
    print('DEBUG DELETE: Post ID = $postId');
    print('DEBUG DELETE: Full post data = ${widget.post}');

    if (postId == null) {
      print('DEBUG DELETE: Post ID is null!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Post ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading snackbar
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
        duration: Duration(
            milliseconds: 100), // Long duration, will be dismissed manually
      ),
    );

    try {
      print('DEBUG DELETE: Getting current user...');
      final currentUser = await ref.read(authStateProvider.future);
      print('DEBUG DELETE: Current user ID = ${currentUser?.uid}');

      if (currentUser?.uid == null) {
        throw Exception('User not authenticated');
      }

      // Delete post using Firebase service
      print('DEBUG DELETE: Calling deletePost service...');
      final postService = ref.read(firestorePostServiceProvider);
      await postService.deletePost(postId);
      print('DEBUG DELETE: Delete service completed successfully');

      // Refresh all post-related providers
      print('DEBUG DELETE: Invalidating providers...');
      ref.invalidate(friendsPostsProvider);
      ref.invalidate(postsProvider);
      ref.invalidate(userPostsProvider(currentUser!.uid));
      ref.invalidate(currentUserPostsCountProvider);

      // Refresh gym-specific providers by incrementing the refresh counter
      final refreshNotifier = ref.read(gymDataRefreshProvider.notifier);
      refreshNotifier.state = refreshNotifier.state + 1;
      print('DEBUG DELETE: Providers invalidated');

      // Dismiss loading snackbar and show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('DEBUG DELETE ERROR: $e');
      print('DEBUG DELETE STACK TRACE: $stackTrace');

      // Dismiss loading snackbar and show error
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
}

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isCommentEmpty = true;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
      _commentController.clear(); // Clear immediately for better UX

      // Reset comment empty state
      setState(() {
        _isCommentEmpty = true;
      });

      final postService = ref.read(firestorePostServiceProvider);
      await postService.addComment(
        widget.postId,
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

  Widget _buildCommentItem(
    Map<String, dynamic> comment,
    Map<String, dynamic> user,
    int likesCount,
    bool isLiked,
    dynamic currentUser,
  ) {
    final isCurrentUserComment = currentUser?.id == comment['user_id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.orange,
            backgroundImage: (user['profile_photo'] != null &&
                    user['profile_photo'].toString().isNotEmpty)
                ? CachedNetworkImageProvider(user['profile_photo'])
                : null,
            child: (user['profile_photo'] == null ||
                    user['profile_photo'].toString().isEmpty)
                ? Text(
                    (user['username'] != null &&
                            user['username'].toString().isNotEmpty)
                        ? user['username']
                            .toString()
                            .substring(0, 1)
                            .toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            (user['username'] != null &&
                                    user['username'].toString().isNotEmpty)
                                ? user['username'].toString()
                                : 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCommentDate(comment['created_at']),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment['comment']?.toString() ?? 'No comment text',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (currentUser != null &&
                        (isCurrentUserComment || _isPostOwner(currentUser)))
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        onSelected: (value) => _handleCommentAction(
                          value,
                          comment['id'],
                          isCurrentUserComment,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: currentUser != null
                              ? () => _toggleCommentLike(comment['id'])
                              : null,
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isLiked ? Colors.red : Colors.grey[600],
                          ),
                        ),
                        if (likesCount > 0) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                _showCommentLikes(context, comment['id']),
                            child: Text(
                              likesCount.toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentDate(dynamic dateField) {
    try {
      if (dateField == null) return 'now';

      DateTime dateTime;
      if (dateField is String) {
        dateTime = DateTime.parse(dateField);
      } else if (dateField.runtimeType.toString().contains('Timestamp')) {
        // Handle Firestore Timestamp
        dateTime = dateField.toDate();
      } else {
        return 'now';
      }

      return timeago.format(dateTime);
    } catch (e) {
      return 'now';
    }
  }

  Widget _buildCommentItemWithRealTimeLikes(
    Map<String, dynamic> comment,
    Map<String, dynamic> user,
    dynamic currentUser,
  ) {
    final commentId = comment['id'];

    // Watch like count and like status just like post system
    final likesCount = ref.watch(commentLikesCountProvider(commentId));
    final isLiked = ref.watch(commentLikeProvider(commentId.toString()));

    return likesCount.when(
      data: (count) => isLiked.when(
        data: (liked) => _buildCommentItem(
          comment,
          user,
          count,
          liked,
          currentUser,
        ),
        loading: () => _buildCommentItem(
          comment,
          user,
          count,
          false,
          currentUser,
        ),
        error: (_, __) => _buildCommentItem(
          comment,
          user,
          count,
          false,
          currentUser,
        ),
      ),
      loading: () => _buildCommentItem(
        comment,
        user,
        0,
        false,
        currentUser,
      ),
      error: (_, __) => _buildCommentItem(
        comment,
        user,
        0,
        false,
        currentUser,
      ),
    );
  }

  bool _isPostOwner(dynamic currentUser) {
    return currentUser?.id == widget.postOwnerId;
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        return;
      }

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

  void _showCommentLikes(BuildContext context, String commentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentLikesBottomSheet(
        commentId: commentId,
      ),
    );
  }

  Future<void> _handleCommentAction(
      String action, String commentId, bool isCurrentUserComment) async {
    if (action == 'delete') {
      try {
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser?.id == null) return;

        final postService = ref.read(firestorePostServiceProvider);

        if (isCurrentUserComment) {
          // User deleting their own comment
          await postService.deleteComment(commentId, currentUser!.id);
        } else if (_isPostOwner(currentUser)) {
          // Post owner deleting someone else's comment
          await postService.deleteCommentByPostOwner(
              commentId, currentUser!.id);
        } else {
          throw Exception('You do not have permission to delete this comment');
        }

        // StreamProviders will automatically update when data changes
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

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.postId));
    final currentUserAsync = ref.watch(currentUserProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Comments list
          Expanded(
            child: comments.when(
              data: (commentsList) {
                if (commentsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet\nBe the first to comment!',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: commentsList.length,
                  itemBuilder: (context, index) {
                    final comment = commentsList[index];
                    final user = comment['users'] ?? {};

                    return currentUserAsync.when(
                      data: (currentUser) => _buildCommentItemWithRealTimeLikes(
                        comment,
                        user,
                        currentUser,
                      ),
                      loading: () =>
                          _buildCommentItem(comment, user, 0, false, null),
                      error: (_, __) =>
                          _buildCommentItem(comment, user, 0, false, null),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                return Center(
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
                        'Error loading comments',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.red[400],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(postCommentsProvider(widget.postId));
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
                );
              },
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isCommentEmpty ? null : () => _addComment(),
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
}

class CommentLikesBottomSheet extends ConsumerWidget {
  final String commentId;

  const CommentLikesBottomSheet({
    super.key,
    required this.commentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentLikes = ref.watch(commentLikesProvider(commentId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Likes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Likes list
          Expanded(
            child: commentLikes.when(
              data: (likesList) {
                if (likesList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No likes yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: likesList.length,
                  itemBuilder: (context, index) {
                    final like = likesList[index];
                    final user = like['users'] ?? {};

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.orange,
                        backgroundImage: (user['profile_photo'] != null &&
                                user['profile_photo'].toString().isNotEmpty)
                            ? CachedNetworkImageProvider(user['profile_photo'])
                            : null,
                        child: (user['profile_photo'] == null ||
                                user['profile_photo'].toString().isEmpty)
                            ? Text(
                                (user['username'] != null &&
                                        user['username'].toString().isNotEmpty)
                                    ? user['username']
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user['username'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: user['bio'] != null &&
                              user['bio'].toString().isNotEmpty
                          ? Text(
                              user['bio'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: user['id'],
                              username: user['username'] ?? 'Unknown User',
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                return Center(
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
                        'Error loading likes',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(commentLikesProvider(commentId));
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
