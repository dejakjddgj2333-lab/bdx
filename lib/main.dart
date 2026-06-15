import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/datasources/local/hive_storage.dart';
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

  runApp(const App());
}
