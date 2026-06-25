import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../../services/auth_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

enum _LoginMode { oneClick, email }

class LoginPage extends StatefulWidget {
  final String? redirect;

  const LoginPage({super.key, this.redirect});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  _LoginMode _mode = _LoginMode.oneClick;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  int _countdown = 0;
  bool _sendingCode = false;

  @override
  void initState() {
    super.initState();
    // 进入登录页即预热一键登录（初始化 SDK + 预取号），
    // 让用户点击「一键登录」时可秒弹授权页，或在不可用时立即转邮箱登录。
    AuthService.prepareAliAuth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  void _switchToEmail([String? message]) {
    if (message != null && message.isNotEmpty) {
      BdxToast.show(context, message: message, icon: Icons.info_outline);
    }
    setState(() => _mode = _LoginMode.email);
  }

  void _switchToOneClick() {
    setState(() => _mode = _LoginMode.oneClick);
  }

  Future<void> _startOneClickLogin() async {
    if (Platform.isAndroid) {
      final status = await Permission.phone.request();
      if (!status.isGranted) {
        _switchToEmail('请先允许电话权限，一键登录需要读取 SIM 卡信息');
        return;
      }
    }

    final result = await AuthService.startAliAuthLogin();
    if (!mounted) return;

    if (result.success && result.token != null) {
      context.read<AuthBloc>().add(AuthOneClickRequested(result.token!));
    } else {
      _switchToEmail(result.error ?? '一键登录失败，请使用邮箱登录');
    }
  }

  Future<void> _signInWithApple() async {
    final result = await AuthService.signInWithApple();
    if (!mounted) return;

    if (result.success && result.token != null && result.userIdentifier != null) {
      context.read<AuthBloc>().add(
            AuthAppleLoginRequested(
              identityToken: result.token!,
              userIdentifier: result.userIdentifier!,
              email: result.email,
              nickname: result.nickname,
            ),
          );
    } else {
      BdxToast.show(
        context,
        message: result.error ?? 'Apple 登录失败',
        icon: Icons.error_outline,
      );
    }
  }

  void _sendEmailCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      BdxToast.show(context, message: '请输入正确的邮箱地址');
      return;
    }
    context.read<AuthBloc>().add(AuthSendEmailCodeRequested(email));
  }

  void _emailLogin() {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      BdxToast.show(context, message: '请输入正确的邮箱地址');
      return;
    }
    if (code.length != 6) {
      BdxToast.show(context, message: '请输入6位验证码');
      return;
    }

    context.read<AuthBloc>().add(AuthEmailLoginRequested(email, code));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.of(context).bg,
      body: TechBackground(
        child: BlocListener<AuthBloc, AuthState>(
          listener: _handleAuthState,
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _mode == _LoginMode.oneClick
                              ? _buildOneClickPanel()
                              : _buildEmailPanel(),
                        ),
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

  void _handleAuthState(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      // 登录成功统一回首页
      context.go('/');
    } else if (state is AuthOneClickFailed) {
      _switchToEmail(state.error);
    } else if (state is AuthEmailCodeSending) {
      setState(() => _sendingCode = true);
    } else if (state is AuthEmailCodeSent) {
      _sendingCode = false;
      _startCountdown();
      BdxToast.show(context, message: '验证码已发送');
    } else if (state is AuthEmailCodeError) {
      setState(() => _sendingCode = false);
      BdxToast.show(
        context,
        message: state.error ?? '验证码发送失败',
        icon: Icons.error_outline,
      );
    } else if (state is AuthError) {
      BdxToast.show(
        context,
        message: state.error ?? '登录失败',
        icon: Icons.error_outline,
      );
    }
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.auto_awesome,
          color: AppColors.of(context).text,
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

  Widget _buildOneClickPanel() {
    final colors = AppColors.of(context);

    return Column(
      key: const ValueKey('oneClickPanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return BdxButton(
              text: '本机号码一键登录',
              expanded: true,
              enabled: !isLoading,
              onTap: isLoading ? null : _startOneClickLogin,
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
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: AppDimens.s16),
          _buildAppleButton(),
        ],
        const SizedBox(height: AppDimens.s24),
        TextButton(
          onPressed: () => _switchToEmail(),
          child: Text(
            '使用邮箱验证码登录',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleButton() {
    return GestureDetector(
      onTap: _signInWithApple,
      child: Container(
        height: AppDimens.buttonHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppDimens.r28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.apple,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: AppDimens.s8),
            const Text(
              '使用 Apple 登录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPanel() {
    final colors = AppColors.of(context);

    return Column(
      key: const ValueKey('emailPanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BdxInput(
          controller: _emailController,
          hintText: '邮箱地址',
          textInputAction: TextInputAction.next,
          prefix: Icon(
            Icons.email_outlined,
            color: colors.textTertiary,
            size: AppDimens.iconMedium,
          ),
        ),
        const SizedBox(height: AppDimens.s16),
        BdxInput(
          controller: _codeController,
          hintText: '6位验证码',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefix: Icon(
            Icons.confirmation_number_outlined,
            color: colors.textTertiary,
            size: AppDimens.iconMedium,
          ),
          suffix: SizedBox(
            height: 32,
            child: TextButton(
              onPressed: _countdown > 0 || _sendingCode ? null : _sendEmailCode,
              child: Text(
                _countdown > 0 ? '${_countdown}s' : '获取验证码',
                style: TextStyle(
                  color: _countdown > 0 || _sendingCode
                      ? colors.textTertiary
                      : AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.s36),
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return BdxButton(
              text: '登录',
              expanded: true,
              enabled: !isLoading,
              onTap: isLoading ? null : _emailLogin,
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
        ),
        const SizedBox(height: AppDimens.s24),
        TextButton(
          onPressed: _switchToOneClick,
          child: Text(
            '返回一键登录',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
