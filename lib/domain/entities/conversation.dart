class Conversation {
  final String? id;
  final String? title;
  final String? model;
  final String? agentId;
  final Map<String, dynamic>? agent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Conversation({
    this.id,
    this.title,
    this.model,
    this.agentId,
    this.agent,
    this.createdAt,
    this.updatedAt,
  });
}
