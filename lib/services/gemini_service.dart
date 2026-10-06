import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GeminiService {
  /// Browser mein save ki hui key (app chalne par set hoti hai)
  static String runtimeKey = '';

  /// Gemini ko REST se call karta hai. useUrlContext=true ho to Gemini
  /// diye gaye links khud khol kar parh sakta hai (url_context tool).
  /// 503/timeout par retry, model band ho to agla model.
  static Future<String?> generate(String prompt,
      {bool useUrlContext = false, bool allowNoToolFallback = true}) async {
    final key = runtimeKey.isNotEmpty ? runtimeKey : apiKey;
    if (key.isEmpty) {
      throw Exception(
          'Gemini API key set nahi hai. Upar chaabi (key) wale icon se apni key daalein.');
    }

    for (final name in geminiModels) {
      for (var attempt = 0; attempt < 2; attempt++) {
        http.Response res;
        try {
          res = await http
              .post(
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$name:generateContent'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              if (useUrlContext)
                'tools': [
                  {'url_context': {}}
                ],
            }),
          )
              .timeout(const Duration(seconds: 25));
        } on TimeoutException {
          // Server slow tha, crash mat ho — agla attempt/model try karo
          continue;
        } catch (_) {
          // Network ka koi aur masla — agla attempt/model try karo
          continue;
        }

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final parts =
              (data['candidates']?[0]?['content']?['parts'] as List?) ?? [];
          final text = parts
              .map((p) => (p['text'] ?? '').toString())
              .where((t) => t.isNotEmpty)
              .join('\n')
              .trim();
          if (text.isNotEmpty) return text;
          if (useUrlContext && allowNoToolFallback) {
            return generate(prompt, useUrlContext: false);
          }
          return null;
        }

        final body = res.body;
        final busy = res.statusCode == 503 ||
            res.statusCode == 429 ||
            body.contains('UNAVAILABLE');
        final unavailable =
            res.statusCode == 404 || body.contains('no longer available');

        if (unavailable) break; // is model ko chhorho, agla try karo
        if (busy) {
          await Future.delayed(Duration(seconds: 1 + attempt));
          continue;
        }
        // Koi aur error: agar url tool ki wajah se ho to bina tool ke try karo
        if (useUrlContext) {
          if (allowNoToolFallback) {
            return generate(prompt, useUrlContext: false);
          }
          return null;
        }
        throw Exception('Gemini error ${res.statusCode}: $body');
      }
    }
    return null; // sab models busy / slow
  }
}