import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/websocket_service.dart';
import '../voice_call_settings/voice_call_settings_cubit.dart';

part 'voice_call_event.dart';
part 'voice_call_state.dart';

class VoiceCallBloc extends Bloc<VoiceCallEvent, VoiceCallState> {
  final WebSocketService _webSocketService;
  final AudioRecorderService _audioRecorderService;
  final AudioPlayerService _audioPlayerService;
  final VoiceCallSettingsCubit _voiceCallSettingsCubit;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _audioSubscription;
  Timer? _speakingWatchdog;
  Timer? _playerWatchdog;
  Timer? _micResumeTimer;
  Timer? _vadThresholdTimer;
  DateTime? _lastAudioDeltaTime;
  bool _micPausedForAi = false;
  bool _isResettingPlayer = false;

  /// AI 播放结束后，等缓冲排空再继续等多久才恢复麦克风（ms）
  static const int _aiResumeTailMs = 800;

  /// AI 播放结束后恢复麦克风时丢弃前 N ms，避免发送房间混响
  static const int _aiResumeDropMs = 250;

  /// 用户打断时先停麦多久，让扬声器尾音衰减（ms）
  static const int _interruptMuteMs = 150;

  /// 用户打断恢复麦克风后丢弃前 N ms
  static const int _interruptDropMs = 200;

  /// 打断后多久才把 VAD threshold 降到正常值（ms）
  static const int _postInterruptVadDelayMs = 500;

  /// response.done 后多久把 VAD threshold 降到正常值（ms）
  static const int _postAiVadDelayMs = 600;

  VoiceCallBloc(
    this._webSocketService,
    this._audioRecorderService,
    this._audioPlayerService,
    this._voiceCallSettingsCubit,
  ) : super(const VoiceCallState()) {
    on<VoiceCallStarted>(_onStarted);
    on<VoiceCallHangup>(_onHangup);
    on<VoiceCallToggleMute>(_onToggleMute);
    on<VoiceCallToggleSpeaker>(_onToggleSpeaker);
    on<VoiceCallMessageReceived>(_onMessageReceived);
    on<VoiceCallAudioReceived>(_onAudioReceived);
    on<VoiceCallDurationTick>(_onDurationTick);
    on<_VoiceCallForceListening>(_onForceListening);
  }

  Future<void> _onStarted(
    VoiceCallStarted event,
    Emitter<VoiceCallState> emit,
  ) async {
    emit(state.copyWith(status: CallStatus.connecting));
    log('通话开始连接');

    try {
      // 0. 加载语音通话厂商/音色配置（失败不阻断连接，使用后端默认）
      try {
        await _voiceCallSettingsCubit.load();
        final settingsState = _voiceCallSettingsCubit.state;
        log('当前语音厂商: ${settingsState.config?.provider}, 音色: ${settingsState.selectedVoice ?? settingsState.config?.defaultVoice}');
      } catch (configErr) {
        log('加载语音通话配置失败，使用默认音色: $configErr');
      }

      // 1. 先初始化音频播放器，确保 WebSocket 一来音频就能直接进缓冲
      try {
        await _audioPlayerService.init();
        log('音频播放器初始化完成');
      } catch (audioErr) {
        log('音频播放器初始化失败（不影响连接）: $audioErr');
      }

      // 2. 再连 WebSocket，把 App 选择的音色带在 URL 参数里
      final settingsState = _voiceCallSettingsCubit.state;
      final voice = settingsState.selectedVoice ?? settingsState.config?.defaultVoice;
      await _webSocketService.connect(voice: voice);
      log('WebSocket 已连接, voice=$voice');

      _messageSubscription = _webSocketService.messageStream.listen(
        (msg) => add(VoiceCallMessageReceived(msg)),
      );
      _audioSubscription = _webSocketService.audioStream.listen(
        (data) => add(VoiceCallAudioReceived(Uint8List.fromList(data))),
      );

      _startPlayerWatchdog();
    } catch (e) {
      log('通话连接失败: $e');
      if (isClosed) return;
      emit(state.copyWith(status: CallStatus.error, error: e.toString()));
    }
  }

