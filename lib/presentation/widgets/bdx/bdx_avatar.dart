import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';

class BdxAvatar extends StatelessWidget {
  final String? imageUrl;
  final IconData? icon;
  final double size;
  final double borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const BdxAvatar({
    super.key,
    this.imageUrl,
    this.icon,
    this.size = AppDimens.avatarMedium,
    this.borderRadius = AppDimens.r14,
    this.gradient,
    this.shadows,
  });

  /// 将相对路径（如 /uploads/avatars/xxx.webp）补全为完整 URL；
  /// 空值或已是完整地址时按原样处理。
  String? get _resolvedUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConstants.uploadBaseUrl.replaceAll(RegExp(r'/$'), '')}$url';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? Icons.person;
    final effectiveGradient = gradient ?? AppColors.primaryGradient;
    final resolvedUrl = _resolvedUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: resolvedUrl == null ? effectiveGradient : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? AppShadows.avatarGlow(AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl != null
          ? CachedNetworkImage(
              imageUrl: resolvedUrl,
              width: size,
              height: size,
              memCacheWidth: (size * 2).toInt(),
              memCacheHeight: (size * 2).toInt(),
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.primaryDark),
              errorWidget: (_, _, _) => Icon(effectiveIcon, color: Colors.white, size: size * 0.45),
            )
          : Icon(effectiveIcon, color: Colors.white, size: size * 0.45),
    );
  }
}

class BdxGradientAvatar extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final double size;
  final double borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const BdxGradientAvatar({
    super.key,
    this.child,
    this.icon,
    this.size = 56,
    this.borderRadius = AppDimens.r18,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? AppShadows.avatarGlow(AppColors.primary),
      ),
      child: child ??
          (icon != null
              ? Icon(icon, color: Colors.white, size: size * 0.45)
              : null),
    );
  }
}
