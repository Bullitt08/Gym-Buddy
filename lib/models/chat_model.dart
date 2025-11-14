class Chat {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool? lastMessageFromUser1;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Display data (not from database)
  final String? otherUserName;
  final String? otherUserPhoto;
  final int? unreadCount;

  Chat({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageFromUser1,
    required this.createdAt,
    required this.updatedAt,
    this.otherUserName,
    this.otherUserPhoto,
    this.unreadCount,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      lastMessageFromUser1: json['last_message_from_user1'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'last_message_from_user1': lastMessageFromUser1,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Chat copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? lastMessageFromUser1,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? otherUserName,
    String? otherUserPhoto,
    int? unreadCount,
  }) {
    return Chat(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageFromUser1: lastMessageFromUser1 ?? this.lastMessageFromUser1,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhoto: otherUserPhoto ?? this.otherUserPhoto,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  bool isLastMessageFromCurrentUser(String currentUserId) {
    if (lastMessageFromUser1 == null) return false;
    return (currentUserId == user1Id && lastMessageFromUser1!) ||
        (currentUserId == user2Id && !lastMessageFromUser1!);
  }
}
