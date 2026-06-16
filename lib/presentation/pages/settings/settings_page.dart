import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme_mode.dart';
import '../../../core/constants/conversation_voice.dart';
import '../../blocs/theme/theme_cubit.dart';
import '../../blocs/theme/theme_state.dart';
import '../../blocs/voice/voice_cubit.dart';
import '../../blocs/voice/voice_state.dart';
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
                  _buildSectionTitle(context, '对话声音'),
                  const SizedBox(height: 12),
                  _buildVoiceCard(context),
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

  Widget _buildVoiceCard(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: BlocBuilder<VoiceCubit, VoiceState>(
        builder: (context, state) {
          final grouped = _groupVoices();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: grouped.entries.expand((entry) {
              final category = entry.key;
              final voices = entry.value;
              return [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ...voices.map((voice) {
                  final isSelected = state.voice == voice;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildVoiceOption(
                      context,
                      voice: voice,
                      isSelected: isSelected,
                      onTap: () => context.read<VoiceCubit>().setVoice(voice),
                    ),
                  );
                }),
              ];
            }).toList(),
          );
        },
      ),
    );
  }

  Map<String, List<ConversationVoice>> _groupVoices() {
    final result = <String, List<ConversationVoice>>{};
    for (final voice in ConversationVoice.values) {
      result.putIfAbsent(voice.category, () => []).add(voice);
    }
    return result;
  }

  Widget _buildVoiceOption(
    BuildContext context, {
    required ConversationVoice voice,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                voice.categoryIcon,
                color: isSelected ? AppColors.primaryLight : colors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.displayName,
                    style: TextStyle(
                      color: isSelected ? colors.text : colors.textSecondary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    voice.description,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '适合：${voice.scenario}',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
