// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelConfig _$ModelConfigFromJson(Map<String, dynamic> json) => ModelConfig(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      isDefault: json['isDefault'] as bool?,
      supportsVision: json['supportsVision'] as bool?,
      supportsVoice: json['supportsVoice'] as bool?,
    );

Map<String, dynamic> _$ModelConfigToJson(ModelConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'isDefault': instance.isDefault,
      'supportsVision': instance.supportsVision,
      'supportsVoice': instance.supportsVoice,
    };
