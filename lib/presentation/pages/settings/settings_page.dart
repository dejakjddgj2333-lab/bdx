import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_theme_mode.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../blocs/theme/theme_state.dart';
import '../../blocs/voice_call_settings/voice_call_settings_cubit.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: Column(
          children: [
            AppHeader(
              title: '设置',
              leading: BdxIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                backgroundColor: Colors.transparent,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppDimens.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, '外观'),
                    const SizedBox(height: AppDimens.s12),
                    _buildThemeCard(context),
                    const SizedBox(height: AppDimens.s28),
                    _buildSectionTitle(context, '语音通话音色'),
                    const SizedBox(height: AppDimens.s12),
                    _buildVoiceCallCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppDimens.s8),
        Text(
          title,
          style: AppTextStyles.label(context),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    return GlassCard(
      padding: AppDimens.cardPadding,
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return Column(
            children: AppThemeMode.values.map((mode) {
              final isSelected = state.mode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.s10),
                child: _buildThemeOption(
                  context,
                  mode: mode,
                  isSelected: isSelected,
                  onTap: () {
                    context.read<ThemeCubit>().setMode(mode);
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required AppThemeMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.s16,
          vertical: AppDimens.s14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : colors.bgElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimens.r16),
          border: Border.all(
            color: isSelected ? colors.border : colors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              color: isSelected ? AppColors.primaryLight : colors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppDimens.s12),
            Text(
              mode.displayName,
              style: TextStyle(
                color: isSelected ? colors.text : colors.textSecondary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryLight,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCallCard(BuildContext context) {
    return GlassCard(
      padding: AppDimens.cardPadding,
      child: BlocBuilder<VoiceCallSettingsCubit, VoiceCallSettingsState>(
        builder: (context, state) {
          if (!state.isLoaded && !state.isLoading && state.error == null) {
            context.read<VoiceCallSettingsCubit>().load();
          }

          if (state.error != null) {
            return Text(
              '加载失败：${state.error}',
              style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 14),
            );
          }

          if (state.isLoading || !state.isLoaded) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.s16),
                child: BdxLoading(),
              ),
            );
          }

          final config = state.config!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.s12, left: AppDimens.s4),
                child: Text(
                  '当前厂商：${config.name}',
                  style: TextStyle(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              ...config.voices.map((voice) {
                final isSelected = state.selectedVoice == voice;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.s10),
                  child: _buildVoiceCallOption(
                    context,
                    voice: voice,
                    label: config.labelFor(voice),
                    intro: config.introFor(voice),
                    isSelected: isSelected,
                    onTap: () {
                      context.read<VoiceCallSettingsCubit>().selectVoice(voice);
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceCallOption(
    BuildContext context, {
    required String voice,
    required String label,
    String? intro,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.s16,
          vertical: AppDimens.s14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : colors.bgElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimens.r16),
          border: Border.all(
            color: isSelected ? colors.border : colors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.record_voice_over_outlined,
              color: isSelected ? AppColors.primaryLight : colors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: AppDimens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? colors.text : colors.textSecondary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (intro != null && intro.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimens.s2),
                      child: Text(
                        intro,
                        style: TextStyle(
                          color: isSelected
                              ? colors.textSecondary
                              : colors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryLight,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
