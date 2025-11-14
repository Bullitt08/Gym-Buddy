import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'utils/firestore_init.dart';
import 'services/notification_service.dart';
import 'utils/notification_handler.dart';

// Top-level function for background FCM handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('DEBUG: Firebase initialized successfully');

    // Initialize FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initializeLocalNotifications();
    notificationService.setupFCMListeners();
    await notificationService.handleInitialMessage();
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymBuddy - Firebase Edition',
      navigatorKey: NotificationHandler.navigatorKey, // Global navigator key
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // Normal uygulama geri döndü
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // If user logged in, initialize Firestore
          Future.microtask(() => FirestoreInitHelper.initializeCollections());

          // Save FCM token
          Future.microtask(() async {
            try {
              final notificationService = ref.read(notificationServiceProvider);
              await notificationService.saveUserFCMToken(user.uid);
            } catch (e) {
              print('Error saving FCM token: $e');
            }
          });

          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Scaffold(
        body: Center(child: Text('Authentication Error')),
      ),
    );
  }
}
