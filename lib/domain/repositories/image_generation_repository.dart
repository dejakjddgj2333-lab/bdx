import '../entities/image_model.dart';
import '../entities/painting.dart';

abstract class ImageGenerationRepository {
  Future<List<ImageModel>> getImageModels();
  Future<ImageModel?> getDefaultImageModel();
  Future<Painting> generateImage({
    required String prompt,
    String? negativePrompt,
    String? model,
    String? size,
    String? style,
    int n = 1,
  });
  Future<List<Painting>> getPaintings({int page = 1, int pageSize = 20});
  Future<({int limit, int used, int remaining})> getImageQuota();
}
