part of 'model_cubit.dart';

class ModelState extends Equatable {
  final List<Map<String, dynamic>> models;
  final String? defaultModelId;
  final bool isLoading;
  final String? error;

  const ModelState({
    this.models = const [],
    this.defaultModelId,
    this.isLoading = false,
    this.error,
  });

  ModelState copyWith({
    List<Map<String, dynamic>>? models,
    String? defaultModelId,
    bool? isLoading,
    String? error,
  }) {
    return ModelState(
      models: models ?? this.models,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [models, defaultModelId, isLoading, error];
}
