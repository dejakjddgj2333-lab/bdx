import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/conversation_voice.dart';
import '../../../data/datasources/local/hive_storage.dart';
import 'voice_state.dart';

class VoiceCubit extends Cubit<VoiceState> {
  final HiveStorage _storage;

  VoiceCubit(this._storage) : super(const VoiceState());

  /// 从本地存储加载声音偏好
  Future<void> load() async {
    final saved = _storage.getConversationVoice();
    final voice = ConversationVoiceX.fromString(saved);
    emit(VoiceState(voice: voice));
  }

  /// 设置并持久化声音偏好
  Future<void> setVoice(ConversationVoice voice) async {
    await _storage.setConversationVoice(voice.name);
    emit(VoiceState(voice: voice));
  }
}
