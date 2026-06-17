import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: Column(
          children: [
            AppHeader(
              title: '我的',
              leading: BdxIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                backgroundColor: Colors.transparent,
              ),
            ),
            Expanded(
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final user = state.user;
                  final isLogin = state.isAuthenticated;

                  return SingleChildScrollView(
                    padding: AppDimens.pagePadding,
                    child: Column(
                      children: [
                        _buildUserCard(context, user, isLogin),
                        const SizedBox(height: AppDimens.s24),
                        _buildActionButton(
                          context,
                          icon: Icons.settings_outlined,
                          label: '设置',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/settings');
                          },
                        ),
                        const SizedBox(height: AppDimens.s12),
                        if (isLogin)
                          _buildActionButton(
                            context,
                            icon: Icons.logout,
                            label: '退出登录',
                            color: AppColors.pink,
                            onTap: () => _showLogoutDialog(context),
                          )
                        else
                          BdxButton(
                            text: '去登录',
                            icon: Icons.login,
                            expanded: true,
                            onTap: () => context.go('/login'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic user, bool isLogin) {
    return BdxAnimations.fadeSlideIn(
      GlassCard(
        borderRadius: AppDimens.r24,
        padding: const EdgeInsets.all(AppDimens.s20),
        child: Row(
          children: [
            BdxAvatar(
              imageUrl: user?.avatar,
              icon: Icons.person,
              size: 68,
              borderRadius: AppDimens.r22,
            ),
            const SizedBox(width: AppDimens.s20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nickname ?? (isLogin ? '用户' : '未登录'),
                    style: AppTextStyles.titleLarge(context),
                  ),
                  if (user?.username != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimens.s4),
                      child: Text(
                        '@${user!.username}',
                        style: AppTextStyles.caption(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: onTap,
      child: GlassCard(
        borderRadius: AppDimens.r16,
        padding: AppDimens.listItemPadding,
        margin: const EdgeInsets.only(bottom: AppDimens.s12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color?.withValues(alpha: 0.15) ?? colors.glassWhite,
                borderRadius: BorderRadius.circular(AppDimens.r10),
              ),
              child: Icon(
                icon,
                color: color ?? colors.text,
                size: AppDimens.iconMedium,
              ),
            ),
            const SizedBox(width: AppDimens.s12),
            Text(
              label,
              style: TextStyle(
                color: color ?? colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: color ?? colors.textTertiary,
              size: AppDimens.iconMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.r20),
        ),
        title: Text('确认退出？', style: TextStyle(color: colors.text)),
        content: Text(
          '退出后需要重新登录',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              context.go('/login');
            },
            child: const Text(
              '退出',
              style: TextStyle(color: AppColors.pink),
            ),
          ),
        ],
      ),
    );
  }
}
