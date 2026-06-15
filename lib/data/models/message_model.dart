import 'package:json_annotation/json_annotation.dart';

part 'message_model.g.dart';

@JsonSerializable()
class MessageModel {
  final String? id;
  final String? role;
  final dynamic content;
  @JsonKey(name: 'contentType')
  final String? contentType;
  final String? model;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;

  const MessageModel({
    this.id,
    this.role,
    this.content,
    this.contentType,
    this.model,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageModelToJson(this);
}
