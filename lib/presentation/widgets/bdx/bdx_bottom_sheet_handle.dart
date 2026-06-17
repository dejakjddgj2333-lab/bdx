import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// 底部弹窗顶部的小横条
class BdxBottomSheetHandle extends StatelessWidget {
  const BdxBottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppDimens.s12),
      decoration: BoxDecoration(
        color: colors.borderSubtle,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
