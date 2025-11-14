class PostModel {
  final String id;
  final String userId;
  final String mediaUrl;
  final String type; // 'photo' or 'video'
  final String? caption;
  final List<String> taggedUsers;
  final String? musicTrackId;
  final String? musicTrackName;
  final String? musicArtist;
  final String? musicAlbumArt;
  final String? musicPreviewUrl;
  final DateTime createdAt;
  final Map<String, double>? location; // lat, lng
  final String? locationName; // human readable location name

  PostModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.type,
    this.caption,
    required this.taggedUsers,
    this.musicTrackId,
    this.musicTrackName,
    this.musicArtist,
    this.musicAlbumArt,
    this.musicPreviewUrl,
    required this.createdAt,
    this.location,
    this.locationName,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['user_id'],
      mediaUrl: json['media_url'],
      type: json['type'],
      caption: json['caption'],
      taggedUsers: List<String>.from(json['tagged_users'] ?? []),
      musicTrackId: json['music_track_id'],
      musicTrackName: json['music_track_name'],
      musicArtist: json['music_artist'],
      musicAlbumArt: json['music_album_art'],
      musicPreviewUrl: json['music_preview_url'],
      createdAt: DateTime.parse(json['created_at']),
      location: json['location'] != null
          ? Map<String, double>.from(json['location'])
          : null,
      locationName: json['location_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': mediaUrl,
      'type': type,
      'caption': caption,
      'tagged_users': taggedUsers,
      'music_track_id': musicTrackId,
      'music_track_name': musicTrackName,
      'music_artist': musicArtist,
      'music_album_art': musicAlbumArt,
      'music_preview_url': musicPreviewUrl,
      'created_at': createdAt.toIso8601String(),
      'location': location,
      'location_name': locationName,
    };
  }
}
