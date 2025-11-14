import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym_model.dart';
import '../config/api_keys.dart';

class GymService {
  // Google Places API Key from secure config
  static String get _placesApiKey => ApiKeys.googleMapsApiKey;

  /// Get detailed information about a gym by its Place ID
  Future<Gym?> getGymDetails(String placeId) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,formatted_phone_number,website,rating,opening_hours,photos,editorial_summary,price_level,geometry,place_id'
          '&key=$_placesApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['result'] != null) {
          return Gym.fromGooglePlaces(data['result']);
        } else {
          print('Places API error: ${data['status']}');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching gym details: $e');
      return null;
    }
  }

  /// Get gym details by name (search and get first result)
  Future<Gym?> getGymByName(String gymName, {double? lat, double? lng}) async {
    try {
      String url =
          'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
          '?input=${Uri.encodeComponent(gymName)}'
          '&inputtype=textquery'
          '&fields=place_id,name,formatted_address,rating,geometry'
          '&key=$_placesApiKey';

      // Add location bias if coordinates are provided
      if (lat != null && lng != null) {
        url += '&locationbias=point:$lat,$lng';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['candidates'] != null &&
            (data['candidates'] as List).isNotEmpty) {
          final firstCandidate = (data['candidates'] as List)[0];
          final placeId = firstCandidate['place_id'];

          // Get detailed information using the place ID
          return await getGymDetails(placeId);
        } else {
          print('No gym found with name: $gymName');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error searching gym by name: $e');
      return null;
    }
  }

  /// Search for gyms near a location
  Future<List<Gym>> searchNearbyGyms({
    required double lat,
    required double lng,
    int radius = 5000,
  }) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=$radius'
          '&type=gym'
          '&keyword=fitness|gym|spor|antrenman'
          '&key=$_placesApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List? ?? [];
          List<Gym> gyms = [];

          for (var gymData in results) {
            try {
              final gym = Gym.fromGooglePlaces(gymData);
              gyms.add(gym);
            } catch (e) {
              print('Error parsing gym data: $e');
              continue;
            }
          }

          return gyms;
        } else {
          print('Places API error: ${data['status']}');
          return [];
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching nearby gyms: $e');
      return [];
    }
  }

  /// Get posts tagged at a specific gym
  Future<List<Map<String, dynamic>>> getGymPosts(String gymName) async {
    try {
      print('DEBUG GymService: Fetching posts for gym: $gymName');

      final firestore = FirebaseFirestore.instance;

      // Query posts where location_name matches gym name (case insensitive)
      final querySnapshot = await firestore
          .collection('posts')
          .where('location_name', isEqualTo: gymName)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> gymPosts = [];

      for (var doc in querySnapshot.docs) {
        final postData = doc.data();
        postData['id'] = doc.id;

        // Fetch user data for the post
        try {
          final userDoc = await firestore
              .collection('users')
              .doc(postData['user_id'])
              .get();

          if (userDoc.exists) {
            postData['users'] = userDoc.data();
          }
        } catch (e) {
          print('Error fetching user for post ${doc.id}: $e');
        }

        gymPosts.add(postData);
      }

      print(
          'DEBUG GymService: Found ${gymPosts.length} posts for gym: $gymName');
      return gymPosts;
    } catch (e) {
      print('Error fetching gym posts: $e');
      return [];
    }
  }

  /// Get users who frequently visit this gym
  /// This would be implemented when you have Firestore integration
  Future<List<Map<String, dynamic>>> getGymMembers(String gymId) async {
    // TODO: Implement Firestore query for users who post at this gym
    // For now, return empty list
    return [];
  }

  /// Get gym statistics (posts count, members count, etc.)
  Future<Map<String, int>> getGymStats(String gymName) async {
    try {
      print('DEBUG GymService: Fetching stats for gym: $gymName');
      final firestore = FirebaseFirestore.instance;

      // First, let's see all posts and their location_name fields for debugging
      final allPostsQuery = await firestore.collection('posts').get();
      print(
          'DEBUG GymService: Total posts in database: ${allPostsQuery.docs.length}');
      for (var doc in allPostsQuery.docs.take(5)) {
        // Just first 5 for debug
        final data = doc.data();
        print(
            'DEBUG GymService: Post ${doc.id} - location_name: "${data['location_name']}"');
      }

      // Get total posts count
      final totalPostsQuery = await firestore
          .collection('posts')
          .where('location_name', isEqualTo: gymName)
          .get();

      final totalPosts = totalPostsQuery.docs.length;
      print('DEBUG GymService: Total posts found: $totalPosts');

      // Get posts from this week - temporarily use client-side filtering until Firebase index is ready
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      print(
          'DEBUG GymService: Checking posts since: ${oneWeekAgo.toIso8601String()}');

      // Client-side filtering for this week posts
      int thisWeekPosts = 0;
      try {
        print(
            'DEBUG GymService: Starting client-side filtering, docs count: ${totalPostsQuery.docs.length}');
        for (var doc in totalPostsQuery.docs) {
          final data = doc.data();
          final createdAtString = data['created_at'] as String?;
          print(
              'DEBUG GymService: Post ${doc.id} - created_at: $createdAtString');
          if (createdAtString != null) {
            final createdAt = DateTime.parse(createdAtString);
            print(
                'DEBUG GymService: Parsed date: $createdAt, oneWeekAgo: $oneWeekAgo, isAfter: ${createdAt.isAfter(oneWeekAgo)}');
            if (createdAt.isAfter(oneWeekAgo)) {
              thisWeekPosts++;
              print(
                  'DEBUG GymService: This week posts incremented to: $thisWeekPosts');
            }
          }
        }
      } catch (e) {
        print(
            'DEBUG GymService: Error parsing dates, using 0 for this week: $e');
        thisWeekPosts = 0;
      }
      print('DEBUG GymService: This week posts found: $thisWeekPosts');

      // Get unique users (members) - optional for now
      final uniqueUsers = <String>{};
      for (var doc in totalPostsQuery.docs) {
        final userId = doc.data()['user_id'] as String?;
        if (userId != null) {
          uniqueUsers.add(userId);
        }
      }

      final result = {
        'posts_count': totalPosts,
        'members_count': uniqueUsers.length,
        'this_week_posts': thisWeekPosts,
      };

      print('DEBUG GymService: Final stats: $result');
      return result;
    } catch (e) {
      print('Error fetching gym stats: $e');
      return {
        'posts_count': 0,
        'members_count': 0,
        'this_week_posts': 0,
      };
    }
  }
}
