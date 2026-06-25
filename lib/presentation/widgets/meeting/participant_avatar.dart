import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../blocs/meeting/meeting_cubit.dart';

/// 会议参与者头像：优先显示网络头像（相对路径自动补全），
/// 无头像或加载失败时 fallback 为彩色首字母。
class ParticipantAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final TextStyle? textStyle;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.size,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final fallback = SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initial,
          style: textStyle ??
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );

    final resolved = MeetingCubit.resolveAvatarUrl(avatarUrl);
    if (resolved == null) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
