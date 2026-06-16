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

  bool get isLoaded => config != null;

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
  bool _hasLoaded = false;

  VoiceCallSettingsCubit(this._repository, this._storage)
      : super(const VoiceCallSettingsState());

  /// 加载厂商/音色配置。已加载过时默认不再重复请求，除非 force=true。
  Future<void> load({bool force = false}) async {
    if (!force && _hasLoaded) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      final config = await _repository.getVoiceProviderConfig();
      final savedVoice = _storage.getVoiceCallVoice(config.provider);
      final selectedVoice = savedVoice ?? config.defaultVoice;
      _hasLoaded = true;
      emit(state.copyWith(
        config: config,
        selectedVoice: selectedVoice,
        isLoading: false,
      ));
    } catch (e) {
      _hasLoaded = true;
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> selectVoice(String voice) async {
    final config = state.config;
    if (config == null) return;
    await _storage.setVoiceCallVoice(config.provider, voice);
    emit(state.copyWith(selectedVoice: voice));
  }

  /// 当后台切换厂商等场景需要刷新时调用
  void resetLoaded() {
    _hasLoaded = false;
  }
}
