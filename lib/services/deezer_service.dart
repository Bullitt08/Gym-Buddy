import 'package:http/http.dart' as http;
import 'dart:convert';

class DeezerTrack {
  final String id;
  final String name;
  final String artist;
  final String? albumArt;
  final String? previewUrl;
  final String link; // Deezer web link

  DeezerTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.albumArt,
    this.previewUrl,
    required this.link,
  });

  factory DeezerTrack.fromJson(Map<String, dynamic> json) {
    return DeezerTrack(
      id: json['id']?.toString() ?? '',
      name: json['title'] ?? '',
      artist: json['artist']?['name'] ?? 'Unknown Artist',
      albumArt: json['album']?['cover_medium'] ?? json['album']?['cover_big'],
      previewUrl: json['preview'],
      link: json['link'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'albumArt': albumArt,
      'previewUrl': previewUrl,
      'link': link,
    };
  }
}

class DeezerService {
  // Deezer API - Authentication is not required
  static const String baseUrl = 'https://api.deezer.com';

  // Find tracks
  Future<List<DeezerTrack>> searchTracks(String query) async {
    try {
      print('DEBUG DEEZER: Searching for: $query');

      final response = await http.get(
        Uri.parse('$baseUrl/search?q=${Uri.encodeComponent(query)}&limit=20'),
      );

      print('DEBUG DEEZER: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final tracks = (data['data'] as List?)?.map((item) {
              final track = DeezerTrack.fromJson(item);
              return track;
            }).toList() ??
            [];

        // Count how many tracks have preview URLs
        final tracksWithPreview = tracks
            .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
            .length;
        print(
            'DEBUG DEEZER: Found ${tracks.length} tracks, $tracksWithPreview with preview URLs');

        return tracks;
      } else {
        print('DEBUG DEEZER: Error - Status ${response.statusCode}');
        throw Exception('Arama başarısız: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG DEEZER: Exception - $e');
      return [];
    }
  }

  // Get Track Details
  Future<DeezerTrack?> getTrack(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/track/$trackId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DeezerTrack.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error of getTrack: $e');
      return null;
    }
  }
}
