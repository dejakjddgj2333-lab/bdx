import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_theme.dart';
import 'injection.dart';
import 'presentation/blocs/agent/agent_bloc.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/chat_detail/chat_detail_bloc.dart';
import 'presentation/blocs/chat_list/chat_list_bloc.dart';
import 'presentation/blocs/voice_call/voice_call_bloc.dart';
import 'presentation/pages/agent/agent_list_page.dart';
import 'presentation/pages/chat/chat_detail_page.dart';
import 'presentation/pages/chat/chat_list_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/profile/profile_page.dart';
import 'presentation/pages/voice_call/voice_call_page.dart';
import 'presentation/widgets/tech_background.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
      child: MaterialApp.router(
        title: '北斗星AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _router,
        builder: (context, child) => TechBackground(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isLoginPage = state.matchedLocation == '/login';

    if (authState is AuthLoading || authState is AuthInitial) return null;
    if (!authState.isAuthenticated && !isLoginPage) {
      return '/login?redirect=${Uri.encodeComponent(state.matchedLocation)}';
    }
    if (authState.isAuthenticated && isLoginPage) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ChatListBloc>()..add(const ChatListLoaded()),
        child: const ChatListPage(),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final redirect = state.uri.queryParameters['redirect'];
        return LoginPage(redirect: redirect);
      },
    ),
    GoRoute(
      path: '/chat/detail',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final agentId = state.uri.queryParameters['agentId'];
        final content = state.uri.queryParameters['content'];
        return BlocProvider(
          create: (_) => getIt<ChatDetailBloc>(),
          child: ChatDetailPage(
            conversationId: id,
            agentId: agentId,
            initialContent: content,
          ),
        );
      },
    ),
    GoRoute(
      path: '/agents',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AgentBloc>()..add(const AgentLoaded()),
        child: const AgentListPage(),
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/voice-call',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<VoiceCallBloc>(),
        child: const VoiceCallPage(),
      ),
    ),
  ],
);
