import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/datasources/local/hive_storage.dart';
import 'presentation/blocs/theme/theme_cubit.dart';
import 'presentation/blocs/voice/voice_cubit.dart';
import 'app.dart';
import 'injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();
  await HiveStorage.init();
  await getIt<ThemeCubit>().load();
  await getIt<VoiceCubit>().load();

  runApp(const App());
}
