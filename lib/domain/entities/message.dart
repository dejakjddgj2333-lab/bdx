class Message {
  final String? id;
  final String? role;
  final dynamic content;
  final String? contentType;
  final String? model;
  final DateTime? createdAt;

  const Message({
    this.id,
    this.role,
    this.content,
    this.contentType,
    this.model,
    this.createdAt,
  });

  Message copyWith({
    String? id,
    String? role,
    dynamic content,
    String? contentType,
    String? model,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
