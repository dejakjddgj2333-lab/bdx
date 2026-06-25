import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

/// 语义化文字样式 Token
///
/// 不再直接 `TextStyle(color: ..., fontSize: ...)`，而是通过 [AppTextStyles]
/// 获取与主题绑定的样式。这样将来换字体、改字号只需改一处。
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required Color color,
    required double fontSize,
    FontWeight? weight,
    double? height,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.w400,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static AppColorsPalette _palette(BuildContext context) =>
      AppColors.of(context);

  // ===== Display / Hero =====
  static TextStyle display(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 32,
        weight: FontWeight.w700,
        height: 1.2,
      );

  // ===== Headline =====
  static TextStyle headline(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 24,
        weight: FontWeight.w600,
        height: 1.3,
      );

  // ===== Title =====
  static TextStyle titleLarge(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 20,
        weight: FontWeight.w600,
      );

  static TextStyle title(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 18,
        weight: FontWeight.w600,
      );

  static TextStyle titleSmall(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 16,
        weight: FontWeight.w600,
      );

  // ===== Body =====
  static TextStyle bodyLarge(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 16,
        height: 1.6,
      );

  static TextStyle body(BuildContext context) => _base(
        color: _palette(context).text,
        fontSize: 14,
        height: 1.6,
      );

  static TextStyle bodySmall(BuildContext context) => _base(
        color: _palette(context).textSecondary,
        fontSize: 13,
        height: 1.5,
      );

  // ===== Caption / Meta =====
  static TextStyle caption(BuildContext context) => _base(
        color: _palette(context).textTertiary,
        fontSize: 12,
      );

  static TextStyle captionSmall(BuildContext context) => _base(
        color: _palette(context).textTertiary,
        fontSize: 11,
      );

  // ===== Button / Label =====
  static TextStyle button(BuildContext context) => _base(
        color: Colors.white,
        fontSize: 15,
        weight: FontWeight.w600,
      );

  static TextStyle label(BuildContext context) => _base(
        color: _palette(context).textSecondary,
        fontSize: 12,
        weight: FontWeight.w500,
      );

  // ===== Chat specific =====
  static TextStyle chatBubble(BuildContext context) => _base(
        color: Colors.white,
        fontSize: 15,
        height: 1.55,
      );

  static TextStyle chatModelLabel(BuildContext context) => _base(
        color: _palette(context).textTertiary,
        fontSize: AppDimens.s12,
      );
}
