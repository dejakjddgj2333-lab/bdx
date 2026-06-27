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

/// 语音通话 Bloc（阶段二：方舟 Plan ASR/TTS 编排协议）
///
/// 新协议下，端点检测/打断/状态由后端编排器统一判定并下发 state 事件。
/// 前端只负责：发音频、收音频播放、按 state 切 UI、显示 asr.text/llm.text。
class VoiceCallBloc extends Bloc<VoiceCallEvent, VoiceCallState> {
  final WebSocketService _webSocketService;
  final AudioRecorderService _audioRecorderService;
  final AudioPlayerService _audioPlayerService;
  final VoiceCallSettingsCubit _voiceCallSettingsCubit;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _audioSubscription;
  Timer? _playerWatchdog;
  bool _playerFeedActive = false;

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
      // 0. 加载音色配置（失败不阻断，用后端默认）
      try {
        await _voiceCallSettingsCubit.load();
      } catch (e) {
        log('加载语音配置失败，使用默认: $e');
      }

      // 1. 初始化播放器
      try {
        await _audioPlayerService.init();
      } catch (e) {
        log('播放器初始化失败（不阻断）: $e');
      }

      // 2. 连接 WS，带音色
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
    _playerWatchdog?.cancel();
    _playerFeedActive = false;
    try {
      _webSocketService.sendStop();
    } catch (_) {}
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
    final newValue = !state.isMuted;
    log('静音切换: $newValue');
    emit(state.copyWith(isMuted: newValue));

    if (!state.status.isInCall) return;

    if (newValue) {
      await _audioRecorderService.stopRecording();
    } else {
      // 仅在 listening 状态恢复录音（speaking 时后端会处理打断，前端不强停麦）
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

  void _onMessageReceived(
    VoiceCallMessageReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    final type = event.message['type']?.toString() ?? '';
    print('🔴[bloc] 收到消息: $type, 内容: ${event.message}');

    switch (type) {
      case 'state':
        final s = event.message['state']?.toString() ?? '';
        switch (s) {
          case 'listening':
            emit(state.copyWith(status: CallStatus.listening, currentSpeaker: 'user'));
            _ensureRecording();
            break;
          case 'thinking':
            emit(state.copyWith(status: CallStatus.thinking, currentSpeaker: 'ai'));
            break;
          case 'speaking':
            emit(state.copyWith(status: CallStatus.speaking, currentSpeaker: 'ai'));
            _playerFeedActive = true;
            break;
          case 'interrupted':
            // 用户打断，回到聆听
            emit(state.copyWith(status: CallStatus.listening, currentSpeaker: 'user'));
            _ensureRecording();
            break;
          case 'idle':
            emit(state.copyWith(status: CallStatus.connected));
            break;
        }
        break;

      case 'asr.text':
        // 用户语音转写
        final text = event.message['text']?.toString() ?? '';
        emit(state.copyWith(currentText: text, currentSpeaker: 'user'));
        break;

      case 'llm.text':
        // AI 回复文本（增量）
        final text = event.message['text']?.toString() ?? '';
        emit(state.copyWith(currentText: text, currentSpeaker: 'ai'));
        break;

      case 'turn.end':
        // 一轮结束，回聆听
        emit(state.copyWith(status: CallStatus.listening, currentText: ''));
        break;

      case 'error':
        final msg = event.message['message']?.toString() ?? '未知错误';
        log('语音错误: $msg');
        emit(state.copyWith(error: msg));
        break;

      case 'closed':
        log('连接关闭');
        emit(state.copyWith(status: CallStatus.idle));
        break;
    }
  }

  void _onAudioReceived(
    VoiceCallAudioReceived event,
    Emitter<VoiceCallState> emit,
  ) {
    if (!_playerFeedActive) return;
    try {
      _audioPlayerService.handleAudioData(event.data);
    } catch (e) {
      log('播放音频失败: $e');
    }
  }

  void _onDurationTick(VoiceCallDurationTick event, Emitter<VoiceCallState> emit) {
    if (state.status.isInCall) {
      emit(state.copyWith(durationSeconds: state.durationSeconds + 1));
    }
  }

  void _onForceListening(_VoiceCallForceListening event, Emitter<VoiceCallState> emit) {
    emit(state.copyWith(status: CallStatus.listening));
    _ensureRecording();
  }

  /// 确保录音在跑（listening 时）。startRecording 内部已防重复启动。
  Future<void> _ensureRecording() async {
    if (state.isMuted) {
      print('🔴[bloc] 录音跳过：已静音');
      return;
    }
    print('🔴[bloc] 启动录音...');
    try {
      await _audioRecorderService.startRecording(
        onData: (data) {
          _blocAudioCount++;
          if (_blocAudioCount <= 3) print('🔴[bloc] 录音数据 #$_blocAudioCount, ${data.length} bytes');
          _webSocketService.sendAudio(data);
        },
      );
      print('🔴[bloc] 录音启动成功');
    } catch (e) {
      print('🔴[bloc] 启动录音失败: $e');
    }
  }
  int _blocAudioCount = 0;

  /// 播放器看门狗：长时间无音频输入时重置（避免卡死）
  void _startPlayerWatchdog() {
    _playerWatchdog?.cancel();
    _playerWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      // 简化：仅日志，不强制重置
    });
  }

  @override
  Future<void> close() {
    _playerWatchdog?.cancel();
    _playerFeedActive = false;
    return super.close();
  }
}
