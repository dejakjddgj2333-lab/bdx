import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/websocket_service.dart';

part 'voice_call_event.dart';
part 'voice_call_state.dart';

class VoiceCallBloc extends Bloc<VoiceCallEvent, VoiceCallState> {
  final WebSocketService _webSocketService;
  final AudioRecorderService _audioRecorderService;
  final AudioPlayerService _audioPlayerService;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _audioSubscription;
  Timer? _speakingWatchdog;
  Timer? _playerWatchdog;
  DateTime? _lastAudioDeltaTime;

  VoiceCallBloc(
    this._webSocketService,
    this._audioRecorderService,
    this._audioPlayerService,
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
      // 1. 先连 WebSocket，确保后端能收到连接请求并打印日志
      await _webSocketService.connect();
      log('WebSocket 已连接');

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
    log('处理消息: $type');

    // 追加调试日志，最多保留 30 条
    final logEntry = _formatDebugLog(type, msg);
    final newLogs = [...state.debugLogs, logEntry];
    if (newLogs.length > 30) newLogs.removeAt(0);
    emit(state.copyWith(debugLogs: newLogs));

    switch (type) {
      case 'session.created':
        log('session.created, 发送配置');
        _webSocketService.sendConfig();
        await Future.delayed(const Duration(milliseconds: 200));
        if (!state.isMuted) {
          log('启动录音');
          await _audioRecorderService.startRecording(
            onData: (data) => _webSocketService.sendAudio(data),
          );
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
          log('AI 开始播放语音, 提高 VAD threshold 到 0.65');
          emit(state.copyWith(status: CallStatus.speaking));
          _webSocketService.updateVadThreshold(0.65);
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
        _audioPlayerService.flushAccumulatedAudio();
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
    _speakingWatchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (state.status != CallStatus.speaking) {
        _speakingWatchdog?.cancel();
        return;
      }
      final lastDelta = _lastAudioDeltaTime;
      if (lastDelta != null &&
          DateTime.now().difference(lastDelta).inSeconds >= 6) {
        log('AI speaking 超过 6 秒无新音频, 强制重置为 listening');
        _lastAudioDeltaTime = null;
        _audioPlayerService.flushAccumulatedAudio();
        add(const _VoiceCallForceListening());
      }
    });
  }

  void _startPlayerWatchdog() {
    _playerWatchdog?.cancel();
    _playerWatchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_audioPlayerService.isStuck) {
        _audioPlayerService.forceReset();
      }
    });
  }

  String _formatDebugLog(String type, Map<String, dynamic> msg) {
    final time = DateTime.now().toString().substring(11, 19);
    switch (type) {
      case 'response.audio.delta':
        final delta = msg['delta']?.toString() ?? '';
        final bytes = delta.isNotEmpty ? (delta.length * 3) ~/ 4 : 0;
        return '[$time] $type · $bytes bytes';
      case 'response.audio_transcript.delta':
      case 'conversation.item.input_audio_transcription.delta':
        final text = msg['delta']?.toString() ?? msg['text']?.toString() ?? '';
        return '[$time] $type · "$text"';
      case 'error':
      case 'server.error':
        final err = msg['error']?.toString() ?? msg.toString();
        return '[$time] $type · $err';
      default:
        final preview = msg.toString();
        final trimmed = preview.length > 120 ? '${preview.substring(0, 120)}...' : preview;
        return '[$time] $type · $trimmed';
    }
  }

  @override
  Future<void> close() async {
    _speakingWatchdog?.cancel();
    _playerWatchdog?.cancel();
    await _messageSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _audioRecorderService.stopRecording();
    _audioPlayerService.cancelPlaying();
    _webSocketService.disconnect();
    return super.close();
  }
}