  Future<void> _onHangup(
    VoiceCallHangup event,
    Emitter<VoiceCallState> emit,
  ) async {
    log('通话挂断');
    _speakingWatchdog?.cancel();
    _playerWatchdog?.cancel();
    _micResumeTimer?.cancel();
    _micPausedForAi = false;
    _isResettingPlayer = false;
    await _audioRecorderService.stopRecording();
    await _audioPlayerService.dispose();
    _webSocketService.disconnect();
    await _messageSubscription?.cancel();
    await _audioSubscription?.cancel();
    emit(const VoiceCallState());
  }

  Future<void> _onToggleMute(
    VoiceCallToggleMute event,
    Emitter<VoiceCallState> emit,
  ) async {
    _micResumeTimer?.cancel();
    final newValue = !state.isMuted;
    log('静音切换: $newValue');
    emit(state.copyWith(isMuted: newValue));

    if (!state.status.isInCall) return;

    if (newValue) {
      _micResumeTimer?.cancel();
      _micPausedForAi = false;
      await _audioRecorderService.stopRecording();
    } else if (state.status != CallStatus.speaking) {
      // AI 说话时先不打开麦克风，等 AI 说完再自动恢复，避免回音。
      await _audioRecorderService.startRecording(
        onData: (data) => _webSocketService.sendAudio(data),
      );
    }
  }

  Future<void> _onToggleSpeaker(
    VoiceCallToggleSpeaker event,
    Emitter<VoiceCallState> emit,
  ) async {
    final newValue = !state.isSpeaker;
    log('免提切换: $newValue');
    await _audioPlayerService.setSpeaker(newValue);
    emit(state.copyWith(isSpeaker: newValue));
  }

