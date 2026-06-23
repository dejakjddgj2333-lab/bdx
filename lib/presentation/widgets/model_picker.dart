import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_text_styles.dart';
import '../widgets/bdx/bdx.dart';

class ModelPicker extends StatelessWidget {
  final List<Map<String, dynamic>> models;
  final String? selectedId;
  final Function(String) onSelected;

  const ModelPicker({
    super.key,
    required this.models,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ClipRRect(
      borderRadius: AppDimens.topRadius24,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: colors.bgElevated.withValues(alpha: 0.82),
          borderRadius: AppDimens.topRadius24,
          child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.s20,
            AppDimens.s12,
            AppDimens.s20,
            AppDimens.s28,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BdxBottomSheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择模型',
                    style: AppTextStyles.title(context),
                  ),
                  BdxIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                    size: 36,
                    backgroundColor: Colors.transparent,
                    iconColor: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.s12),
              Flexible(
                child: AnimationLimiter(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      final id = model['id']?.toString() ?? '';
                      final isSelected = id == selectedId;
                      final isDefault = model['isDefault'] == true;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 300),
                        child: SlideAnimation(
                          verticalOffset: 20,
                          child: FadeInAnimation(
                            child: _buildModelItem(
                              context,
                              model: model,
                              id: id,
                              isSelected: isSelected,
                              isDefault: isDefault,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildModelItem(
    BuildContext context, {
    required Map<String, dynamic> model,
    required String id,
    required bool isSelected,
    required bool isDefault,
  }) {
    final colors = AppColors.of(context);
    final name = model['name']?.toString() ?? '未命名';
    final description = model['description']?.toString();

    return PressScale(
      onTap: () {
        onSelected(id);
        Navigator.pop(context);
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: AppDimens.s10),
        padding: const EdgeInsets.all(AppDimens.s14),
        borderRadius: AppDimens.r16,
        borderColor: isSelected ? colors.border : colors.borderSubtle,
        gradient: isSelected ? AppColors.glassGradient : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: AppDimens.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.s6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDimens.r6),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            '默认',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimens.s4),
                      child: Text(
                        description,
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryLight)
            else
              Icon(Icons.circle_outlined, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
