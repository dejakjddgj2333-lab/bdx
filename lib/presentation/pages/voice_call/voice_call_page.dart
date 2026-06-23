import 'dart:async';
import 'dart:io';
import 'dart:math' show pi, sin;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../../injection.dart';
import '../../../services/audio_recorder_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/voice_call/voice_call_bloc.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({super.key});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _waveController;
  Timer? _durationTimer;
  bool _microphoneDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      context.go('/login?redirect=/voice-call');
      return;
    }

    if (kIsWeb) {
      context.read<VoiceCallBloc>().add(const VoiceCallStarted());
      _startDurationTimer();
      return;
    }

    if (Platform.isIOS) {
      final granted = await getIt<AudioRecorderService>().hasPermission();
      if (!mounted) return;
      if (granted) {
        setState(() => _microphoneDenied = false);
        context.read<VoiceCallBloc>().add(const VoiceCallStarted());
        _startDurationTimer();
      } else {
        setState(() => _microphoneDenied = true);
      }
      return;
    }

    final current = await Permission.microphone.status;
    if (!mounted) return;
    if (current.isGranted) {
      setState(() => _microphoneDenied = false);
      context.read<VoiceCallBloc>().add(const VoiceCallStarted());
      _startDurationTimer();
      return;
    }
    if (current.isPermanentlyDenied || current.isRestricted) {
      setState(() => _microphoneDenied = true);
      return;
    }

    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _microphoneDenied = false);
      context.read<VoiceCallBloc>().add(const VoiceCallStarted());
      _startDurationTimer();
    } else {
      setState(() => _microphoneDenied = true);
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context.read<VoiceCallBloc>().add(const VoiceCallDurationTick());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _microphoneDenied) {
      _checkPermissionAndStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: BlocConsumer<VoiceCallBloc, VoiceCallState>(
          listener: (context, state) {
            if (state.status == CallStatus.idle) {
              _durationTimer?.cancel();
            }
          },
          builder: (context, state) {
            if (_microphoneDenied) {
              return SafeArea(child: _buildPermissionDenied());
            }
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BdxIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => _goBack(context),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  const Spacer(),
                  _buildAvatar(state),
                  const SizedBox(height: AppDimens.s32),
                  BdxAnimations.breathe(
                    Text(
                      state.statusText,
                      style: AppTextStyles.headline(context),
                    ),
                    minOpacity: 0.75,
                    maxOpacity: 1.0,
                    durationMs: state.status == CallStatus.listening
                        ? 1200
                        : 2500,
                  ),
                  const SizedBox(height: AppDimens.s12),
                  Text(
                    state.formattedDuration,
                    style: AppTextStyles.body(context),
                  ),
                  const SizedBox(height: AppDimens.s24),
                  const Spacer(),
                  _buildWaveAnimation(state),
                  const SizedBox(height: AppDimens.s40),
                  _buildControls(state),
                  const SizedBox(height: AppDimens.s40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(VoiceCallState state) {
    if (state.status == CallStatus.connecting) {
      return BdxConnectingRing(
        animation: _waveController,
        size: 220,
      );
    }

    final isActive = state.status == CallStatus.speaking ||
        state.status == CallStatus.listening;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final scale = isActive ? 1.0 + _waveController.value * 0.05 : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/logo.png',
        width: 170,
        height: 170,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.auto_awesome,
          color: Colors.white,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildWaveAnimation(VoiceCallState state) {
    final isActive = state.status == CallStatus.speaking ||
        state.status == CallStatus.listening;

    return BdxWaveVisualizer(
      animation: _waveController,
      active: isActive,
      width: 260,
      height: 70,
    );
  }

  Widget _buildControls(VoiceCallState state) {
    if (state.status == CallStatus.idle) {
      return _buildControlButton(
        icon: Icons.phone_in_talk,
        label: '重新接通',
        size: 64,
        color: AppColors.primary,
        onTap: () => _checkPermissionAndStart(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildControlButton(
          icon: state.isMuted ? Icons.mic_off : Icons.mic,
          label: state.isMuted ? '已静音' : '静音',
          size: 56,
          isActive: state.isMuted,
          onTap: () {
            context.read<VoiceCallBloc>().add(const VoiceCallToggleMute());
          },
        ),
        const SizedBox(width: AppDimens.s24),
        _buildControlButton(
          icon: Icons.call_end,
          label: '挂断',
          size: 76,
          color: AppColors.pink,
          pulse: true,
          onTap: () => _hangup(context),
        ),
        const SizedBox(width: AppDimens.s24),
        _buildControlButton(
          icon: state.isSpeaker ? Icons.volume_up : Icons.hearing,
          label: state.isSpeaker ? '免提' : '听筒',
          size: 56,
          isActive: state.isSpeaker,
          onTap: () {
            context.read<VoiceCallBloc>().add(const VoiceCallToggleSpeaker());
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double size,
    Color? color,
    bool isActive = false,
    bool pulse = false,
  }) {
    final colors = AppColors.of(context);
    final isHangup = color == AppColors.pink;
    final backgroundColor = color ??
        (isActive ? AppColors.primary : colors.glassWhite);

    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isHangup || isActive
              ? Colors.transparent
              : colors.borderSubtle,
        ),
        boxShadow: isHangup
            ? AppShadows.glowAccent(opacity: 0.45)
            : isActive
                ? AppShadows.glowPrimary(opacity: 0.35)
                : null,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.4),
    );

    if (pulse) {
      button = AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          final scale = 1.0 + sin(_waveController.value * 2 * pi) * 0.04;
          return Transform.scale(scale: scale, child: child);
        },
        child: button,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressScale(
          onTap: onTap,
          scale: 0.92,
          child: button,
        ),
        SizedBox(height: isHangup ? AppDimens.s10 : AppDimens.s8),
        Text(
          label,
          style: TextStyle(
            color: isHangup ? AppColors.pink : colors.textSecondary,
            fontSize: isHangup ? 13 : 12,
            fontWeight: isHangup ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _hangup(BuildContext context) {
    _durationTimer?.cancel();
    setState(() => _microphoneDenied = false);
    context.read<VoiceCallBloc>().add(const VoiceCallHangup());
  }

  void _goBack(BuildContext context) {
    _durationTimer?.cancel();
    context.read<VoiceCallBloc>().add(const VoiceCallHangup());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Widget _buildPermissionDenied() {
    final colors = AppColors.of(context);

    return SizedBox.expand(
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.s32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassCard(
                    borderRadius: AppDimens.r24,
                    padding: const EdgeInsets.all(AppDimens.s24),
                    child: Icon(
                      Icons.mic_off,
                      color: colors.textSecondary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppDimens.s20),
                  Text(
                    '需要麦克风权限才能进行语音通话',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title(context),
                  ),
                  const SizedBox(height: AppDimens.s8),
                  FutureBuilder<PermissionStatus>(
                    future: Permission.microphone.status,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      final isPermanent = status?.isPermanentlyDenied ?? false;
                      final isRestricted = status?.isRestricted ?? false;
                      final canRequest = status?.isDenied ?? false;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status != null)
                            Text(
                              isPermanent || isRestricted
                                  ? '权限已被永久拒绝，请前往系统设置手动开启'
                                  : '请点击下方按钮授权麦克风权限',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall(context),
                            ),
                          const SizedBox(height: AppDimens.s24),
                          BdxButton(
                            text: canRequest ? '重新请求权限' : '去系统设置开启',
                            expanded: true,
                            onTap: canRequest
                                ? _checkPermissionAndStart
                                : openAppSettings,
                          ),
                          const SizedBox(height: AppDimens.s12),
                          BdxButton(
                            text: '已开启，重新检测',
                            type: BdxButtonType.ghost,
                            expanded: true,
                            onTap: _checkPermissionAndStart,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: BdxIconButton(
                icon: Icons.arrow_back,
                onTap: () => _goBack(context),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
