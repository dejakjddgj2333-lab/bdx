import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'bdx_button.dart';
import 'glass_card.dart';

/// 代码块展示卡片（带复制按钮）
class BdxCodeBlock extends StatelessWidget {
  final String code;
  final String? language;

  const BdxCodeBlock({
    super.key,
    required this.code,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.s8),
      child: GlassCard(
        borderRadius: AppDimens.r12,
        useBlur: true,
        backgroundColor: colors.surfaceHigh,
        borderColor: colors.borderSubtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (language != null && language!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimens.s12,
                  top: AppDimens.s8,
                  right: AppDimens.s12,
                ),
                child: Text(
                  language!.toUpperCase(),
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimens.s12),
                  child: SelectableText(
                    code,
                    style: TextStyle(
                      color: colors.text,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  top: AppDimens.s8,
                  right: AppDimens.s8,
                  child: BdxIconButton(
                    icon: Icons.copy,
                    size: 32,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('代码已复制'),
                            backgroundColor: colors.bgElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.r12),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    backgroundColor: colors.glassWhite,
                    iconColor: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
