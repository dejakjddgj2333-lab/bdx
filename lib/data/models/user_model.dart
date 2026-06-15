import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String? id;
  final String? username;
  final String? nickname;
  final String? avatar;
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;

  const UserModel({
    this.id,
    this.username,
    this.nickname,
    this.avatar,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
