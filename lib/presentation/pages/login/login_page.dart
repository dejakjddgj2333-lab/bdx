import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class LoginPage extends StatefulWidget {
  final String? redirect;

  const LoginPage({super.key, this.redirect});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.length < 2) {
      BdxToast.show(context, message: '用户名至少2位');
      return;
    }
    if (password.length < 6) {
      BdxToast.show(context, message: '密码至少6位');
      return;
    }

    final isLogin = _tabController.index == 0;
    final bloc = context.read<AuthBloc>();
    if (isLogin) {
      bloc.add(AuthLoginRequested(username, password));
    } else {
      final nickname = _nicknameController.text.trim();
      bloc.add(AuthRegisterRequested(username, password, nickname: nickname));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = AppColors.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.bg,
      body: TechBackground(
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              final redirect = widget.redirect;
              if (redirect != null && redirect.isNotEmpty) {
                context.go(redirect);
              } else {
                context.go('/');
              }
            } else if (state is AuthError) {
              BdxToast.show(
                context,
                message: state.error ?? '登录失败',
                icon: Icons.error_outline,
              );
            }
          },
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.s32,
                  AppDimens.s24,
                  AppDimens.s32,
                  bottomPadding + AppDimens.s24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: BdxAnimations.pageEnter(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogo(),
                        const SizedBox(height: AppDimens.s28),
                        Text(
                          '北斗星AI',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.display(context).copyWith(
                            fontSize: 32,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppDimens.s8),
                        Text(
                          '探索 AI 的无限可能',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall(context).copyWith(
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppDimens.s40),
                        _buildTabBar(),
                        const SizedBox(height: AppDimens.s32),
                        _buildTextField(
                          controller: _usernameController,
                          hint: '用户名',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: AppDimens.s16),
                        _buildTextField(
                          controller: _passwordController,
                          hint: '密码',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: AppDimens.s16),
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (_, _) {
                            if (_tabController.index == 0) {
                              return const SizedBox.shrink();
                            }
                            return BdxAnimations.fadeSlideIn(
                              _buildTextField(
                                controller: _nicknameController,
                                hint: '昵称（可选）',
                                icon: Icons.badge_outlined,
                              ),
                              beginY: 0.05,
                            );
                          },
                        ),
                        const SizedBox(height: AppDimens.s36),
                        _buildSubmitButton(),
                        const SizedBox(height: AppDimens.s24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 160,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 64,
        ),
      ),
    ).animate().scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildTabBar() {
    final colors = AppColors.of(context);

    return GlassCard(
      borderRadius: AppDimens.r28,
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppDimens.r24),
          boxShadow: AppShadows.glowPrimary(opacity: 0.3),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: colors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        tabs: const [
          Tab(text: '登录'),
          Tab(text: '注册'),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return BdxInput(
      controller: controller,
      hintText: hint,
      obscureText: obscureText,
      prefix: Icon(
        icon,
        color: AppColors.of(context).textTertiary,
        size: AppDimens.iconMedium,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return BdxButton(
          text: _tabController.index == 0 ? '登录' : '注册',
          expanded: true,
          enabled: !isLoading,
          onTap: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : null,
        );
      },
    );
  }
}