  Future<void> _onMessageReceived(
    VoiceCallMessageReceived event,
    Emitter<VoiceCallState> emit,
  ) async {
    final msg = event.message;
    final type = msg['type']?.toString() ?? '';

    switch (type) {
      case 'session.created':
        log('session.created, 发送配置');
        final settingsState = _voiceCallSettingsCubit.state;
        final voice = settingsState.selectedVoice ?? settingsState.config?.defaultVoice;
        _webSocketService.sendConfig(voice: voice);
        await Future.delayed(const Duration(milliseconds: 200));
        if (isClosed) return;
        if (!state.isMuted) {
          log('启动录音');
          await _audioRecorderService.startRecording(
            onData: (data) => _webSocketService.sendAudio(data),
          );
        }
        emit(state.copyWith(status: CallStatus.connected));
        await Future.delayed(const Duration(milliseconds: 300));
        if (isClosed) return;
        if (state.status == CallStatus.connected) {
          emit(state.copyWith(status: CallStatus.listening));
        }
        break;

      case 'input_audio_buffer.speech_started':
      case 'speech_started':
        log('检测到用户开始说话，清空 AI 播放并做回声保护');
        _speakingWatchdog?.cancel();
        _lastAudioDeltaTime = null;
        _micResumeTimer?.cancel();
        await _audioPlayerService.clearBuffer();
        if (isClosed) return;
        emit(state.copyWith(status: CallStatus.listening));
        _scheduleVadThresholdDrop(
          initial: 0.5,
          target: 0.3,
          delay: const Duration(milliseconds: _postInterruptVadDelayMs),
        );
        // 如果 AI 说话时麦克风被暂停，现在需要恢复，但要先等扬声器尾音衰减。
        if (!state.isMuted &&
            _micPausedForAi &&
            state.status.isInCall &&
            state.status != CallStatus.speaking) {
          _micPausedForAi = false;
          log('打断：先停麦 $_interruptMuteMs ms 衰减尾音');
          await _audioRecorderService.stopRecording();
          _micResumeTimer = Timer(
            const Duration(milliseconds: _interruptMuteMs),
            () async {
              if (isClosed) return;
              if (state.isMuted ||
                  !state.status.isInCall ||
                  state.status == CallStatus.speaking) {
                return;
              }
              log('打断保护期结束，恢复麦克风并丢弃前 $_interruptDropMs ms');
              await _audioRecorderService.startRecording(
                onData: (data) => _webSocketService.sendAudio(data),
                dropInitial: const Duration(milliseconds: _interruptDropMs),
              );
            },
          );
        } else {
          _micPausedForAi = false;
        }
        break;

      case 'input_audio_buffer.speech_stopped':
      case 'speech_stopped':
        log('检测到用户停止说话');
        emit(state.copyWith(status: CallStatus.thinking));
        break;

      case 'conversation.item.input_audio_transcription.delta':
        emit(state.copyWith(
          currentSpeaker: 'user',
          currentText: '${msg['text'] ?? ''}${msg['stash'] ?? ''}',
        ));
        break;

      case 'conversation.item.input_audio_transcription.completed':
        emit(state.copyWith(
          currentSpeaker: 'user',
          currentText: msg['transcript']?.toString() ?? '',
          status: CallStatus.thinking,
        ));
        break;

      case 'response.created':
        log('AI 开始响应');
        if (state.status == CallStatus.speaking) {
          log('新响应开始时 AI 仍在播放，清空旧音频');
          await _audioPlayerService.clearBuffer();
          if (isClosed) return;
        }
        _speakingWatchdog?.cancel();
        _lastAudioDeltaTime = null;
        emit(state.copyWith(status: CallStatus.thinking));
        break;

      case 'response.audio_transcript.delta':
        emit(state.copyWith(
          currentSpeaker: 'ai',
          currentText: state.currentText + (msg['delta']?.toString() ?? ''),
        ));
        break;

      case 'response.audio_transcript.done':
        emit(state.copyWith(
          currentSpeaker: 'ai',
          currentText: msg['transcript']?.toString() ?? '',
        ));
        break;

      case 'response.audio.delta':
        _lastAudioDeltaTime = DateTime.now();
        if (state.status != CallStatus.speaking) {
          log('AI 开始播放语音，暂停麦克风避免回音循环');
          emit(state.copyWith(status: CallStatus.speaking));
          if (!state.isMuted) {
            _micPausedForAi = true;
            await _audioRecorderService.stopRecording();
            if (isClosed) return;
          }
          _webSocketService.updateVadThreshold(0.6);
          _startSpeakingWatchdog();
        }
        break;

      case 'response.audio.done':
        log('AI 语音片段结束');
        break;

      case 'response.done':
        log('AI 响应结束, 重置为 listening');
        _speakingWatchdog?.cancel();
        _lastAudioDeltaTime = null;
        await _audioPlayerService.flushAccumulatedAudio();
        if (isClosed) return;
        emit(state.copyWith(status: CallStatus.listening));
        _scheduleVadThresholdDrop(
          initial: 0.5,
          target: 0.3,
          delay: const Duration(milliseconds: _postAiVadDelayMs),
        );
        if (_micPausedForAi && !state.isMuted) {
          _micResumeTimer?.cancel();
          _scheduleMicResumeAfterAiSpeech();
        }
        break;

      case 'error':
      case 'server.error':
        log('通话错误: ${msg['error']}');
        emit(state.copyWith(error: msg['error']?.toString() ?? '通话出错'));
        break;

      case 'closed':
        log('连接已关闭');
        emit(state.copyWith(status: CallStatus.error));
        break;
    }
  }

  void _onAudioReceived(
    VoiceCallAudioReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    _audioPlayerService.handleAudioData(event.data);
  }

  void _onDurationTick(
    VoiceCallDurationTick event,
    Emitter<VoiceCallState> emit,
  ) {
    final seconds = state.durationSeconds + 1;
    emit(state.copyWith(durationSeconds: seconds));
  }

  void _onForceListening(
    _VoiceCallForceListening event,
    Emitter<VoiceCallState> emit,
  ) {
    if (state.status == CallStatus.speaking) {
      emit(state.copyWith(status: CallStatus.listening));
      _webSocketService.updateVadThreshold(0.5);
      //  watchdog 强制切回 listening 时，也要把麦克风恢复，否则界面显示“聆听中”但用户说不了话。
      if (_micPausedForAi && !state.isMuted && state.status.isInCall) {
        _micResumeTimer?.cancel();
        _scheduleMicResumeAfterAiSpeech();
      }
    }
  }

  void _scheduleVadThresholdDrop({
    required double initial,
    required double target,
    required Duration delay,
  }) {
    _vadThresholdTimer?.cancel();
    _webSocketService.updateVadThreshold(initial);
    _vadThresholdTimer = Timer(delay, () {
      if (isClosed) return;
      log('VAD threshold 从 $initial 降至 $target');
      _webSocketService.updateVadThreshold(target);
    });
  }

