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
  DateTime? _lastAudioDeltaTime;

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

      // 1. 先连 WebSocket，把 App 选择的音色带在 URL 参数里
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

      // 2. 再初始化音频播放器；如果这里失败也不应阻断整个通话
      try {
        await _audioPlayerService.init();
        log('音频播放器初始化完成');
      } catch (audioErr) {
        log('音频播放器初始化失败（不影响连接）: $audioErr');
      }

      _startPlayerWatchdog();
    } catch (e) {
      log('通话连接失败: $e');
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
        if (!state.isMuted) {
          log('启动录音');
          await _audioRecorderService.startRecording(
            onData: (data) => _webSocketService.sendAudio(data),
          );
          // record 插件启动录音时会重新配置 AVAudioSession，可能覆盖我们的
          // defaultToSpeaker，导致声音从听筒输出。录音启动后重新应用一次输出路由。
          log('录音已启动，重新应用音频输出路由: speaker=${state.isSpeaker}');
          await _audioPlayerService.setSpeaker(state.isSpeaker);
        }
        emit(state.copyWith(status: CallStatus.connected));
        await Future.delayed(const Duration(milliseconds: 300));
        if (state.status == CallStatus.connected) {
          emit(state.copyWith(status: CallStatus.listening));
        }
        break;

      case 'input_audio_buffer.speech_started':
      case 'speech_started':
        log('检测到用户开始说话');
        // 服务端处理打断，客户端不停止本地播放，只切换状态
        emit(state.copyWith(status: CallStatus.listening));
        _webSocketService.updateVadThreshold(0.5);
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
          log('AI 开始播放语音, VAD threshold 0.6，兼顾打断与回音抑制');
          emit(state.copyWith(status: CallStatus.speaking));
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
        emit(state.copyWith(status: CallStatus.listening));
        _webSocketService.updateVadThreshold(0.5);
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
    }
  }

  void _startSpeakingWatchdog() {
    _speakingWatchdog?.cancel();
    _speakingWatchdog = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (state.status != CallStatus.speaking) {
        _speakingWatchdog?.cancel();
        return;
      }
      final lastDelta = _lastAudioDeltaTime;
      if (lastDelta != null &&
          DateTime.now().difference(lastDelta).inSeconds >= 6) {
        log('AI speaking 超过 6 秒无新音频, 强制重置为 listening');
        _lastAudioDeltaTime = null;
        await _audioPlayerService.flushAccumulatedAudio();
        add(const _VoiceCallForceListening());
      }
    });
  }

  void _startPlayerWatchdog() {
    _playerWatchdog?.cancel();
    _playerWatchdog = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_audioPlayerService.isStuck) {
        await _audioPlayerService.forceReset();
      }
    });
  }

  @override
  Future<void> close() async {
    _speakingWatchdog?.cancel();
    _playerWatchdog?.cancel();
    await _messageSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _audioRecorderService.stopRecording();
    await _audioPlayerService.cancelPlaying();
    _webSocketService.disconnect();
    return super.close();
  }
}
