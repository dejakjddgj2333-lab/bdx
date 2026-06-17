import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/chat_repository.dart';

part 'model_state.dart';

/// 全局模型列表缓存
///
/// 在首页提前加载模型列表，避免进入聊天页后发送首条消息时
/// 还需要等待模型接口返回默认模型。
class ModelCubit extends Cubit<ModelState> {
  final ChatRepository _chatRepository;

  ModelCubit(this._chatRepository) : super(const ModelState());

  Future<void> loadModels() async {
    if (state.isLoading) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      final models = await _chatRepository.getModels();
      final defaultModel = models.firstWhere(
        (m) => m['isDefault'] == true,
        orElse: () => models.isNotEmpty ? models.first : const {},
      );
      emit(state.copyWith(
        models: models,
        defaultModelId: defaultModel['id']?.toString(),
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
