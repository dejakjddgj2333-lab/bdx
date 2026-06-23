part of 'image_generation_bloc.dart';

abstract class ImageGenerationState extends Equatable {
  final List<ImageModel> models;
  final ImageModel? selectedModel;
  final String prompt;
  final String negativePrompt;
  final String? size;
  final String? style;
  final bool isGenerating;
  final List<Painting> history;
  final int quotaLimit;
  final int quotaUsed;
  final Painting? latest;
  final String? error;

  const ImageGenerationState({
    this.models = const [],
    this.selectedModel,
    this.prompt = '',
    this.negativePrompt = '',
    this.size,
    this.style,
    this.isGenerating = false,
    this.history = const [],
    this.quotaLimit = 0,
    this.quotaUsed = 0,
    this.latest,
    this.error,
  });

  ImageGenerationState copyWith({
    List<ImageModel>? models,
    ImageModel? selectedModel,
    String? prompt,
    String? negativePrompt,
    String? size,
    String? style,
    bool? isGenerating,
    List<Painting>? history,
    int? quotaLimit,
    int? quotaUsed,
    Painting? latest,
    String? error,
    bool clearError = false,
  });

  @override
  List<Object?> get props => [
        models,
        selectedModel,
        prompt,
        negativePrompt,
        size,
        style,
        isGenerating,
        history,
        quotaLimit,
        quotaUsed,
        latest,
        error,
      ];
}

class ImageGenerationInitial extends ImageGenerationState {
  const ImageGenerationInitial() : super();

  @override
  ImageGenerationState copyWith({
    List<ImageModel>? models,
    ImageModel? selectedModel,
    String? prompt,
    String? negativePrompt,
    String? size,
    String? style,
    bool? isGenerating,
    List<Painting>? history,
    int? quotaLimit,
    int? quotaUsed,
    Painting? latest,
    String? error,
    bool clearError = false,
  }) {
    return ImageGenerationUpdated(
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      size: size ?? this.size,
      style: style ?? this.style,
      isGenerating: isGenerating ?? this.isGenerating,
      history: history ?? this.history,
      quotaLimit: quotaLimit ?? this.quotaLimit,
      quotaUsed: quotaUsed ?? this.quotaUsed,
      latest: latest ?? this.latest,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ImageGenerationUpdated extends ImageGenerationState {
  const ImageGenerationUpdated({
    super.models,
    super.selectedModel,
    super.prompt,
    super.negativePrompt,
    super.size,
    super.style,
    super.isGenerating,
    super.history,
    super.quotaLimit,
    super.quotaUsed,
    super.latest,
    super.error,
  });

  @override
  ImageGenerationState copyWith({
    List<ImageModel>? models,
    ImageModel? selectedModel,
    String? prompt,
    String? negativePrompt,
    String? size,
    String? style,
    bool? isGenerating,
    List<Painting>? history,
    int? quotaLimit,
    int? quotaUsed,
    Painting? latest,
    String? error,
    bool clearError = false,
  }) {
    return ImageGenerationUpdated(
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      size: size ?? this.size,
      style: style ?? this.style,
      isGenerating: isGenerating ?? this.isGenerating,
      history: history ?? this.history,
      quotaLimit: quotaLimit ?? this.quotaLimit,
      quotaUsed: quotaUsed ?? this.quotaUsed,
      latest: latest ?? this.latest,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
