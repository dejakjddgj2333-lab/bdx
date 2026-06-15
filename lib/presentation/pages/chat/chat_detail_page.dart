import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/chat_detail/chat_detail_bloc.dart';
import '../../widgets/ai_message.dart';
import '../../widgets/app_header.dart';
import '../../widgets/model_picker.dart';
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
        ));

    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _textController.text = Uri.decodeComponent(widget.initialContent!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatDetailBloc>().add(ChatDetailMessageSent(_textController.text));
        _textController.clear();
      });
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    _textController.dispose();
    _scrollController.dispose();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: BlocConsumer<ChatDetailBloc, ChatDetailState>(
        listener: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
                leading: IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                actions: [
                  _buildModelChip(currentModelName),
                  IconButton(
                    onPressed: () => _showMoreActions(context),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ],
              ),
              Expanded(child: _buildMessageList(state)),
              _buildInputArea(state, supportsVision),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelChip(String name) {
    return GestureDetector(
      onTap: () => _showModelPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
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
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textTertiary, size: 18),
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
      padding: const EdgeInsets.only(bottom: 16),
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
    return Shimmer.fromColors(
      baseColor: AppColors.glassWhite,
      highlightColor: AppColors.borderSubtle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Container(width: 200, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Container(width: 160, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(ChatDetailState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '嗨，今天要和北斗星AI一起做什么？',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '选一个话题开始吧',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ...state.suggestions.map((s) => _buildSuggestionItem(s)),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion) {
    final title = suggestion['title']?.toString() ?? '';
    final prompt = suggestion['prompt']?.toString() ?? '';
    return GestureDetector(
      onTap: () {
        _textController.text = prompt;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textTertiary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        final delay = index * 0.25;
        final value = ((_dotController.value + delay) % 1.0);
        final scale = 0.5 + (value < 0.5 ? value * 2 : (1 - value) * 2) * 0.6;
        return Container(
          width: 8 * scale,
          height: 8 * scale,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(ChatDetailState state, bool supportsVision) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        // Scaffold 的 resizeToAvoidBottomInset 已经把 body 向上顶了键盘高度，
        // 这里只需补偿底部安全区 + 固定间距，避免双重计算。
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (supportsVision)
                  IconButton(
                    onPressed: state.isSending ? null : _pickImage,
                    icon: const Icon(Icons.photo, color: AppColors.textSecondary),
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(state),
                    decoration: const InputDecoration(
                      hintText: '尽管问，带图也行',
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: state.isSending ? null : () => _sendMessage(state),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: state.isSending ? null : AppColors.primaryGradient,
                      color: state.isSending ? AppColors.buttonOverlay : null,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '内容由 AI 生成',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
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
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => context.read<ChatDetailBloc>().add(ChatDetailImageRemoved(index)),
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
    );
  }

  void _sendMessage(ChatDetailState state) {
    final text = _textController.text.trim();
    if (text.isEmpty && state.pendingImages.isEmpty) return;
    context.read<ChatDetailBloc>().add(ChatDetailMessageSent(text));
    _textController.clear();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    try {
      final bytes = await image.readAsBytes();
      context.read<ChatDetailBloc>().add(ChatDetailImageUploaded(
            bytes,
            filename: image.name,
          ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }

  void _showModelPicker(BuildContext context) {
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
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<ChatDetailBloc>().add(const ChatDetailModelsReloadRequested()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            if (state.models.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('加载模型中...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }
            return ModelPicker(
              models: state.models,
              selectedId: state.currentModel,
              onSelected: (id) => context.read<ChatDetailBloc>().add(ChatDetailModelSelected(id)),
            );
          },
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.white),
              title: const Text('清空对话', style: TextStyle(color: Colors.white)),
              onTap: () {
                context.read<ChatDetailBloc>().add(const ChatDetailCleared());
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.white),
              title: const Text('新建对话', style: TextStyle(color: Colors.white)),
              onTap: () {
                context.read<ChatDetailBloc>().add(const ChatDetailCleared());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
