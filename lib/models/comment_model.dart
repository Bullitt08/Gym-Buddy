class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final Map<String, dynamic>? user;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.user,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      isLikedByCurrentUser: json['is_liked_by_current_user'] ?? false,
      user: json['users'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'likes_count': likesCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'users': user,
    };
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? comment,
    DateTime? createdAt,
    int? likesCount,
    bool? isLikedByCurrentUser,
    Map<String, dynamic>? user,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      user: user ?? this.user,
    );
  }
}
