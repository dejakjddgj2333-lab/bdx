import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/bdx_animations.dart';
import '../../../core/constants/app_shadows.dart';
import 'bdx/bdx.dart';

class UserMessage extends StatelessWidget {
  final dynamic content;

  const UserMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final parts = _parseContent(content);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BdxAnimations.messageEnter(
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.s8,
          horizontal: AppDimens.s16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: GlassCard(
                useBlur: true,
                borderRadius: AppDimens.r18,
                customBorderRadius: AppDimens.messageBubble(isUser: true),
                borderColor: AppColors.of(context).borderSubtle,
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF2A2D3E), Color(0xFF1F2230)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.primaryGradient,
                shadows: AppShadows.card(context),
                padding: const EdgeInsets.all(AppDimens.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: parts.map((p) => _buildPart(context, p)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      isUser: true,
    );
  }

  Widget _buildPart(BuildContext context, Map<String, dynamic> part) {
    final colors = AppColors.of(context);
    final type = part['type']?.toString();
    if (type == 'image_url') {
      final url = part['image_url']?['url']?.toString() ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.s8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.r10),
          child: CachedNetworkImage(
            imageUrl: _getImageUrl(url),
            width: 160,
            height: 160,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: 160,
              height: 160,
              color: colors.bgElevated,
            ),
            errorWidget: (_, _, _) => Container(
              width: 160,
              height: 160,
              color: colors.bgElevated,
              child: Icon(Icons.broken_image, color: colors.textTertiary),
            ),
          ),
        ),
      );
    }

    return Text(
      part['text']?.toString() ?? '',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
      ),
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
