import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_theme_mode.dart';
import 'injection.dart';
import 'presentation/blocs/agent/agent_bloc.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/chat_detail/chat_detail_bloc.dart';
import 'presentation/blocs/chat_list/chat_list_bloc.dart';
import 'presentation/blocs/theme/theme_cubit.dart';
import 'presentation/blocs/theme/theme_state.dart';
import 'presentation/blocs/voice_call/voice_call_bloc.dart';
import 'presentation/pages/agent/agent_list_page.dart';
import 'presentation/pages/chat/chat_detail_page.dart';
import 'presentation/pages/chat/chat_list_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/profile/profile_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/voice_call/voice_call_page.dart';
import 'presentation/widgets/tech_background.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: '北斗星AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(
              platform: TargetPlatform.iOS,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            darkTheme: AppTheme.darkTheme.copyWith(
              platform: TargetPlatform.iOS,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            themeMode: themeState.mode.toThemeMode,
            routerConfig: _router,
            builder: (context, child) => TechBackground(child: child ?? const SizedBox.shrink()),
          );
        },
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
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (_) => getIt<ChatListBloc>()..add(const ChatListLoaded()),
          child: const ChatListPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) {
        final redirect = state.uri.queryParameters['redirect'];
        return CupertinoPage(
          key: state.pageKey,
          child: LoginPage(redirect: redirect),
        );
      },
    ),
    GoRoute(
      path: '/chat/detail',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'];
        final agentId = state.uri.queryParameters['agentId'];
        final content = state.uri.queryParameters['content'];
        return CupertinoPage(
          key: state.pageKey,
          child: BlocProvider(
            create: (_) => getIt<ChatDetailBloc>(),
            child: ChatDetailPage(
              conversationId: id,
              agentId: agentId,
              initialContent: content,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/agents',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (_) => getIt<AgentBloc>()..add(const AgentLoaded()),
          child: const AgentListPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: const ProfilePage(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: const SettingsPage(),
      ),
    ),
    GoRoute(
      path: '/voice-call',
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        child: BlocProvider(
          create: (_) => getIt<VoiceCallBloc>(),
          child: const VoiceCallPage(),
        ),
      ),
    ),
  ],
);
