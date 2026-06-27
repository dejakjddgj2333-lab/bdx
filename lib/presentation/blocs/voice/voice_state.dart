import 'package:equatable/equatable.dart';
import '../../../core/constants/conversation_voice.dart';

class VoiceState extends Equatable {
  final ConversationVoice voice;

  const VoiceState({this.voice = ConversationVoice.vivi});

  VoiceState copyWith({ConversationVoice? voice}) {
    return VoiceState(voice: voice ?? this.voice);
  }

  @override
  List<Object?> get props => [voice];
}
