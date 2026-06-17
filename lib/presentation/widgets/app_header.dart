import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBorder;
  final bool useBlur;

  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showBorder = false,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final colors = AppColors.of(context);

    Widget content = Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + AppDimens.s8,
        left: AppDimens.s8,
        right: AppDimens.s8,
        bottom: AppDimens.s10,
      ),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: useBlur ? 0.82 : 0.96),
        border: showBorder
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.5),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions!.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimens.s8),
                  actions![i],
                ],
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );

    if (useBlur) {
      content = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: content,
        ),
      );
    }

    return content;
  }
}
