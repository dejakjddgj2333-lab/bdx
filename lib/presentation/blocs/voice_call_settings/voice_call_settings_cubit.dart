import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/datasources/local/hive_storage.dart';
import '../../../domain/entities/voice_provider_config.dart';
import '../../../domain/repositories/chat_repository.dart';

class VoiceCallSettingsState extends Equatable {
  final VoiceProviderConfig? config;
  final String? selectedVoice;
  final bool isLoading;
  final String? error;

  const VoiceCallSettingsState({
    this.config,
    this.selectedVoice,
    this.isLoading = false,
    this.error,
  });

  VoiceCallSettingsState copyWith({
    VoiceProviderConfig? config,
    String? selectedVoice,
    bool? isLoading,
    String? error,
  }) {
    return VoiceCallSettingsState(
      config: config ?? this.config,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [config, selectedVoice, isLoading, error];
}

class VoiceCallSettingsCubit extends Cubit<VoiceCallSettingsState> {
  final ChatRepository _repository;
  final HiveStorage _storage;

  VoiceCallSettingsCubit(this._repository, this._storage)
      : super(const VoiceCallSettingsState(isLoading: true));

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final config = await _repository.getVoiceProviderConfig();
      final savedVoice = _storage.getVoiceCallVoice(config.provider);
      final selectedVoice = savedVoice ?? config.defaultVoice;
      emit(state.copyWith(
        config: config,
        selectedVoice: selectedVoice,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> selectVoice(String voice) async {
    final config = state.config;
    if (config == null) return;
    await _storage.setVoiceCallVoice(config.provider, voice);
    emit(state.copyWith(selectedVoice: voice));
  }
}
