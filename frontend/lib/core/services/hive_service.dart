import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String sessionBoxName = 'desktop_session_box';
  static const String cacheBoxName = 'desktop_cache_box';
  static const String settingsBoxName = 'desktop_settings_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(cacheBoxName);
    await Hive.openBox(settingsBoxName);
  }

  // --- Session Storage ---
  static Future<void> saveSession(Map<String, dynamic> userData) async {
    final box = Hive.box(sessionBoxName);
    await box.put('user_data', userData);
  }

  static Map<String, dynamic>? getSession() {
    final box = Hive.box(sessionBoxName);
    final data = box.get('user_data');
    if (data != null) {
      return Map<String, dynamic>.from(data as Map);
    }
    return null;
  }

  static Future<void> clearSession() async {
    final box = Hive.box(sessionBoxName);
    await box.clear();
  }

  // --- General Caching ---
  static Future<void> cacheData(String key, dynamic value) async {
    final box = Hive.box(cacheBoxName);
    await box.put(key, {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'value': value,
    });
  }

  static dynamic getCachedData(String key, {Duration maxAge = const Duration(hours: 1)}) {
    final box = Hive.box(cacheBoxName);
    final record = box.get(key);
    if (record == null) return null;

    final timestamp = record['timestamp'] as int;
    final value = record['value'];

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAge.inMilliseconds) {
      box.delete(key); // Stale cache
      return null;
    }
    return value;
  }

  static Future<void> clearCache() async {
    await Hive.box(cacheBoxName).clear();
  }
}
