import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// 品牌色 shimmer 骨架屏
///
/// 比默认灰白 shimmer 更有高级感，使用品牌紫 / 青渐变扫过。
class BdxSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const BdxSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppDimens.r12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Shimmer(
      gradient: LinearGradient(
        colors: [
          colors.surface,
          AppColors.primary.withValues(alpha: 0.28),
          AppColors.success.withValues(alpha: 0.22),
          colors.surface,
        ],
        stops: const [0.0, 0.38, 0.62, 1.0],
      ),
      period: const Duration(milliseconds: 1800),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
