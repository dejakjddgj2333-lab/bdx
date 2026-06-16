import 'package:get_it/get_it.dart';
import 'data/datasources/local/hive_storage.dart';
import 'data/datasources/local/secure_storage.dart';
import 'data/datasources/remote/api_client.dart';
import 'data/datasources/remote/auth_api.dart';
import 'data/datasources/remote/chat_api.dart';
import 'data/datasources/remote/agent_api.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'data/repositories/agent_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/agent_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/chat_list/chat_list_bloc.dart';
import 'presentation/blocs/chat_detail/chat_detail_bloc.dart';
import 'presentation/blocs/agent/agent_bloc.dart';
import 'presentation/blocs/theme/theme_cubit.dart';
import 'presentation/blocs/voice_call/voice_call_bloc.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/websocket_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // 本地存储
  getIt.registerSingleton(SecureStorage());
  getIt.registerSingleton(HiveStorage());

  // 主题
  getIt.registerLazySingleton(() => ThemeCubit(getIt<HiveStorage>()));

  // API 客户端
  getIt.registerSingleton(ApiClient(getIt<SecureStorage>()));

  // API
  getIt.registerSingleton(AuthApi(getIt<ApiClient>().dio));
  getIt.registerSingleton(ChatApi(getIt<ApiClient>().dio));
  getIt.registerSingleton(AgentApi(getIt<ApiClient>().dio));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<AuthApi>(),
      getIt<SecureStorage>(),
      getIt<HiveStorage>(),
    ),
  );
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      getIt<ChatApi>(),
      getIt<SecureStorage>(),
    ),
  );
  getIt.registerLazySingleton<AgentRepository>(
    () => AgentRepositoryImpl(getIt<AgentApi>()),
  );

  // Services
  getIt.registerLazySingleton(() => WebSocketService(getIt<SecureStorage>()));
  getIt.registerLazySingleton(() => createAudioRecorderService());
  getIt.registerLazySingleton(() => AudioPlayerService());

  // Blocs
  getIt.registerFactory(() => AuthBloc(getIt<AuthRepository>()));
  getIt.registerFactory(() => ChatListBloc(getIt<ChatRepository>()));
  getIt.registerFactory(() => ChatDetailBloc(getIt<ChatRepository>()));
  getIt.registerFactory(() => AgentBloc(getIt<AgentRepository>()));
  getIt.registerFactory(() => VoiceCallBloc(
        getIt<WebSocketService>(),
        getIt<AudioRecorderService>(),
        getIt<AudioPlayerService>(),
      ));
}
