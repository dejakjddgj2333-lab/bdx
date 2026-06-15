class User {
  final String? id;
  final String? username;
  final String? nickname;
  final String? avatar;
  final DateTime? createdAt;

  const User({
    this.id,
    this.username,
    this.nickname,
    this.avatar,
    this.createdAt,
  });

  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatar,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
