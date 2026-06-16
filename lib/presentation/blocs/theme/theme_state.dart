import 'package:equatable/equatable.dart';
import '../../../core/constants/app_theme_mode.dart';

class ThemeState extends Equatable {
  final AppThemeMode mode;

  const ThemeState({this.mode = AppThemeMode.dark});

  ThemeState copyWith({AppThemeMode? mode}) {
    return ThemeState(mode: mode ?? this.mode);
  }

  @override
  List<Object?> get props => [mode];
}
