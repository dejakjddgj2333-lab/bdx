import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// 玻璃拟态卡片
///
/// 自动根据当前主题选择背景色，并叠加 [BackdropFilter] 实现真正的毛玻璃效果。
/// 可通过 [borderColor]、[gradient]、[padding] 调整风格。
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final bool useBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppDimens.r20,
    this.customBorderRadius,
    this.borderColor,
    this.gradient,
    this.shadows,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveRadius = customBorderRadius ??
        BorderRadius.circular(borderRadius);

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.glassGradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? colors.borderSubtle,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (useBlur) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 仅作为视觉装饰的玻璃面板，无子元素
class GlassPanel extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;
  final List<BoxShadow>? shadows;

  const GlassPanel({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppDimens.r20,
    this.color,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color ?? colors.glassWhite,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colors.borderSubtle),
            boxShadow: shadows,
          ),
        ),
      ),
    );
  }
}
