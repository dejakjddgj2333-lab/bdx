import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/bdx_animations.dart';
import 'glass_card.dart';

class BdxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? illustration;

  const BdxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return BdxAnimations.fadeSlideIn(
      SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: AppDimens.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (illustration != null)
                  illustration!
                else
                  GlassCard(
                    borderRadius: AppDimens.r24,
                    padding: const EdgeInsets.all(AppDimens.s24),
                    child: Icon(icon, color: colors.textTertiary, size: 40),
                  ),
                const SizedBox(height: AppDimens.s20),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimens.s8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppDimens.s24),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
