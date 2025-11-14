import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/gym_model.dart';
import '../../providers/providers.dart';
import '../../widgets/post_card.dart';

class GymProfileScreen extends ConsumerStatefulWidget {
  final String gymId; // This could be placeId or gym name
  final String? gymName; // Optional, for display while loading
  final String? placeId; // Optional, if we have the place ID directly
  final double? lat; // Optional, for location-based search
  final double? lng; // Optional, for location-based search

  const GymProfileScreen({
    super.key,
    required this.gymId,
    this.gymName,
    this.placeId,
    this.lat,
    this.lng,
  });

  @override
  ConsumerState<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends ConsumerState<GymProfileScreen> {
  PageController? _pageController;
  int _currentPhotoIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decide which provider to use based on available data
    final AsyncValue<Gym?> gymAsync =
        widget.placeId != null && widget.placeId!.isNotEmpty
            ? ref.watch(gymDetailsProvider(widget.placeId!))
            : ref.watch(gymByNameProvider(GymSearchParams(
                name: widget.gymId,
                lat: widget.lat,
                lng: widget.lng,
              )));

    return Scaffold(
      body: gymAsync.when(
        loading: () => _buildLoadingScreen(),
        error: (error, stackTrace) => _buildErrorScreen(error),
        data: (gym) {
          if (gym == null) {
            return _buildNotFoundScreen();
          }
          return _buildGymProfile(gym);
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gymName ?? 'Loading...'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading gym information...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(dynamic error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load gym information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Refresh the data
                if (widget.placeId != null) {
                  ref.invalidate(gymDetailsProvider(widget.placeId!));
                } else {
                  ref.invalidate(gymByNameProvider(GymSearchParams(
                    name: widget.gymId,
                    lat: widget.lat,
                    lng: widget.lng,
                  )));
                }
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
    );
  }

  Widget _buildNotFoundScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Not Found'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gym not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not find information for "${widget.gymName ?? widget.gymId}"',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymProfile(Gym gym) {
    // Use gym name for posts and stats, not gym.id (which is place_id)
    final gymName = widget.gymName ?? gym.name;

    // Listen to refresh trigger
    ref.listen<int>(gymDataRefreshProvider, (previous, next) {
      if (previous != next) {
        // Force refresh when counter changes
        ref.invalidate(gymPostsProvider(gymName));
        ref.invalidate(gymStatsProvider(gymName));
      }
    });

    final posts = ref.watch(gymPostsProvider(gymName));
    final stats = ref.watch(gymStatsProvider(gymName));

    return Scaffold(
      body: NestedScrollView(
        physics: const ClampingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              floating: false,
              pinned: true,
              snap: false,
              stretch: false,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: innerBoxIsScrolled ? 1 : 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  gym.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                background: _buildGymCover(gym),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Gym info header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gym basic info
                  _buildGymInfo(gym),

                  const SizedBox(height: 16),

                  // Stats row
                  stats.when(
                    data: (statsData) => _buildStatsRow(statsData),
                    loading: () => _buildStatsRowLoading(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  _buildActionButtons(gym),
                ],
              ),
            ),

            // Posts section
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Refresh gym data
                  ref.invalidate(gymPostsProvider(gymName));
                  ref.invalidate(gymStatsProvider(gymName));

                  // Trigger refresh counter
                  final refreshNotifier =
                      ref.read(gymDataRefreshProvider.notifier);
                  refreshNotifier.state = refreshNotifier.state + 1;

                  // Wait a moment for the refresh
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: _buildPostsTab(posts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCover(Gym gym) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background images with PageView and gesture detection
        if (gym.photos != null && gym.photos!.isNotEmpty)
          GestureDetector(
            onTap: () {
              // Tap on right side = next photo, left side = previous photo
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                if (!_isDisposed && mounted) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                }
              },
              itemCount: gym.photos!.length,
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: gym.photos![index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultGymCover(),
                );
              },
            ),
          )
        else
          _buildDefaultGymCover(),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),

        // Photo navigation buttons
        if (gym.photos != null && gym.photos!.length > 1) ...[
          // Previous button
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _previousPhoto,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          // Next button
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _nextPhoto,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],

        // Photo indicator dots
        if (gym.photos != null && gym.photos!.length > 1)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                gym.photos!.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultGymCover() {
    return Container(
      color: Colors.orange,
      child: const Icon(
        Icons.fitness_center,
        size: 100,
        color: Colors.white,
      ),
    );
  }

  Widget _buildGymInfo(Gym gym) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating and status
        Row(
          children: [
            if (gym.rating != null) ...[
              Icon(Icons.star, color: Colors.amber[600], size: 20),
              const SizedBox(width: 4),
              Text(
                gym.displayRating,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: gym.statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                gym.displayStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (gym.priceLevel != null) ...[
              const Spacer(),
              Text(
                gym.displayPriceLevel,
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),

        // Address
        if (gym.address != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[600], size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  gym.address!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Description
        if (gym.description != null) ...[
          const SizedBox(height: 8),
          Text(
            gym.description!,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Posts', stats['posts_count'] ?? 0),
        Container(width: 1, height: 20, color: Colors.grey[300]),
        _buildStatItem('This Week', stats['this_week_posts'] ?? 0),
      ],
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRowLoading() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Posts', 0),
        Container(width: 1, height: 20, color: Colors.grey[300]),
        _buildStatItem('This Week', 0),
      ],
    );
  }

  Widget _buildActionButtons(Gym gym) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openInMaps(gym),
            icon: const Icon(Icons.map, size: 18),
            label: const Text('More Info'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab(AsyncValue<List<Map<String, dynamic>>> postsAsync) {
    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading posts',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to post from this gym!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(post: posts[index]);
          },
        );
      },
    );
  }

  void _previousPhoto() {
    if (!_isDisposed &&
        mounted &&
        _pageController != null &&
        _pageController!.hasClients) {
      final currentPage = _currentPhotoIndex;
      final totalPages = _getCurrentGym()?.photos?.length ?? 0;

      if (totalPages > 0) {
        final newPage = currentPage > 0 ? currentPage - 1 : totalPages - 1;
        _pageController!.animateToPage(
          newPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _nextPhoto() {
    if (!_isDisposed &&
        mounted &&
        _pageController != null &&
        _pageController!.hasClients) {
      final currentPage = _currentPhotoIndex;
      final totalPages = _getCurrentGym()?.photos?.length ?? 0;

      if (totalPages > 0) {
        final newPage = (currentPage + 1) % totalPages;
        _pageController!.animateToPage(
          newPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Gym? _getCurrentGym() {
    final AsyncValue<Gym?> gymAsync = widget.placeId != null
        ? ref.read(gymDetailsProvider(widget.placeId!))
        : ref.read(gymByNameProvider(GymSearchParams(
            name: widget.gymId,
            lat: widget.lat,
            lng: widget.lng,
          )));

    return gymAsync.value;
  }

  void _openInMaps(Gym gym) async {
    String url;

    if (gym.location != null) {
      final lat = gym.location!['lat'];
      final lng = gym.location!['lng'];
      // Open gym location in Google Maps with place details
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      // Fallback to search by name
      final encodedName = Uri.encodeComponent(gym.name);
      url = 'https://www.google.com/maps/search/?api=1&query=$encodedName';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