  /// AI 播放结束后，等播放缓冲真正排空并再留一段尾音，再恢复麦克风。
  void _scheduleMicResumeAfterAiSpeech() {
    _micResumeTimer?.cancel();
    _micResumeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        if (isClosed) {
          _micResumeTimer?.cancel();
          return;
        }
        if (!_micPausedForAi) {
          _micResumeTimer?.cancel();
          return;
        }
        if (state.isMuted ||
            !state.status.isInCall ||
            state.status == CallStatus.speaking) {
          _micResumeTimer?.cancel();
          return;
        }
        if (_audioPlayerService.isPlaybackActive) {
          // 仍在播放或刚播完，继续等待。
          return;
        }
        // 缓冲已排空，再等尾音保护期。
        _micResumeTimer?.cancel();
        await Future.delayed(
          const Duration(milliseconds: _aiResumeTailMs),
        );
        if (isClosed) return;
        if (!_micPausedForAi ||
            state.isMuted ||
            !state.status.isInCall ||
            state.status == CallStatus.speaking) {
          _micPausedForAi = false;
          return;
        }
        log('AI 播放排干且尾音消退后，恢复麦克风');
        await _audioRecorderService.startRecording(
          onData: (data) => _webSocketService.sendAudio(data),
          dropInitial: const Duration(milliseconds: _aiResumeDropMs),
        );
        _micPausedForAi = false;
      },
    );
  }

  void _startSpeakingWatchdog() {
    _speakingWatchdog?.cancel();
    _speakingWatchdog = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (isClosed) return;
      if (state.status != CallStatus.speaking) {
        _speakingWatchdog?.cancel();
        return;
      }
      final lastDelta = _lastAudioDeltaTime;
      final noDeltaSeconds = lastDelta == null
          ? 0
          : DateTime.now().difference(lastDelta).inSeconds;

      // AI 仍在播放或缓冲未空时，给更多容忍时间，避免播放还没完就误切到 listening。
      final isStillPlaying = _audioPlayerService.isPlaybackActive;
      final thresholdSeconds = isStillPlaying ? 12 : 6;

      if (noDeltaSeconds >= thresholdSeconds) {
        log('AI speaking 超过 $thresholdSeconds 秒无新音频，强制重置为 listening');
        _lastAudioDeltaTime = null;
        await _audioPlayerService.flushAccumulatedAudio();
        if (isClosed) return;
        add(const _VoiceCallForceListening());
      }
    });
  }

  void _startPlayerWatchdog() {
    _playerWatchdog?.cancel();
    _playerWatchdog = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (isClosed) return;
      if (!_audioPlayerService.isStuck) return;
      if (_isResettingPlayer) return;
      _isResettingPlayer = true;

      log('AudioPlayer 长时间无数据，先停录音再强制重置');
      await _audioRecorderService.stopRecording();
      await _audioPlayerService.forceReset();

      if (isClosed) {
        _isResettingPlayer = false;
        return;
      }
      final currentStatus = state.status;
      final muted = state.isMuted;
      if (!muted &&
          currentStatus.isInCall &&
          currentStatus != CallStatus.speaking) {
        log('播放器重置后恢复麦克风');
        await _audioRecorderService.startRecording(
          onData: (data) => _webSocketService.sendAudio(data),
        );
      } else if (currentStatus == CallStatus.speaking) {
        // AI 正在说话时麦克风本来就应暂停，由 response.done 统一恢复。
        _micPausedForAi = true;
      }
      _isResettingPlayer = false;
    });
  }

  @override
  Future<void> close() async {
    _speakingWatchdog?.cancel();
    _playerWatchdog?.cancel();
    _micResumeTimer?.cancel();
    _vadThresholdTimer?.cancel();
    _micPausedForAi = false;
    _isResettingPlayer = false;

    try {
      await _messageSubscription?.cancel();
    } catch (_) {}
    try {
      await _audioSubscription?.cancel();
    } catch (_) {}
    try {
      await _audioRecorderService.stopRecording();
    } catch (_) {}
    try {
      await _audioPlayerService.dispose();
    } catch (_) {}
    try {
      _webSocketService.disconnect();
    } catch (_) {}

    return super.close();
  }
}
