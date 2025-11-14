import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:typed_data';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload profile image
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to upload profile image');
      }

      // Verify the userId matches the authenticated user
      if (currentUser.uid != userId) {
        throw Exception(
            'Unauthorized: Cannot upload profile image for another user');
      }

      // Get file extension from the original file
      final fileName = imageFile.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      final supportedFormats = ['jpg', 'jpeg', 'png', 'webp'];

      if (!supportedFormats.contains(extension)) {
        throw Exception('Unsupported image format: $extension');
      }

      final ref = _storage
          .ref()
          .child('profile_photos')
          .child(userId)
          .child('profile.$extension');

      // Determine content type based on extension
      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error occurred while uploading profile image: $e');
    }
  }

  // Upload post image
  Future<String> uploadPostImage(String postId, File imageFile) async {
    try {
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      print('DEBUG: Firebase Storage - Current user: ${currentUser?.uid}');
      print('DEBUG: Firebase Storage - User email: ${currentUser?.email}');

      if (currentUser == null) {
        throw Exception('User must be authenticated to upload post image');
      }

      // Get file info
      final fileExists = await imageFile.exists();
      print('DEBUG: Firebase Storage - File exists: $fileExists');

      if (!fileExists) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      print('DEBUG: Firebase Storage - File size: $fileSize bytes');

      // Create storage reference - rules'a uygun olarak userId klasörü içinde
      final ref = _storage
          .ref()
          .child('post_images')
          .child(currentUser.uid)
          .child('$postId.jpg');
      print(
          'DEBUG: Firebase Storage - Storage path: post_images/${currentUser.uid}/$postId.jpg');

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'postId': postId,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );

      print('DEBUG: Firebase Storage - Starting upload...');
      final uploadTask = await ref.putFile(imageFile, metadata);
      print('DEBUG: Firebase Storage - Upload task completed');

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('DEBUG: Firebase Storage - Download URL obtained: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('DEBUG: Post image upload error: $e');
      print('DEBUG: Error type: ${e.runtimeType}');

      // Re-throw with more specific error information
      if (e.toString().contains('firebase_storage')) {
        rethrow; // Keep the original Firebase error
      } else {
        throw Exception('Error occurred while uploading post image: $e');
      }
    }
  }

  // Upload post video
  Future<String> uploadPostVideo(String postId, File videoFile) async {
    try {
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to upload post video');
      }

      final ref = _storage
          .ref()
          .child('post_images')
          .child(currentUser.uid)
          .child('$postId.mp4');

      final uploadTask = await ref.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('DEBUG: Post video upload error: $e');
      throw Exception('Error occurred while uploading post video: $e');
    }
  }

  // Upload from bytes (for web)
  Future<String> uploadFromBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);

      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error occurred while uploading file: $e');
    }
  }

  // Delete profile image
  Future<void> deleteProfileImage(String userId) async {
    try {
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to delete profile image');
      }

      // Verify the userId matches the authenticated user
      if (currentUser.uid != userId) {
        throw Exception(
            'Unauthorized: Cannot delete profile image for another user');
      }

      // Try to delete common image formats
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];

      for (final extension in extensions) {
        try {
          final ref = _storage
              .ref()
              .child('profile_photos')
              .child(userId)
              .child('profile.$extension');
          await ref.delete();
          print('DEBUG: Deleted profile image: $userId.$extension');
          break; // If successful, exit the loop
        } catch (e) {
          // Continue to next extension if this one doesn't exist
          continue;
        }
      }
    } catch (e) {
      throw Exception('Error occurred while deleting profile image: $e');
    }
  }

  // Delete post image/video
  Future<void> deletePostImage(String postId) async {
    try {
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to delete post media');
      }

      // Try to delete both image and video formats
      final imageFormats = ['jpg', 'jpeg', 'png', 'webp'];
      final videoFormats = ['mp4', 'mov', 'avi'];

      bool deleted = false;

      // Try deleting image formats
      for (final extension in imageFormats) {
        try {
          final ref = _storage
              .ref()
              .child('post_images')
              .child(currentUser.uid)
              .child('$postId.$extension');
          await ref.delete();
          print('DEBUG: Deleted post image: $postId.$extension');
          deleted = true;
          break;
        } catch (e) {
          // Continue to next format if this one doesn't exist
          continue;
        }
      }

      // If no image found, try video formats
      if (!deleted) {
        for (final extension in videoFormats) {
          try {
            final ref = _storage
                .ref()
                .child('post_images')
                .child(currentUser.uid)
                .child('$postId.$extension');
            await ref.delete();
            print('DEBUG: Deleted post video: $postId.$extension');
            deleted = true;
            break;
          } catch (e) {
            // Continue to next format if this one doesn't exist
            continue;
          }
        }
      }

      if (!deleted) {
        print('DEBUG: No media file found for post: $postId');
      }
    } catch (e) {
      print('DEBUG: Error deleting post media: $e');
      throw Exception('Error occurred while deleting post media: $e');
    }
  }

  // Delete file by URL
  Future<void> deleteFile(String downloadUrl) async {
    try {
      print('DEBUG: Deleting file from URL: $downloadUrl');
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('DEBUG: Successfully deleted file from storage');
    } catch (e) {
      print('DEBUG: Error deleting file by URL: $e');
      throw Exception('Error occurred while deleting file: $e');
    }
  }

  // Delete file by path
  Future<void> deleteFileByPath(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Error occurred while deleting file: $e');
    }
  }

  // Get download URL
  Future<String> getDownloadURL(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error occurred while getting download URL: $e');
    }
  }

  // Get file metadata
  Future<FullMetadata> getFileMetadata(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getMetadata();
    } catch (e) {
      throw Exception('Error occurred while getting file metadata: $e');
    }
  }

  // List files in directory
  Future<ListResult> listFiles(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.listAll();
    } catch (e) {
      throw Exception('Error occurred while listing files: $e');
    }
  }

  // Upload with progress tracking
  Stream<TaskSnapshot> uploadWithProgress(String path, File file) {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    return uploadTask.snapshotEvents;
  }

  // Compress and upload image
  Future<String> compressAndUploadImage({
    required String path,
    required File imageFile,
    int quality = 70,
  }) async {
    try {
      final ref = _storage.ref().child(path);

      // For now, just upload without compression
      // In a real app, you'd use image compression library
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Sıkıştırılmış resim yüklenirken hata oluştu: $e');
    }
  }
}

// Provider
final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});
