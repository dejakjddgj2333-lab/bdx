part of 'voice_call_bloc.dart';

abstract class VoiceCallEvent extends Equatable {
  const VoiceCallEvent();

  @override
  List<Object?> get props => [];
}

class VoiceCallStarted extends VoiceCallEvent {
  const VoiceCallStarted();
}

class VoiceCallHangup extends VoiceCallEvent {
  const VoiceCallHangup();
}

class VoiceCallToggleMute extends VoiceCallEvent {
  const VoiceCallToggleMute();
}

class VoiceCallToggleSpeaker extends VoiceCallEvent {
  const VoiceCallToggleSpeaker();
}

class VoiceCallMessageReceived extends VoiceCallEvent {
  final Map<String, dynamic> message;

  const VoiceCallMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class VoiceCallAudioReceived extends VoiceCallEvent {
  final Uint8List data;

  const VoiceCallAudioReceived(this.data);

  @override
  List<Object?> get props => [data];
}

class VoiceCallDurationTick extends VoiceCallEvent {
  const VoiceCallDurationTick();
}

class _VoiceCallForceListening extends VoiceCallEvent {
  const _VoiceCallForceListening();
}
