import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/voice_call/voice_call_bloc.dart';

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

    // 先查当前状态，避免已永久拒绝时反复弹窗
    debugPrint('VoiceCall: 检查麦克风权限状态...');
    final current = await Permission.microphone.status;
    debugPrint('VoiceCall: 当前麦克风权限状态 = $current');
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

    debugPrint('VoiceCall: 请求麦克风权限...');
    final status = await Permission.microphone.request();
    debugPrint('VoiceCall: 请求后麦克风权限状态 = $status');
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<VoiceCallBloc, VoiceCallState>(
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
                  child: IconButton(
                    onPressed: () => _goBack(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const Spacer(),
                _buildAvatar(state),
                const SizedBox(height: 32),
                Text(
                  state.statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.formattedDuration,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                const Spacer(),
                _buildWaveAnimation(),
                const SizedBox(height: 40),
                _buildControls(state),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(VoiceCallState state) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final scale =
            state.status == CallStatus.speaking ||
                state.status == CallStatus.listening
            ? 1.0 + _waveController.value * 0.05
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveAnimation() {
    return SizedBox(
      height: 70,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              final delay = index * 0.2;
              final value = (_waveController.value + delay) % 1.0;
              final height = 20 + value * 40;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.6 + value * 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildControls(VoiceCallState state) {
    // 通话已结束，显示重新接通按钮
    if (state.status == CallStatus.idle) {
      return _buildControlButton(
        icon: Icons.phone_in_talk,
        label: '重新接通',
        color: AppColors.primary,
        onTap: () => _checkPermissionAndStart(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: state.isMuted ? Icons.mic_off : Icons.mic,
          label: state.isMuted ? '静音' : '静音',
          isActive: state.isMuted,
          onTap: () =>
              context.read<VoiceCallBloc>().add(const VoiceCallToggleMute()),
        ),
        _buildControlButton(
          icon: Icons.call_end,
          label: '挂断',
          color: AppColors.pink,
          onTap: () => _hangup(context),
        ),
        _buildControlButton(
          icon: state.isSpeaker ? Icons.volume_up : Icons.hearing,
          label: state.isSpeaker ? '免提' : '听筒',
          isActive: state.isSpeaker,
          onTap: () =>
              context.read<VoiceCallBloc>().add(const VoiceCallToggleSpeaker()),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color:
                  color ??
                  (isActive ? AppColors.primary : AppColors.glassWhite),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  void _hangup(BuildContext context) {
    _durationTimer?.cancel();
    setState(() => _microphoneDenied = false);
    context.read<VoiceCallBloc>().add(const VoiceCallHangup());
    // 挂断后停留在当前页，不返回上一页
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
    return SizedBox.expand(
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_off, color: AppColors.textSecondary, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    '需要麦克风权限才能进行语音通话',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 8),
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
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 24),
                          if (canRequest)
                            ElevatedButton(
                              onPressed: _checkPermissionAndStart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('重新请求权限'),
                            )
                          else
                            ElevatedButton(
                              onPressed: openAppSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('去系统设置开启'),
                            ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => _checkPermissionAndStart(),
                            child: const Text(
                              '已开启，重新检测',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
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
              child: IconButton(
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
