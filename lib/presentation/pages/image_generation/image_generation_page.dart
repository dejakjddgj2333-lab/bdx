import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../domain/entities/painting.dart';
import '../../blocs/image_generation/image_generation_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/tech_background.dart';

class ImageGenerationPage extends StatefulWidget {
  const ImageGenerationPage({super.key});

  @override
  State<ImageGenerationPage> createState() => _ImageGenerationPageState();
}

class _ImageGenerationPageState extends State<ImageGenerationPage> {
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ImageGenerationBloc>().add(const ImageGenerationLoaded());
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: BlocConsumer<ImageGenerationBloc, ImageGenerationState>(
          listener: (context, state) {
            if (state.error != null) {
              BdxToast.show(
                context,
                message: state.error!,
                icon: Icons.error_outline,
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                AppHeader(
                  title: 'AI 绘图',
                  leading: BdxIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.canPop() ? context.pop() : context.go('/'),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: _buildInputSection(state)),
                      SliverToBoxAdapter(child: _buildParamsSection(state)),
                      SliverToBoxAdapter(child: _buildGenerateButton(state)),
                      SliverToBoxAdapter(child: _buildResultSection(state)),
                      SliverToBoxAdapter(child: _buildHistoryHeader(state)),
                      _buildHistoryGrid(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputSection(ImageGenerationState state) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        AppDimens.s8,
        AppDimens.s16,
        AppDimens.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '图片描述',
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.s8),
          BdxInput(
            controller: _promptController,
            hintText: '描述你想生成的画面，例如：一只在火星上喝咖啡的猫...',
            maxLines: 4,
            minLines: 3,
            onChanged: (value) => context
                .read<ImageGenerationBloc>()
                .add(ImageGenerationPromptChanged(value)),
          ),
          const SizedBox(height: AppDimens.s12),
          GlassCard(
            borderRadius: AppDimens.r12,
            padding: const EdgeInsets.all(AppDimens.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '负面提示词（可选）',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppDimens.s8),
                TextField(
                  controller: _negativePromptController,
                  maxLines: 2,
                  minLines: 1,
                  style: TextStyle(color: colors.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '不想出现的元素，如：模糊、低质量、多余的手指...',
                    hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => context
                      .read<ImageGenerationBloc>()
                      .add(ImageGenerationNegativePromptChanged(value)),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamsSection(ImageGenerationState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s12,
      ),
      child: GlassCard(
        borderRadius: AppDimens.r16,
        padding: const EdgeInsets.all(AppDimens.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.models.isNotEmpty) ...[
              _buildParamRow(
                label: '模型',
                child: _buildModelSelector(state),
              ),
              const SizedBox(height: AppDimens.s12),
            ],
            if (state.selectedModel?.supportedSizes.isNotEmpty == true) ...[
              _buildParamRow(
                label: '尺寸',
                child: _buildSizeSelector(state),
              ),
              const SizedBox(height: AppDimens.s12),
            ],
            if (state.selectedModel?.supportedStyles.isNotEmpty == true)
              _buildParamRow(
                label: '风格',
                child: _buildStyleSelector(state),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow({required String label, required Widget child}) {
    final colors = AppColors.of(context);

    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildModelSelector(ImageGenerationState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: state.models.map((model) {
          final isSelected = state.selectedModel?.id == model.id;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.s8),
            child: BdxChip(
              label: model.name,
              selected: isSelected,
              onTap: () => context
                  .read<ImageGenerationBloc>()
                  .add(ImageGenerationModelSelected(model.id)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSizeSelector(ImageGenerationState state) {
    final sizes = state.selectedModel?.supportedSizes ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sizes.map((size) {
          final isSelected = state.size == size;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.s8),
            child: BdxChip(
              label: size,
              selected: isSelected,
              onTap: () => context
                  .read<ImageGenerationBloc>()
                  .add(ImageGenerationSizeSelected(size)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStyleSelector(ImageGenerationState state) {
    final styles = state.selectedModel?.supportedStyles ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: styles.map((style) {
          final isSelected = state.style == style;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.s8),
            child: BdxChip(
              label: style,
              selected: isSelected,
              onTap: () => context
                  .read<ImageGenerationBloc>()
                  .add(ImageGenerationStyleSelected(style)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenerateButton(ImageGenerationState state) {
    final colors = AppColors.of(context);
    final remaining = state.quotaLimit - state.quotaUsed;
    final canGenerate = remaining > 0 && !state.isGenerating;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: Column(
        children: [
          BdxButton(
            text: state.isGenerating ? '生成中...' : '立即生成',
            icon: Icons.auto_fix_high,
            expanded: true,
            enabled: canGenerate,
            onTap: canGenerate
                ? () {
                    FocusScope.of(context).unfocus();
                    context
                        .read<ImageGenerationBloc>()
                        .add(const ImageGenerationSubmitted());
                    _promptController.clear();
                    _negativePromptController.clear();
                  }
                : null,
          ),
          const SizedBox(height: AppDimens.s8),
          Text(
            '今日剩余 $remaining / ${state.quotaLimit} 次',
            style: TextStyle(
              color: remaining > 0 ? colors.textTertiary : AppColors.pink,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(ImageGenerationState state) {
    final colors = AppColors.of(context);

    if (state.isGenerating) {
      return Container(
        margin: const EdgeInsets.fromLTRB(
          AppDimens.s16,
          0,
          AppDimens.s16,
          AppDimens.s16,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: GlassCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LoadingIndicator(size: 48),
                const SizedBox(height: AppDimens.s16),
                Text(
                  'AI 正在创作中...',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.latest?.imageUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppDimens.s8),
              Text(
                '最新作品',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.s10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.r16),
            child: AspectRatio(
              aspectRatio: _aspectRatio(state.latest!.width, state.latest!.height),
              child: Image.network(
                _fullImageUrl(state.latest!.imageUrl!),
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: colors.glassWhite,
                    child: const Center(child: LoadingIndicator()),
                  );
                },
                errorBuilder: (_, error, stack) {
                  debugPrint('最新作品图片加载失败: $_fullImageUrl(${state.latest!.imageUrl}) error=$error');
                  return Container(
                    color: colors.glassWhite,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: colors.textTertiary),
                        const SizedBox(height: 4),
                        Text(
                          '加载失败',
                          style: TextStyle(color: colors.textTertiary, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppDimens.s8),
          Text(
            state.latest!.prompt,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(ImageGenerationState state) {
    final colors = AppColors.of(context);

    if (state.history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: AppDimens.sectionPadding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimens.s8),
          Text(
            '历史作品',
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid(ImageGenerationState state) {
    final colors = AppColors.of(context);

    if (state.history.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s16,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.s10,
          mainAxisSpacing: AppDimens.s10,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final painting = state.history[index];
            final imageUrl = painting.imageUrl;
            return PressScale(
              onTap: imageUrl != null && imageUrl.isNotEmpty
                  ? () => _showImagePreview(context, painting)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.r12),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        _fullImageUrl(imageUrl),
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: colors.glassWhite,
                            child: const Center(child: LoadingIndicator()),
                          );
                        },
                        errorBuilder: (_, error, stack) {
                          debugPrint('历史作品图片加载失败: $_fullImageUrl($imageUrl) error=$error');
                          return Container(
                            color: colors.glassWhite,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: colors.textTertiary),
                                const SizedBox(height: 4),
                                Text(
                                  '加载失败',
                                  style: TextStyle(color: colors.textTertiary, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        color: colors.glassWhite,
                        child: Center(
                          child: Icon(Icons.broken_image, color: colors.textTertiary),
                        ),
                      ),
              ),
            );
          },
          childCount: state.history.length,
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, Painting painting) {
    final imageUrl = painting.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppDimens.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.r16),
              child: Image.network(
                _fullImageUrl(imageUrl),
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) {
                  debugPrint('预览图片加载失败: $_fullImageUrl($imageUrl) error=$error');
                  return Container(
                    color: colors.glassWhite,
                    child: Icon(Icons.broken_image, color: colors.textTertiary),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimens.s12),
            Text(
              painting.prompt,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _fullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final baseUrl = ApiConstants.uploadBaseUrl.replaceAll(RegExp(r'/$'), '');
    return '$baseUrl$url';
  }

  double _aspectRatio(int? width, int? height) {
    if (width == null || height == null || height == 0) return 1;
    return width / height;
  }
}
