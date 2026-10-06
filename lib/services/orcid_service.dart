import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prof_info.dart';

class OrcidService {
  /// ORCID se keywords, papers aur (agar public ho) email laata hai
  static Future<void> enrich(String orcid, ProfInfo info) async {
    final id = orcid.trim();
    if (id.isEmpty) return;
    const headers = {'Accept': 'application/json'};

    Future<dynamic> get(String path) async {
      try {
        final r = await http
            .get(Uri.parse('https://pub.orcid.org/v3.0/$id/$path'),
                headers: headers)
            .timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) return jsonDecode(r.body);
      } catch (_) {}
      return null;
    }

    final results =
        await Future.wait([get('keywords'), get('works'), get('person')]);

    try {
      final kw = results[0]?['keyword'];
      if (kw is List) {
        info.orcidKeywords = kw
            .map((k) => (k['content'] ?? '').toString().trim())
            .where((k) => k.isNotEmpty)
            .take(15)
            .toList();
      }
    } catch (_) {}

    try {
      final groups = results[1]?['group'];
      if (groups is List) {
        for (final g in groups) {
          final summaries = g['work-summary'];
          if (summaries is! List || summaries.isEmpty) continue;
          final t = summaries.first['title']?['title']?['value'];
          if (t != null && t.toString().trim().isNotEmpty) {
            info.orcidWorks.add(t.toString().trim());
          }
          if (info.orcidWorks.length >= 8) break;
        }
      }
    } catch (_) {}

    try {
      final emails = results[2]?['emails']?['email'];
      if (emails is List) {
        info.orcidEmails = emails
            .map((e) => (e['email'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
  }
}
