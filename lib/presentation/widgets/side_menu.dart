import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../blocs/auth/auth_bloc.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Drawer(
      backgroundColor: colors.bgElevated,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: colors.borderSubtle),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Divider(color: colors.borderSubtle, indent: 16, endIndent: 16),
              _buildMenuItem(context, Icons.chat_bubble_outline, '新建对话', () {
                Navigator.pop(context);
                context.push('/chat/detail');
              }),
              _buildMenuItem(context, Icons.smart_toy_outlined, '发现智能体', () {
                Navigator.pop(context);
                context.push('/agents');
              }),
              _buildMenuItem(context, Icons.phone_in_talk_outlined, '语音通话', () {
                Navigator.pop(context);
                context.push('/voice-call');
              }),
              const Spacer(),
              Divider(color: colors.borderSubtle, indent: 16, endIndent: 16),
              _buildMenuItem(context, Icons.settings_outlined, '设置', () {
                Navigator.pop(context);
                context.push('/settings');
              }),
              _buildMenuItem(context, Icons.person_outline, '个人中心', () {
                Navigator.pop(context);
                context.push('/profile');
              }),
              _buildMenuItem(context, Icons.logout, '退出登录', () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(const AuthLogoutRequested());
                context.go('/login');
              }, color: AppColors.pink),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = AppColors.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final nickname = state.user?.nickname ?? '未登录';
        final avatar = state.user?.avatar;
        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: avatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(avatar, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.isAuthenticated ? '已登录' : '未登录',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    final colors = AppColors.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.glassWhite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? colors.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? colors.text,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: colors.textTertiary, size: 20),
      onTap: onTap,
    );
  }
}
