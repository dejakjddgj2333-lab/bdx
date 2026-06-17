import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import 'press_scale.dart';

enum BdxButtonType { primary, secondary, ghost, danger }

class BdxButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onTap;
  final BdxButtonType type;
  final double? width;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final bool expanded;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  const BdxButton({
    super.key,
    this.text,
    this.child,
    this.onTap,
    this.type = BdxButtonType.primary,
    this.width,
    this.height = AppDimens.buttonHeight,
    this.borderRadius = AppDimens.r28,
    this.icon,
    this.expanded = false,
    this.enabled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final isPrimary = type == BdxButtonType.primary;
    final isDanger = type == BdxButtonType.danger;
    final isGhost = type == BdxButtonType.ghost;
    final isSecondary = type == BdxButtonType.secondary;

    Gradient? gradient;
    Color backgroundColor = Colors.transparent;
    Color foregroundColor = Colors.white;
    List<BoxShadow>? shadows;

    if (isPrimary) {
      gradient = AppColors.primaryGradient;
      shadows = AppShadows.glowPrimary();
    } else if (isDanger) {
      gradient = const LinearGradient(
        colors: [AppColors.pink, Color(0xFFD81B60)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadows = AppShadows.glowAccent();
    } else if (isSecondary) {
      backgroundColor = colors.bgElevated;
      foregroundColor = colors.text;
    } else if (isGhost) {
      backgroundColor = Colors.transparent;
      foregroundColor = colors.textSecondary;
    }

    final effectiveOnTap = enabled ? onTap : null;

    Widget content = child ??
        Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foregroundColor, size: AppDimens.iconMedium),
              const SizedBox(width: AppDimens.s8),
            ],
            Text(
              text ?? '',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

    return PressScale(
      onTap: effectiveOnTap,
      haptic: enabled,
      child: Container(
        width: expanded ? double.infinity : width,
        height: height,
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? backgroundColor : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: isGhost || isSecondary
              ? Border.all(color: colors.borderSubtle)
              : null,
          boxShadow: shadows,
        ),
        child: content,
      ),
    );
  }
}

/// 圆形图标按钮，带按下缩放和光晕
class BdxIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final List<BoxShadow>? shadows;
  final bool glass;
  final bool showBorder;

  const BdxIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.backgroundColor,
    this.iconColor,
    this.shadows,
    this.glass = true,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (glass ? colors.glassWhite : colors.bgElevated),
          shape: BoxShape.circle,
          border: showBorder ? Border.all(color: colors.borderSubtle) : null,
          boxShadow: shadows,
        ),
        child: Icon(
          icon,
          color: iconColor ?? colors.text,
          size: size * 0.45,
        ),
      ),
    );
  }
}
