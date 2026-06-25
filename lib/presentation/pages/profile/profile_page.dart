import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../injection.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  bool _busy = false;

  /// 选取图片并上传头像
  Future<void> _pickAndUploadAvatar() async {
    if (_busy) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await image.readAsBytes();
      await _authRepository.uploadAvatar(bytes, filename: image.name);
      if (!mounted) return;
      // 头像已在服务端写入，刷新认证态以更新展示
      context.read<AuthBloc>().add(const AuthProfileLoaded());
      BdxToast.show(context, message: '头像已更新', icon: Icons.check_circle_outline);
    } catch (e) {
      if (!mounted) return;
      BdxToast.show(context, message: '上传失败: $e', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 编辑昵称
  Future<void> _editNickname(String? current) async {
    if (_busy) return;
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: current ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.r20),
        ),
        title: Text('修改昵称', style: TextStyle(color: colors.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: TextStyle(color: colors.text),
          decoration: InputDecoration(
            hintText: '请输入昵称',
            hintStyle: TextStyle(color: colors.textTertiary),
            counterStyle: TextStyle(color: colors.textTertiary),
          ),
          onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final nickname = controller.text.trim();
              if (nickname.isEmpty) {
                BdxToast.show(
                  dialogContext,
                  message: '昵称不能为空',
                  icon: Icons.error_outline,
                );
                return;
              }
              if (nickname.length > 20) {
                BdxToast.show(
                  dialogContext,
                  message: '昵称长度不能超过 20 个字符',
                  icon: Icons.error_outline,
                );
                return;
              }
              Navigator.pop(dialogContext, nickname);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == current || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _authRepository.updateProfile(nickname: result);
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthProfileLoaded());
      BdxToast.show(context, message: '昵称已更新', icon: Icons.check_circle_outline);
    } catch (e) {
      if (!mounted) return;
      BdxToast.show(context, message: '保存失败: $e', icon: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    final colors = AppColors.of(context);

    return BdxAnimations.fadeSlideIn(
      GlassCard(
        borderRadius: AppDimens.r24,
        padding: const EdgeInsets.all(AppDimens.s20),
        child: Row(
          children: [
            // 头像（登录后可点击修改）
            PressScale(
              onTap: isLogin ? _pickAndUploadAvatar : null,
              child: Stack(
                children: [
                  BdxAvatar(
                    imageUrl: user?.avatar,
                    icon: Icons.person,
                    size: 68,
                    borderRadius: AppDimens.r22,
                  ),
                  if (isLogin)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.bgElevated, width: 2),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.s20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.nickname ?? (isLogin ? '用户' : '未登录'),
                          style: AppTextStyles.titleLarge(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLogin) ...[
                        const SizedBox(width: AppDimens.s8),
                        GestureDetector(
                          onTap: () => _editNickname(user?.nickname),
                          child: Icon(
                            Icons.edit_outlined,
                            size: AppDimens.iconSmall,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ],
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
