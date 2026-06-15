// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentModel _$AgentModelFromJson(Map<String, dynamic> json) => AgentModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      usageCount: (json['usageCount'] as num?)?.toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$AgentModelToJson(AgentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'description': instance.description,
      'avatar': instance.avatar,
      'usageCount': instance.usageCount,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
