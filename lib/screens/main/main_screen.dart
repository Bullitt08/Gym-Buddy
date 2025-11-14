import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/providers.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'create_post_screen.dart';
import 'friends_screen.dart';
import 'my_profile_screen.dart';
import '../chat/chat_list_screen.dart';
import 'notifications_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const CreatePostScreen(),
    const FriendsScreen(),
    const MyProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Check if token has been saved
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFCMTokenExists();
    });
  }

  Future<void> _ensureFCMTokenExists() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check if token exists in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(currentUser.uid)
          .get();

      if (!doc.exists ||
          doc.data()?['tokens'] == null ||
          (doc.data()?['tokens'] as List).isEmpty) {
        // Token doesn't exist, save it
        print('FCM token not found, saving now...');
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.saveUserFCMToken(currentUser.uid);
        print('FCM token saved successfully');
      } else {
        print('FCM token already exists for user: ${currentUser.uid}');
      }
    } catch (e) {
      print('Error checking FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationProvider);

    // Listen to auth state changes and navigate to login if user is null
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user == null) {
            // User signed out, reset navigation and navigate to login
            ref.read(navigationProvider.notifier).resetToHome();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            });
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    return Scaffold(
      appBar: _buildAppBar(navigationState),
      body: _buildCurrentScreen(navigationState),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getNavigationIndex(navigationState),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          ref.read(navigationProvider.notifier).setIndex(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }

  int _getNavigationIndex(NavigationState navigationState) {
    switch (navigationState) {
      case NavigationState.home:
        return 0;
      case NavigationState.map:
        return 1;
      case NavigationState.createPost:
        return 2;
      case NavigationState.friends:
        return 3;
      case NavigationState.profile:
        return 4;
    }
  }

  Widget _buildCurrentScreen(NavigationState navigationState) {
    int index = 0;
    switch (navigationState) {
      case NavigationState.home:
        index = 0;
        break;
      case NavigationState.map:
        index = 1;
        break;
      case NavigationState.createPost:
        index = 2;
        break;
      case NavigationState.friends:
        index = 3;
        break;
      case NavigationState.profile:
        index = 4;
        break;
    }

    if (index < _screens.length) {
      return IndexedStack(
        index: index,
        children: _screens,
      );
    }

    // Fallback to home
    return _screens[0];
  }

  PreferredSizeWidget _buildAppBar(NavigationState navigationState) {
    if (navigationState == NavigationState.profile) {
      // Different AppBar for User Profile screen
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'GymBuddy',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showProfileMenu(context),
          ),
        ],
      );
    }

    // Normal AppBar for other screens
    final currentUser = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadMessagesCountProvider);
    final unreadNotificationsCount =
        ref.watch(unreadNotificationsCountProvider);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'GymBuddy',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Notification and Message buttons and profile photo
        Row(
          children: [
            // Notification button
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                // Unread notification count badge
                unreadNotificationsCount.when(
                  data: (count) => count > 0
                      ? Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            // Message button
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChatListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                // Unread message count badge
                unreadCount.when(
                  data: (count) => count > 0
                      ? Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            // Profile Photo
            GestureDetector(
              onTap: () {
                // Navigate to profile screen - change navbar to My Profile using navigation provider
                ref.read(navigationProvider.notifier).goToProfile();
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange,
                child: currentUser.when(
                  data: (user) => user?.profilePhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            user!.profilePhoto!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                  loading: () => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                  error: (_, __) => const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showProfileMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Profile Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Check FCM Token'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _checkFCMToken();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                // TODO: Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _handleSignOut();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _checkFCMToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Check token from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();
        final tokens = data?['tokens'] as List?;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ FCM Token Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User ID: ${currentUser.uid}'),
                const SizedBox(height: 8),
                Text('Token Count: ${tokens?.length ?? 0}'),
                const SizedBox(height: 8),
                if (tokens != null && tokens.isNotEmpty)
                  Text(
                    'Token: ${tokens.first.toString().substring(0, 50)}...',
                    style: const TextStyle(fontSize: 10),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Token doesn't exist, save it now
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ No FCM Token'),
            content: const Text(
              'FCM token not found in Firestore. Saving now...',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  // Save token
                  final notificationService =
                      ref.read(notificationServiceProvider);
                  await notificationService.saveUserFCMToken(currentUser.uid);

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FCM token saved! Check again.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Save Token'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSignOut() async {
    if (!mounted) return;

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final currentUser = ref.read(authStateProvider).value;

      // Remove FCM token
      if (currentUser != null) {
        try {
          final notificationService = ref.read(notificationServiceProvider);
          await notificationService.removeUserFCMToken(currentUser.uid);
        } catch (e) {
          print('Error removing FCM token: $e');
        }
      }

      // Clear all providers first - this will trigger UI changes
      ref.invalidate(currentUserProvider);
      ref.invalidate(authStateProvider);

      // Reset navigation to home - this might change the current screen
      ref.read(navigationProvider.notifier).resetToHome();

      // Sign out - this is the actual logout
      await authService.signOut();

      // No need to show loading or close dialogs since navigation will handle UI changes
    } catch (e) {
      // Only show error if still mounted and sign out actually failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
