part of 'image_generation_bloc.dart';

abstract class ImageGenerationEvent extends Equatable {
  const ImageGenerationEvent();

  @override
  List<Object?> get props => [];
}

class ImageGenerationLoaded extends ImageGenerationEvent {
  const ImageGenerationLoaded();
}

class ImageGenerationModelSelected extends ImageGenerationEvent {
  final String modelId;

  const ImageGenerationModelSelected(this.modelId);

  @override
  List<Object?> get props => [modelId];
}

class ImageGenerationSizeSelected extends ImageGenerationEvent {
  final String size;

  const ImageGenerationSizeSelected(this.size);

  @override
  List<Object?> get props => [size];
}

class ImageGenerationStyleSelected extends ImageGenerationEvent {
  final String style;

  const ImageGenerationStyleSelected(this.style);

  @override
  List<Object?> get props => [style];
}

class ImageGenerationPromptChanged extends ImageGenerationEvent {
  final String prompt;

  const ImageGenerationPromptChanged(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

class ImageGenerationNegativePromptChanged extends ImageGenerationEvent {
  final String negativePrompt;

  const ImageGenerationNegativePromptChanged(this.negativePrompt);

  @override
  List<Object?> get props => [negativePrompt];
}

class ImageGenerationSubmitted extends ImageGenerationEvent {
  const ImageGenerationSubmitted();
}

class ImageGenerationHistoryLoaded extends ImageGenerationEvent {
  final int page;

  const ImageGenerationHistoryLoaded({this.page = 1});

  @override
  List<Object?> get props => [page];
}
