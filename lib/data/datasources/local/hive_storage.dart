import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class HiveStorage {
  static late Box<dynamic> _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('beidouxing');
  }

  Future<void> setString(String key, String value) async {
    await _box.put(key, value);
  }

  String? getString(String key) {
    final value = _box.get(key);
    return value?.toString();
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final value = _box.get(key);
    if (value == null) return null;
    try {
      return jsonDecode(value.toString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
