import 'package:json_annotation/json_annotation.dart';

part 'conversation_model.g.dart';

@JsonSerializable()
class ConversationModel {
  final String? id;
  final String? title;
  final String? model;
  @JsonKey(name: 'agentId')
  final String? agentId;
  @JsonKey(name: 'agent')
  final Map<String, dynamic>? agent;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime? updatedAt;

  const ConversationModel({
    this.id,
    this.title,
    this.model,
    this.agentId,
    this.agent,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationModelToJson(this);
}
