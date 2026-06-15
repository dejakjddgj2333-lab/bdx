import 'package:json_annotation/json_annotation.dart';

part 'model_config.g.dart';

@JsonSerializable()
class ModelConfig {
  final String? id;
  final String? name;
  final String? description;
  @JsonKey(name: 'isDefault')
  final bool? isDefault;
  @JsonKey(name: 'supportsVision')
  final bool? supportsVision;
  @JsonKey(name: 'supportsVoice')
  final bool? supportsVoice;

  const ModelConfig({
    this.id,
    this.name,
    this.description,
    this.isDefault,
    this.supportsVision,
    this.supportsVoice,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) =>
      _$ModelConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ModelConfigToJson(this);
}
