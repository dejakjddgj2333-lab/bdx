import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme_mode.dart';
import '../../../data/datasources/local/hive_storage.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  final HiveStorage _storage;

  ThemeCubit(this._storage) : super(const ThemeState());

  /// 从本地存储加载主题模式
  Future<void> load() async {
    final saved = _storage.getThemeMode();
    final mode = AppThemeModeX.fromString(saved);
    emit(ThemeState(mode: mode));
  }

  /// 设置并持久化主题模式
  Future<void> setMode(AppThemeMode mode) async {
    await _storage.setThemeMode(mode.name);
    emit(ThemeState(mode: mode));
  }
}
