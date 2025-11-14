import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/friends_list_modal.dart';
import 'post_detail_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final postsCount = ref.watch(currentUserPostsCountProvider);
    final friendsCount = ref.watch(currentUserFriendsCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all user-related data
          ref.invalidate(currentUserProvider);
          ref.invalidate(currentUserPostsCountProvider);
          ref.invalidate(currentUserFriendsCountProvider);
          ref.invalidate(friendsPostsProvider);
          if (currentUser.value?.id != null) {
            ref.invalidate(userPostsProvider(currentUser.value!.id));
            ref.invalidate(userFriendsListProvider(currentUser.value!.id));
          }

          // Wait a bit for providers to refresh
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Main Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                  ),
                  child: currentUser.when(
                    data: (user) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side - Profile Photo
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      Colors.orange.withValues(alpha: 0.2),
                                  backgroundImage: user?.profilePhoto != null &&
                                          user!.profilePhoto!.isNotEmpty
                                      ? NetworkImage(user.profilePhoto!)
                                      : null,
                                  child: user?.profilePhoto == null ||
                                          user!.profilePhoto!.isEmpty
                                      ? Text(
                                          user?.username != null &&
                                                  user!.username.isNotEmpty
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
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showPhotoOptions(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Right side - User info and stats
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Username
                                  Text(
                                    user?.username ?? 'No Username',
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
                                      _buildCompactStat(postsCount, 'Posts'),
                                      const SizedBox(width: 40),
                                      _buildCompactStat(friendsCount, 'Friends',
                                          onTap: () =>
                                              _showFriendsModal(context)),
                                      const SizedBox(width: 40),
                                      _buildCompactStat(
                                          AsyncValue.data(0), 'Streak'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Bio below profile photo
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showBioEditDialog(context, user?.bio),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              user?.bio?.isNotEmpty == true
                                  ? user!.bio!
                                  : 'No bio added yet. Tap to add one!',
                              style: TextStyle(
                                fontSize: 15,
                                color: user?.bio?.isNotEmpty == true
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontStyle: user?.bio?.isNotEmpty == true
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Loading profile...'),
                      ],
                    ),
                    error: (error, _) => Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('Error: $error'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // My Posts Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // User Posts List
                      currentUser.when(
                        data: (user) {
                          if (user?.id == null) {
                            return const Center(
                              child: Text('Please sign in to view your posts'),
                            );
                          }

                          final userPosts =
                              ref.watch(userPostsProvider(user!.id));

                          return userPosts.when(
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
                                          'Share your first workout moment!',
                                          style: TextStyle(
                                            color: Colors.grey,
                                          ),
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
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => const Center(
                          child: Text('Error loading user data'),
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
      ),
    );
  }

  Widget _buildCompactStat(AsyncValue<int> asyncValue, String label,
      {VoidCallback? onTap}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        asyncValue.when(
          data: (count) => Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () => const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
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

  void _showPhotoOptions(BuildContext context) {
    final user = ref.read(currentUserProvider).value;
    final hasProfilePhoto =
        user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profile Photo Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _updateProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _updateProfilePhoto(ImageSource.gallery);
              },
            ),
            if (hasProfilePhoto) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfilePhoto();
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfilePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image == null) return;

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
                SizedBox(width: 16),
                Text('Uploading profile photo...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 30), // Long duration for upload
          ),
        );
      }

      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        throw Exception('User not logged in');
      }

      // Upload to Firebase Storage
      final storageService = ref.read(firebaseStorageServiceProvider);
      final imageFile = File(image.path);
      final downloadUrl = await storageService.uploadProfileImage(
        currentUser!.id,
        imageFile,
      );

      // Update user profile in Firestore
      final userService = ref.read(firebaseUserServiceProvider);
      await userService.updateUserProfile(currentUser.id, {
        'profile_photo': downloadUrl,
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfilePhoto() async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        throw Exception('User not logged in');
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Profile Photo'),
          content:
              const Text('Are you sure you want to remove your profile photo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
                SizedBox(width: 16),
                Text('Removing profile photo...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Delete from Firebase Storage
      final storageService = ref.read(firebaseStorageServiceProvider);
      await storageService.deleteProfileImage(currentUser!.id);

      // Update user profile in Firestore (remove photo URL)
      final userService = ref.read(firebaseUserServiceProvider);
      await userService.updateUserProfile(currentUser.id, {
        'profile_photo': null,
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBioEditDialog(
      BuildContext context, String? currentBio) async {
    final TextEditingController bioController =
        TextEditingController(text: currentBio ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 150,
              decoration: const InputDecoration(
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(),
              ),
            ),
            if (currentBio?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'REMOVE'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Remove Bio',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, bioController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result == 'REMOVE') {
      await _removeBio();
    } else {
      await _updateBio(result);
    }
  }

  Future<void> _updateBio(String newBio) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        throw Exception('User not logged in');
      }

      final userService = ref.read(firebaseUserServiceProvider);
      await userService.updateUserProfile(currentUser!.id, {
        'bio': newBio.trim(),
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update bio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeBio() async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser?.id == null) {
        throw Exception('User not logged in');
      }

      final userService = ref.read(firebaseUserServiceProvider);
      await userService.updateUserProfile(currentUser!.id, {
        'bio': '',
      });

      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bio removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove bio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFriendsModal(BuildContext context) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser?.id == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Consumer(
        builder: (context, ref, child) {
          final friendsAsync =
              ref.watch(userFriendsListProvider(currentUser!.id));

          return FriendsListModal(
            userId: currentUser.id,
            userName: currentUser.username,
            friends: friendsAsync.asData?.value ?? [],
            isLoading: friendsAsync.isLoading,
            error: friendsAsync.hasError ? friendsAsync.error.toString() : null,
          );
        },
      ),
    );
  }
}
