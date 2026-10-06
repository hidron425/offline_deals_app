import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class ContentService {
  static final Map<String, String> _cache = {};

  static supa.SupabaseClient get _sb => supa.Supabase.instance.client;

  static Future<String> getContent(String key, {String defaultValue = ''}) async {
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final data = await _sb
          .from('content')
          .select('text')
          .eq('key', key)
          .limit(1)
          .maybeSingle();

      if (data != null && data['text'] != null) {
        final text = data['text'] as String;
        _cache[key] = text;
        return text;
      }
    } catch (e) {
      print('❌ ContentService.getContent($key): $e');
    }

    return defaultValue;
  }

  static Future<void> preload(List<String> keys) async {
    for (final key in keys) {
      try {
        await getContent(key);
      } catch (_) {}
    }
  }
}