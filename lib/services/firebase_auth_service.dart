import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        return UserModel(
          id: result.user!.uid,
          email: result.user!.email ?? '',
          username: result.user!.email?.split('@')[0] ?? '',
          profilePhoto: result.user!.photoURL,
          streak: 0,
          friends: [],
          createdAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error occurred while signing in: $e');
    }
  }

  // Sign up with email and password
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      // Firebase Auth registration with proper error handling
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        try {
          // Update display name with the username (not fullName) for profile creation
          await Future.delayed(const Duration(milliseconds: 500));
          await result.user!
              .updateDisplayName(username); // Use username instead of fullName
          await result.user!.reload();
          print('DEBUG: Updated Firebase displayName to: $username');
        } catch (profileUpdateError) {
          // Profile update failed but user is created - this is acceptable
          print(
              'Profile update failed but user registration successful: $profileUpdateError');
        }

        return UserModel(
          id: result.user!.uid,
          email: result.user!.email ?? '',
          username: username, // Save username as is original form
          profilePhoto: result.user!.photoURL,
          streak: 0,
          friends: [],
          createdAt: DateTime.now(),
        );
      }
      return null;
    } on FirebaseAuthException catch (firebaseError) {
      // Handle specific Firebase Auth errors
      String errorMessage = 'Registration failed';
      switch (firebaseError.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid';
          break;
        default:
          errorMessage = firebaseError.message ?? 'An unknown error occurred';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle type cast and other errors gracefully
      print('Auth service error (non-critical if registration succeeds): $e');

      // Wait a bit for potential async completion
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check if user was actually created despite the error
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email == email.trim()) {
        // User was created successfully, return UserModel
        print('Registration successful despite PigeonUserDetails error');
        return UserModel(
          id: currentUser.uid,
          email: currentUser.email ?? '',
          username: username, // Save username as is original form
          profilePhoto: currentUser.photoURL,
          streak: 0,
          friends: [],
          createdAt: DateTime.now(),
        );
      }

      // If error is related to PigeonUserDetails, provide specific message
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        throw Exception(
            'Registration completed but with a minor system error. Please try logging in.');
      }

      throw Exception('Registration failed: Please try again');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error occurred while signing out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw Exception('Error occurred while sending password reset email: $e');
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }
        await user.reload();
      }
    } catch (e) {
      throw Exception('Error occurred while updating profile: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      throw Exception('Error occurred while deleting account: $e');
    }
  }
}

// Provider
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});
