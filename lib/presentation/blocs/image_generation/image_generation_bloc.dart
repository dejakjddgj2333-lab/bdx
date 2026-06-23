import 'dart:developer';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/image_model.dart';
import '../../../domain/entities/painting.dart';
import '../../../domain/repositories/image_generation_repository.dart';

part 'image_generation_event.dart';
part 'image_generation_state.dart';

class ImageGenerationBloc extends Bloc<ImageGenerationEvent, ImageGenerationState> {
  final ImageGenerationRepository _repository;

  ImageGenerationBloc(this._repository) : super(const ImageGenerationInitial()) {
    on<ImageGenerationLoaded>(_onLoaded);
    on<ImageGenerationModelSelected>(_onModelSelected);
    on<ImageGenerationSizeSelected>(_onSizeSelected);
    on<ImageGenerationStyleSelected>(_onStyleSelected);
    on<ImageGenerationPromptChanged>(_onPromptChanged);
    on<ImageGenerationNegativePromptChanged>(_onNegativePromptChanged);
    on<ImageGenerationSubmitted>(_onSubmitted);
    on<ImageGenerationHistoryLoaded>(_onHistoryLoaded);
  }

  Future<void> _onLoaded(
    ImageGenerationLoaded event,
    Emitter<ImageGenerationState> emit,
  ) async {
    try {
      final models = await _repository.getImageModels();
      final quota = await _repository.getImageQuota();
      final history = await _repository.getPaintings(pageSize: 20);

      ImageModel? selected;
      if (models.isNotEmpty) {
        selected = models.firstWhere(
          (m) => m.isDefault,
          orElse: () => models.first,
        );
      }

      emit(state.copyWith(
        models: models,
        selectedModel: selected,
        size: selected?.supportedSizes.isNotEmpty == true
            ? selected!.supportedSizes.first
            : null,
        style: selected?.supportedStyles.isNotEmpty == true
            ? selected!.supportedStyles.first
            : null,
        quotaLimit: quota.limit,
        quotaUsed: quota.used,
        history: history,
        clearError: true,
      ));
    } catch (e, stack) {
      log('加载绘图配置失败: $e', name: 'ImageGenerationBloc', error: e, stackTrace: stack);
      emit(state.copyWith(error: '加载失败: $e'));
    }
  }

  void _onModelSelected(
    ImageGenerationModelSelected event,
    Emitter<ImageGenerationState> emit,
  ) {
    final model = state.models.firstWhere(
      (m) => m.id == event.modelId,
      orElse: () => state.selectedModel ?? const ImageModel(id: '', name: '', provider: ''),
    );

    emit(state.copyWith(
      selectedModel: model,
      size: model.supportedSizes.isNotEmpty ? model.supportedSizes.first : null,
      style: model.supportedStyles.isNotEmpty ? model.supportedStyles.first : null,
      clearError: true,
    ));
  }

  void _onSizeSelected(
    ImageGenerationSizeSelected event,
    Emitter<ImageGenerationState> emit,
  ) {
    emit(state.copyWith(size: event.size, clearError: true));
  }

  void _onStyleSelected(
    ImageGenerationStyleSelected event,
    Emitter<ImageGenerationState> emit,
  ) {
    emit(state.copyWith(style: event.style, clearError: true));
  }

  void _onPromptChanged(
    ImageGenerationPromptChanged event,
    Emitter<ImageGenerationState> emit,
  ) {
    emit(state.copyWith(prompt: event.prompt, clearError: true));
  }

  void _onNegativePromptChanged(
    ImageGenerationNegativePromptChanged event,
    Emitter<ImageGenerationState> emit,
  ) {
    emit(state.copyWith(negativePrompt: event.negativePrompt, clearError: true));
  }

  Future<void> _onSubmitted(
    ImageGenerationSubmitted event,
    Emitter<ImageGenerationState> emit,
  ) async {
    if (state.isGenerating) return;
    if (state.prompt.trim().isEmpty) {
      emit(state.copyWith(error: '请输入图片描述'));
      return;
    }
    if (state.selectedModel == null) {
      emit(state.copyWith(error: '请先选择绘图模型'));
      return;
    }

    emit(state.copyWith(isGenerating: true, clearError: true));

    try {
      final painting = await _repository.generateImage(
        prompt: state.prompt.trim(),
        negativePrompt: state.negativePrompt.trim(),
        model: state.selectedModel!.id,
        size: state.size,
        style: state.style,
      );

      final quota = await _repository.getImageQuota();
      final newHistory = [painting, ...state.history];

      emit(state.copyWith(
        isGenerating: false,
        latest: painting,
        history: newHistory,
        quotaLimit: quota.limit,
        quotaUsed: quota.used,
        prompt: '',
        clearError: true,
      ));
    } catch (e, stack) {
      log('图片生成失败: $e', name: 'ImageGenerationBloc', error: e, stackTrace: stack);
      emit(state.copyWith(
        isGenerating: false,
        error: '图片生成失败: $e',
      ));
    }
  }

  Future<void> _onHistoryLoaded(
    ImageGenerationHistoryLoaded event,
    Emitter<ImageGenerationState> emit,
  ) async {
    try {
      final history = await _repository.getPaintings(
        page: event.page,
        pageSize: 20,
      );
      emit(state.copyWith(
        history: event.page == 1 ? history : [...state.history, ...history],
        clearError: true,
      ));
    } catch (e, stack) {
      log('加载历史作品失败: $e', name: 'ImageGenerationBloc', error: e, stackTrace: stack);
      emit(state.copyWith(error: '加载历史作品失败: $e'));
    }
  }
}
