import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/user_model.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  void _onUsernameChanged(String value) async {
    if (value.length < 3) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    final userService = ref.read(firebaseUserServiceProvider);

    // Format control
    if (!userService.isValidUsernameFormat(value)) {
      setState(() {
        _usernameError =
            'Invalid format. Use 3-20 chars, letters, numbers, underscore';
        _isCheckingUsername = false;
      });
      return;
    }

    // Availability contorol (Firebase Security Rules configured)
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final isAvailable = await userService.isUsernameAvailable(value);
      print('DEBUG UI: Username "$value" check result: $isAvailable');

      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError = isAvailable ? null : 'Username is already taken';
        });
      }
    } catch (e) {
      print('DEBUG UI: Error in username check: $e');
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError =
              'Unable to check availability - Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                    errorText: _usernameError,
                    suffixIcon: _isCheckingUsername
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_usernameError == null &&
                                _usernameController.text.length >= 3)
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                  ),
                  onChanged: _onUsernameChanged,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username is required';
                    }

                    final userService = ref.read(firebaseUserServiceProvider);
                    if (!userService.isValidUsernameFormat(value)) {
                      return 'Invalid format. Use 3-20 chars, letters, numbers, underscore';
                    }

                    if (_usernameError != null) {
                      return _usernameError;
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    UserModel? userModel;
    bool registrationSuccessful = false;

    try {
      // Username availability control (Firebase Security Rules configured)
      final username = _usernameController.text.trim();
      final userService = ref.read(firebaseUserServiceProvider);

      print('DEBUG SIGNUP: Starting registration for username: $username');

      final isUsernameAvailable =
          await userService.isUsernameAvailable(username);

      print(
          'DEBUG SIGNUP: Username availability check result: $isUsernameAvailable');

      if (!isUsernameAvailable) {
        print('DEBUG SIGNUP: Username not available, blocking registration');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Username "$username" is already taken. Please choose another one.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('DEBUG SIGNUP: Username available, proceeding with registration');

      final authService = ref.read(firebaseAuthServiceProvider);
      userModel = await authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: username, // Use username as fullName
        username: username,
      );

      registrationSuccessful = userModel != null;

      // Create user profile in Firestore BEFORE signing out
      if (userModel != null) {
        try {
          final userService = ref.read(firebaseUserServiceProvider);

          // Create user profile directly - no final check needed since we already verified
          print('DEBUG SIGNUP: Creating user profile in Firestore');
          await userService.createUserProfile(userModel);
          print(
              'DEBUG: User profile saved to Firestore with username: ${userModel.username}');
        } catch (firestoreError) {
          print('DEBUG: Firestore profile creation error: $firestoreError');

          // Delete the user from Firebase Auth because profile creation failed
          try {
            await FirebaseAuth.instance.currentUser?.delete();
            print('DEBUG: Deleted auth user due to profile creation failure');
          } catch (deleteError) {
            print('DEBUG: Failed to delete auth user: $deleteError');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Profile creation failed. Please try registration again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (mounted && registrationSuccessful) {
        // Sign out user after registration so they need to login
        // But first make sure the profile is saved
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          final authService = ref.read(firebaseAuthServiceProvider);
          await authService.signOut();
        } catch (signOutError) {
          print('Sign out after registration error: $signOutError');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Registration successful! Please login with your credentials.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Go back to login screen with success indicator
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        // Clean error message
        String errorMessage = error.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
