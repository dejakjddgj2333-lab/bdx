import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class ImageGenerationApi {
  final Dio _dio;

  ImageGenerationApi(this._dio);

  Future<Response> getImageModels() async {
    return _dio.get(ApiConstants.imageModels);
  }

  Future<Response> getImageQuota() async {
    return _dio.get(ApiConstants.imageQuota);
  }

  Future<Response> generateImage(Map<String, dynamic> body) async {
    return _dio.post(ApiConstants.generateImage, data: body);
  }

  Future<Response> getPaintings(Map<String, dynamic> queries) async {
    return _dio.get(ApiConstants.paintings, queryParameters: queries);
  }
}
