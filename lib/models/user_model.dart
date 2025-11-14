class UserModel {
  final String id;
  final String email;
  final String username;
  final String? profilePhoto;
  final String? bio;
  final String? userCode;
  final int streak;
  final List<String> friends;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.profilePhoto,
    this.bio,
    this.userCode,
    required this.streak,
    required this.friends,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Fallback username generation from email if username is null or empty
    String username = json['username'] ?? '';
    if (username.isEmpty && json['email'] != null) {
      username = json['email'].split('@')[0];
    }

    return UserModel(
      id: json['id'],
      email: json['email'],
      username: username,
      profilePhoto: json['profile_photo'],
      bio: json['bio'],
      userCode: json['user_code'],
      streak: json['streak'] ?? 0,
      friends: List<String>.from(json['friends'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'profile_photo': profilePhoto,
      'bio': bio,
      'user_code': userCode,
      'streak': streak,
      'friends': friends,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
