import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class HiveStorage {
  static Box<dynamic>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('beidouxing');
  }

  static Box<dynamic> get _safeBox {
    final box = _box;
    if (box == null) {
      throw StateError('HiveStorage 尚未初始化，请先调用 HiveStorage.init()');
    }
    return box;
  }

  Future<void> setString(String key, String value) async {
    await _safeBox.put(key, value);
  }

  String? getString(String key) {
    final value = _safeBox.get(key);
    return value?.toString();
  }

  Future<void> setThemeMode(String mode) async {
    await _safeBox.put('app_theme_mode', mode);
  }

  String? getThemeMode() {
    final value = _safeBox.get('app_theme_mode');
    return value?.toString();
  }

  Future<void> setConversationVoice(String voice) async {
    await _safeBox.put('conversation_voice', voice);
  }

  String? getConversationVoice() {
    final value = _safeBox.get('conversation_voice');
    return value?.toString();
  }

  Future<void> setVoiceCallVoice(String provider, String voice) async {
    await _safeBox.put('voice_call_voice_$provider', voice);
  }

  String? getVoiceCallVoice(String provider) {
    final value = _safeBox.get('voice_call_voice_$provider');
    return value?.toString();
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _safeBox.put(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final value = _safeBox.get(key);
    if (value == null) return null;
    try {
      return jsonDecode(value.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    await _safeBox.delete(key);
  }

  Future<void> clear() async {
    await _safeBox.clear();
  }
}
