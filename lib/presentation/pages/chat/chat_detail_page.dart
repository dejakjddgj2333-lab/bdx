import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/bdx_animations.dart';
import '../../blocs/chat_detail/chat_detail_bloc.dart';
import '../../blocs/model/model_cubit.dart';
import '../../widgets/ai_message.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/model_picker.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/user_message.dart';

class ChatDetailPage extends StatefulWidget {
  final String? conversationId;
  final String? agentId;
  final String? initialContent;

  const ChatDetailPage({
    super.key,
    this.conversationId,
    this.agentId,
    this.initialContent,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    context.read<ChatDetailBloc>().add(ChatDetailInitialized(
          conversationId: widget.conversationId,
          agentId: widget.agentId,
          initialModel: context.read<ModelCubit>().state.defaultModelId,
          initialModels: context.read<ModelCubit>().state.models.isNotEmpty
              ? context.read<ModelCubit>().state.models
              : null,
        ));

    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _textController.text = widget.initialContent!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatDetailBloc>().add(
              ChatDetailMessageSent(_textController.text),
            );
        _textController.clear();
      });
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: TechBackground(
        child: BlocConsumer<ChatDetailBloc, ChatDetailState>(
          listener: (context, state) {
            if (state.error != null) {
              BdxToast.show(
                context,
                message: state.error!,
                icon: Icons.error_outline,
              );
            }
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          },
          builder: (context, state) {
            final currentModelName = state.models
                    .firstWhere(
                      (m) => m['id']?.toString() == state.currentModel,
                      orElse: () => {'name': '选择模型'},
                    )['name']
                    ?.toString() ??
                '选择模型';

            final supportsVision = state.models
                    .firstWhere(
                      (m) => m['id']?.toString() == state.currentModel,
                      orElse: () => {'supportsVision': false},
                    )['supportsVision'] as bool? ??
                false;

            return Column(
              children: [
                AppHeader(
                  title: '',
                  leading: BdxIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.canPop() ? context.pop() : context.go('/'),
                    backgroundColor: Colors.transparent,
                  ),
                  actions: [
                    _buildModelChip(currentModelName),
                    BdxIconButton(
                      icon: Icons.more_vert,
                      onTap: () => _showMoreActions(context),
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
                Expanded(child: _buildMessageList(state)),
                _buildInputArea(state, supportsVision),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelChip(String name) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: () => _showModelPicker(context),
      child: GlassCard(
        borderRadius: AppDimens.r16,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.s12,
          vertical: AppDimens.s6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatDetailState state) {
    if (state.isLoadingHistory) {
      return _buildSkeleton();
    }

    final messages = state.messages;

    if (messages.isEmpty) {
      return _buildWelcome(state);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppDimens.s16),
      itemCount: messages.length + (state.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _buildLoadingBubble();
        }
        final msg = messages[index];
        if (msg.role == 'user') {
          return UserMessage(content: msg.content);
        }
        return AiMessage(content: msg.content, model: msg.model);
      },
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: AppDimens.pagePadding,
      child: Column(
        children: [
          Row(
            children: [
              const BdxSkeleton(width: 36, height: 36, borderRadius: 18),
              const SizedBox(width: 12),
              const BdxSkeleton(width: 200, height: 60, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: BdxSkeleton(width: 160, height: 40, borderRadius: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(ChatDetailState state) {
    return BdxAnimations.fadeSlideIn(
      SingleChildScrollView(
        padding: AppDimens.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ).animate().scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: AppDimens.s24),
            Text(
              '嗨，今天要和北斗星AI一起做什么？',
              style: AppTextStyles.headline(context),
            ),
            const SizedBox(height: AppDimens.s8),
            Text(
              '选一个话题开始吧',
              style: AppTextStyles.bodySmall(context),
            ),
            const SizedBox(height: AppDimens.s28),
            ...state.suggestions.asMap().entries.map(
                  (e) => BdxAnimations.fadeSlideIn(
                    _buildSuggestionItem(e.value),
                    delayMs: e.key * 80,
                    beginY: 0.08,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion) {
    final colors = AppColors.of(context);
    final title = suggestion['title']?.toString() ?? '';
    final prompt = suggestion['prompt']?.toString() ?? '';

    return PressScale(
      onTap: () {
        _textController.text = prompt;
        _focusNode.requestFocus();
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: AppDimens.s12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.s20,
          vertical: AppDimens.s16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: colors.textTertiary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.s8,
        horizontal: AppDimens.s16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BdxGradientAvatar(
            size: 36,
            borderRadius: AppDimens.r12,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          GlassCard(
            borderRadius: AppDimens.r16,
            padding: const EdgeInsets.all(AppDimens.s16),
            child: BdxTypingDots(
              dotSize: 8,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatDetailState state, bool supportsVision) {
    final colors = AppColors.of(context);
    final hasContent = _textController.text.isNotEmpty ||
        state.pendingImages.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: AppDimens.s16,
        right: AppDimens.s16,
        top: AppDimens.s12,
        bottom: MediaQuery.of(context).padding.bottom + AppDimens.s12,
      ),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.pendingImages.isNotEmpty)
                SizedBox(
                  height: 76,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.pendingImages.length,
                    itemBuilder: (context, index) {
                      return _buildPendingImage(state.pendingImages[index], index);
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.s8),
                decoration: BoxDecoration(
                  color: colors.glassWhite,
                  borderRadius: BorderRadius.circular(AppDimens.r24),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? colors.border
                        : colors.borderSubtle,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (supportsVision)
                      BdxIconButton(
                        icon: Icons.photo,
                        onTap: state.isSending ? null : _pickImage,
                        size: 40,
                        backgroundColor: Colors.transparent,
                        showBorder: false,
                        iconColor: state.isSending
                            ? colors.textTertiary
                            : colors.textSecondary,
                      ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(state),
                        decoration: InputDecoration(
                          hintText: '尽管问，带图也行',
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.s12,
                            vertical: AppDimens.s12,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintStyle: TextStyle(color: colors.textTertiary),
                        ),
                        style: TextStyle(color: colors.text),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: 200.ms,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: hasContent && !state.isSending
                          ? PressScale(
                              key: const ValueKey('send'),
                              onTap: () => _sendMessage(state),
                              haptic: true,
                              child: Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow:
                                      AppShadows.glowPrimary(opacity: 0.35),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty'),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.s6),
              Text(
                '内容由 AI 生成',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingImage(String url, int index) {
    final imageUrl = url.startsWith('http') ? url : '${ApiConstants.uploadBaseUrl}$url';
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.r10),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: PressScale(
            onTap: () =>
                context.read<ChatDetailBloc>().add(ChatDetailImageRemoved(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 200.ms,
        );
  }

  void _sendMessage(ChatDetailState state) {
    final text = _textController.text.trim();
    if (text.isEmpty && state.pendingImages.isEmpty) return;
    HapticFeedback.lightImpact();
    context.read<ChatDetailBloc>().add(ChatDetailMessageSent(text));
    _textController.clear();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      context.read<ChatDetailBloc>().add(ChatDetailImageUploaded(
            bytes,
            filename: image.name,
          ));
    } catch (e) {
      if (!mounted) return;
      BdxToast.show(context, message: '上传失败: $e', icon: Icons.error_outline);
    }
  }

  void _showModelPicker(BuildContext context) {
    final colors = AppColors.of(context);
    final bloc = context.read<ChatDetailBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
          builder: (context, state) {
            if (state.error != null) {
              return Container(
                padding: AppDimens.pagePadding,
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimens.r24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BdxBottomSheetHandle(),
                    Text(
                      state.error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimens.s16),
                    BdxButton(
                      text: '重试',
                      expanded: true,
                      onTap: () => context
                          .read<ChatDetailBloc>()
                          .add(const ChatDetailModelsReloadRequested()),
                    ),
                  ],
                ),
              );
            }
            if (state.models.isEmpty) {
              return Container(
                padding: AppDimens.pagePadding,
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimens.r24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BdxBottomSheetHandle(),
                    const BdxLoading(),
                    const SizedBox(height: AppDimens.s16),
                    Text('加载模型中...', style: TextStyle(color: colors.text)),
                  ],
                ),
              );
            }
            return ModelPicker(
              models: state.models,
              selectedId: state.currentModel,
              onSelected: (id) => context
                  .read<ChatDetailBloc>()
                  .add(ChatDetailModelSelected(id)),
            );
          },
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: colors.bgElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.r24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BdxBottomSheetHandle(),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.glassWhite,
                    borderRadius: BorderRadius.circular(AppDimens.r10),
                  ),
                  child: Icon(Icons.cleaning_services, color: colors.text),
                ),
                title: Text('清空对话', style: TextStyle(color: colors.text)),
                onTap: () {
                  context.read<ChatDetailBloc>().add(const ChatDetailCleared());
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.glassWhite,
                    borderRadius: BorderRadius.circular(AppDimens.r10),
                  ),
                  child: Icon(Icons.add_circle_outline, color: colors.text),
                ),
                title: Text('新建对话', style: TextStyle(color: colors.text)),
                onTap: () {
                  context.read<ChatDetailBloc>().add(const ChatDetailCleared());
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
