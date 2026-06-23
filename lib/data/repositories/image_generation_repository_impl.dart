import 'package:dio/dio.dart';
import '../../../core/errors/exceptions.dart';
import '../../../data/datasources/remote/image_generation_api.dart';
import '../../../domain/entities/image_model.dart';
import '../../../domain/entities/painting.dart';
import '../../../domain/repositories/image_generation_repository.dart';

class ImageGenerationRepositoryImpl implements ImageGenerationRepository {
  final ImageGenerationApi _api;

  ImageGenerationRepositoryImpl(this._api);

  Map<String, dynamic> _unwrap(Response? response) {
    if (response?.data == null) throw const ServerException('响应为空');
    final data = response!.data as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw ServerException(data['message']?.toString() ?? '请求失败');
    }
    return data;
  }

  @override
  Future<List<ImageModel>> getImageModels() async {
    final res = await _api.getImageModels();
    final data = _unwrap(res);
    final list = data['data'] as List<dynamic>?;
    return list?.map((e) => _mapImageModel(e as Map<String, dynamic>)).toList() ?? [];
  }

  @override
  Future<ImageModel?> getDefaultImageModel() async {
    final models = await getImageModels();
    if (models.isEmpty) return null;
    return models.firstWhere(
      (m) => m.isDefault,
      orElse: () => models.first,
    );
  }

  @override
  Future<Painting> generateImage({
    required String prompt,
    String? negativePrompt,
    String? model,
    String? size,
    String? style,
    int n = 1,
  }) async {
    final res = await _api.generateImage({
      'prompt': prompt,
      if (negativePrompt != null && negativePrompt.isNotEmpty)
        'negativePrompt': negativePrompt,
      if (model != null && model.isNotEmpty) 'model': model,
      if (size != null && size.isNotEmpty) 'size': size,
      if (style != null && style.isNotEmpty) 'style': style,
      'n': n,
    });
    final data = _unwrap(res);
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    return _mapPainting(payload);
  }

  @override
  Future<List<Painting>> getPaintings({int page = 1, int pageSize = 20}) async {
    final res = await _api.getPaintings({
      'page': page,
      'pageSize': pageSize,
    });
    final data = _unwrap(res);
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    final list = payload['list'] as List<dynamic>?;
    return list?.map((e) => _mapPainting(e as Map<String, dynamic>)).toList() ?? [];
  }

  @override
  Future<({int limit, int used, int remaining})> getImageQuota() async {
    final res = await _api.getImageQuota();
    final data = _unwrap(res);
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    final limit = (payload['limit'] as num?)?.toInt() ?? 0;
    final used = (payload['used'] as num?)?.toInt() ?? 0;
    final remaining = (payload['remaining'] as num?)?.toInt() ?? 0;
    return (limit: limit, used: used, remaining: remaining);
  }

  ImageModel _mapImageModel(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
      supportedSizes: _toStringList(json['supportedSizes']),
      supportedStyles: _toStringList(json['supportedStyles']),
      config: json['config'] is Map<String, dynamic>
          ? json['config'] as Map<String, dynamic>
          : {},
    );
  }

  Painting _mapPainting(Map<String, dynamic> json) {
    return Painting(
      id: json['id']?.toString(),
      prompt: json['prompt']?.toString() ?? '',
      negativePrompt: (json['negativePrompt'] ?? json['negative_prompt'])?.toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      style: json['style']?.toString(),
      status: json['status']?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
