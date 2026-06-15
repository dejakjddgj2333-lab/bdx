import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';

class UserMessage extends StatelessWidget {
  final dynamic content;

  const UserMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final parts = _parseContent(content);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2D3E), Color(0xFF1F2230)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: parts.map((p) => _buildPart(p)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPart(Map<String, dynamic> part) {
    final type = part['type']?.toString();
    if (type == 'image_url') {
      final url = part['image_url']?['url']?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: _getImageUrl(url),
            width: 160,
            height: 160,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 160,
              height: 160,
              color: AppColors.bgElevated,
            ),
            errorWidget: (_, __, ___) => Container(
              width: 160,
              height: 160,
              color: AppColors.bgElevated,
              child: const Icon(Icons.broken_image, color: AppColors.textTertiary),
            ),
          ),
        ),
      );
    }

    return Text(
      part['text']?.toString() ?? '',
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
    );
  }

  List<Map<String, dynamic>> _parseContent(dynamic content) {
    if (content is String) {
      return [{'type': 'text', 'text': content}];
    }
    if (content is List) {
      return content.whereType<Map<String, dynamic>>().toList();
    }
    if (content is Map) {
      return [content as Map<String, dynamic>];
    }
    return [];
  }

  String _getImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiConstants.uploadBaseUrl.replaceAll(RegExp(r'/$'), '')}$url';
  }
}
