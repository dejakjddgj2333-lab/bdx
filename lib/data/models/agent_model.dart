import 'package:json_annotation/json_annotation.dart';

part 'agent_model.g.dart';

@JsonSerializable()
class AgentModel {
  final String? id;
  final String? name;
  final String? category;
  final String? description;
  final String? avatar;
  @JsonKey(name: 'usageCount')
  final int? usageCount;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;

  const AgentModel({
    this.id,
    this.name,
    this.category,
    this.description,
    this.avatar,
    this.usageCount,
    this.createdAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) =>
      _$AgentModelFromJson(json);

  Map<String, dynamic> toJson() => _$AgentModelToJson(this);
}
