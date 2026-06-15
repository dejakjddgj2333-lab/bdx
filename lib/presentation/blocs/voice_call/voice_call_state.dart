part of 'voice_call_bloc.dart';

enum CallStatus {
  idle,
  connecting,
  connected,
  listening,
  thinking,
  speaking,
  error,
}

extension CallStatusX on CallStatus {
  bool get isInCall =>
      this == CallStatus.connected ||
      this == CallStatus.listening ||
      this == CallStatus.thinking ||
      this == CallStatus.speaking;
}

class VoiceCallState extends Equatable {
  final CallStatus status;
  final String currentSpeaker;
  final String currentText;
  final bool isMuted;
  final bool isSpeaker;
  final int durationSeconds;
  final String? error;
  final List<String> playerLogs;

  const VoiceCallState({
    this.status = CallStatus.idle,
    this.currentSpeaker = 'ai',
    this.currentText = '',
    this.isMuted = false,
    this.isSpeaker = true,
    this.durationSeconds = 0,
    this.error,
    this.playerLogs = const [],
  });

  String get statusText {
    switch (status) {
      case CallStatus.idle:
        return '准备通话';
      case CallStatus.connecting:
        return '连接中...';
      case CallStatus.connected:
        return '已接通';
      case CallStatus.listening:
        return '聆听中';
      case CallStatus.thinking:
        return '思考中';
      case CallStatus.speaking:
        return '说话中';
      case CallStatus.error:
        return '连接失败';
    }
  }

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  VoiceCallState copyWith({
    CallStatus? status,
    String? currentSpeaker,
    String? currentText,
    bool? isMuted,
    bool? isSpeaker,
    int? durationSeconds,
    String? error,
    List<String>? playerLogs,
  }) {
    return VoiceCallState(
      status: status ?? this.status,
      currentSpeaker: currentSpeaker ?? this.currentSpeaker,
      currentText: currentText ?? this.currentText,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      error: error,
      playerLogs: playerLogs ?? this.playerLogs,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentSpeaker,
        currentText,
        isMuted,
        isSpeaker,
        durationSeconds,
        error,
        playerLogs,
      ];
}
