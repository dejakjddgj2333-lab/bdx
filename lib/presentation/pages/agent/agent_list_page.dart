import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../domain/entities/agent.dart';
import '../../blocs/agent/agent_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/tech_background.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<AgentBloc>().add(const AgentLoaded());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      context.read<AgentBloc>().add(const AgentLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: Column(
          children: [
            AppHeader(
              title: '智能体',
              leading: BdxIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                backgroundColor: Colors.transparent,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.s16,
                AppDimens.s16,
                AppDimens.s16,
                AppDimens.s12,
              ),
              child: _buildSearchField(),
            ),
            _buildCategoryList(),
            Expanded(child: _buildAgentList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return BdxInput(
      controller: _searchController,
      hintText: '搜索智能体',
      prefix: Icon(
        Icons.search,
        color: AppColors.of(context).textTertiary,
        size: AppDimens.iconMedium,
      ),
      suffix: _searchController.text.isNotEmpty
          ? IconButton(
              onPressed: () {
                _searchController.clear();
                context.read<AgentBloc>().add(const AgentSearchChanged(''));
                setState(() {});
              },
              icon: Icon(
                Icons.clear,
                color: AppColors.of(context).textTertiary,
                size: AppDimens.iconMedium,
              ),
            )
          : null,
      onChanged: (value) =>
          context.read<AgentBloc>().add(AgentSearchChanged(value)),
    );
  }

  Widget _buildCategoryList() {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        if (state is AgentLoadedSuccess) {
          return SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.s12),
              itemCount: state.categories.length,
              itemBuilder: (context, index) {
                final category = state.categories[index];
                final isSelected = category == state.selectedCategory ||
                    (state.selectedCategory.isEmpty && category == '全部');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.s4),
                  child: BdxChip(
                    label: category,
                    selected: isSelected,
                    onTap: () => context.read<AgentBloc>().add(
                          AgentCategorySelected(
                            category == '全部' ? '' : category,
                          ),
                        ),
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAgentList() {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        if (state is AgentLoading) {
          return const Center(child: LoadingIndicator());
        }
        if (state is AgentError) {
          return BdxEmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            subtitle: state.message,
            action: BdxButton(
              text: '重试',
              onTap: () => context.read<AgentBloc>().add(const AgentLoaded()),
            ),
          );
        }
        if (state is AgentLoadedSuccess) {
          if (state.agents.isEmpty) {
            return const BdxEmptyState(
              icon: Icons.smart_toy_outlined,
              title: '暂无智能体',
            );
          }

          return LiquidPullToRefresh(
            onRefresh: () async {
              context.read<AgentBloc>().add(const AgentLoaded());
            },
            color: AppColors.primary,
            backgroundColor: Colors.white,
            height: 60,
            showChildOpacityTransition: false,
            child: AnimationLimiter(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppDimens.s16),
                itemCount: state.agents.length + (state.hasReachedMax ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == state.agents.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.s16),
                        child: LoadingIndicator(),
                      ),
                    );
                  }
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 30,
                      child: FadeInAnimation(
                        child: _buildAgentCard(state.agents[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAgentCard(Agent agent) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: () => context.push('/chat/detail?agentId=${agent.id}'),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: AppDimens.s12),
        padding: AppDimens.listItemPadding,
        child: Row(
          children: [
            BdxAvatar(
              imageUrl: agent.avatar,
              icon: Icons.smart_toy,
              size: AppDimens.avatarLarge,
              borderRadius: AppDimens.r18,
            ),
            const SizedBox(width: AppDimens.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.name ?? '未命名',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimens.s4),
                  Text(
                    agent.category ?? '',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppDimens.s4),
                  Text(
                    agent.description ?? '',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
