import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ContactStatus { none, emailed, replied, noEmail }

class ContactInfo {
  final ContactStatus status;
  final String? date;
  final bool favorite;

  const ContactInfo({
    this.status = ContactStatus.none,
    this.date,
    this.favorite = false,
  });

  ContactInfo copyWith({ContactStatus? status, String? date, bool? favorite}) =>
      ContactInfo(
        status: status ?? this.status,
        date: date ?? this.date,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() =>
      {'status': status.name, 'date': date, 'favorite': favorite};

  factory ContactInfo.fromJson(Map<String, dynamic> j) => ContactInfo(
    status: ContactStatus.values.firstWhere(
            (s) => s.name == j['status'],
        orElse: () => ContactStatus.none),
    date: j['date'] as String?,
    favorite: j['favorite'] == true,
  );
}

class ContactStore {
  static const _key = 'contacts_v1';
  static Map<String, ContactInfo>? _cache;

  static Future<Map<String, ContactInfo>> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = {};

    final map = <String, ContactInfo>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      // Naya safe loop: Agar ek record kharab ho to sirf wo ignore hoga, sab 0 nahi honge!
      for (final entry in decoded.entries) {
        try {
          map[entry.key] = ContactInfo.fromJson(entry.value as Map<String, dynamic>);
        } catch (_) {
          // ignore bad record
        }
      }
      _cache = map;
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _cache ?? {};
    await prefs.setString(
        _key, jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
  }

  static Future<Map<String, ContactInfo>> setStatus(
      String id, ContactStatus status) async {
    final map = await load();
    final now = DateTime.now().toIso8601String().substring(0, 10);
    map[id] = (map[id] ?? const ContactInfo()).copyWith(
        status: status, date: now);
    await _persist();
    return map;
  }

  static Future<Map<String, ContactInfo>> toggleFavorite(String id) async {
    final map = await load();
    final current = map[id] ?? const ContactInfo();
    map[id] = current.copyWith(favorite: !current.favorite);
    await _persist();
    return map;
  }
}