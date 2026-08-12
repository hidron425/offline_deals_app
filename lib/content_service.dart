import 'package:cloud_firestore/cloud_firestore.dart';

class ContentService {
  static final _firestore = FirebaseFirestore.instance;
  static final Map<String, String> _cache = {};

  static Future<String> getContent(String key, {String defaultValue = ''}) async {
    if (_cache.containsKey(key)) return _cache[key]!;

    final snap = await _firestore.collection('content').where('key', isEqualTo: key).limit(1).get();
    if (snap.docs.isNotEmpty) {
      final text = snap.docs.first.data()['text'] as String? ?? defaultValue;
      _cache[key] = text;
      return text;
    }
    return defaultValue;
  }

  /// Предзагрузка нескольких ключей при старте
  static Future<void> preload(List<String> keys) async {
    for (final key in keys) {
      await getContent(key);
    }
  }
}