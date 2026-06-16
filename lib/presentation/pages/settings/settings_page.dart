import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme_mode.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../blocs/theme/theme_state.dart';
import '../../blocs/voice_call_settings/voice_call_settings_cubit.dart';
import '../../widgets/app_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          AppHeader(
            title: '设置',
            leading: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              icon: Icon(Icons.arrow_back, color: colors.text),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, '外观'),
                  const SizedBox(height: 12),
                  _buildThemeCard(context),
                  const SizedBox(height: 28),
                  _buildSectionTitle(context, '语音通话音色'),
                  const SizedBox(height: 12),
                  _buildVoiceCallCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colors = AppColors.of(context);
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
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return Column(
            children: AppThemeMode.values.map((mode) {
              final isSelected = state.mode == mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildThemeOption(
                  context,
                  mode: mode,
                  isSelected: isSelected,
                  onTap: () => context.read<ThemeCubit>().setMode(mode),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : colors.bgElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 12),
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
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: BlocBuilder<VoiceCallSettingsCubit, VoiceCallSettingsState>(
        builder: (context, state) {
          if (state.isLoading || state.config == null) {
            // 未加载时自动触发加载
            if (state.config == null) {
              context.read<VoiceCallSettingsCubit>().load();
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (state.error != null) {
            return Text(
              '加载失败：${state.error}',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            );
          }

          final config = state.config!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  '当前厂商：${config.name}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              ...config.voices.map((voice) {
                final isSelected = state.selectedVoice == voice;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildVoiceCallOption(
                    context,
                    voice: voice,
                    label: config.labelFor(voice),
                    isSelected: isSelected,
                    onTap: () => context.read<VoiceCallSettingsCubit>().selectVoice(voice),
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : colors.bgElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.text : colors.textSecondary,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
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