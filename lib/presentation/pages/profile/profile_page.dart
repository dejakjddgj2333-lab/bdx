import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_header.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          AppHeader(
            title: '我的',
            leading: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              icon: Icon(Icons.arrow_back, color: colors.text),
            ),
          ),
          Expanded(
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final user = state.user;
                final isLogin = state.isAuthenticated;

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildUserCard(context, user, isLogin),
                      const SizedBox(height: 24),
                      _buildActionButton(
                        context,
                        icon: Icons.settings_outlined,
                        label: '设置',
                        onTap: () => context.push('/settings'),
                      ),
                      const SizedBox(height: 12),
                      if (isLogin)
                        _buildActionButton(
                          context,
                          icon: Icons.logout,
                          label: '退出登录',
                          color: AppColors.pink,
                          onTap: () => _showLogoutDialog(context),
                        )
                      else
                        _buildActionButton(
                          context,
                          icon: Icons.login,
                          label: '去登录',
                          gradient: AppColors.primaryGradient,
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
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic user, bool isLogin) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: user?.avatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(user!.avatar!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.nickname ?? (isLogin ? '用户' : '未登录'),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user?.username != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '@${user!.username}',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    Gradient? gradient,
  }) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? colors.glassWhite : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? colors.text),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color ?? colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: color ?? colors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              context.go('/login');
            },
            child: const Text('退出', style: TextStyle(color: AppColors.pink)),
          ),
        ],
      ),
    );
  }
}
