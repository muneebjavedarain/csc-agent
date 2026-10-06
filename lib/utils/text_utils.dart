import 'dart:convert';

List<String> asStrings(dynamic v) {
  if (v is String) v = [v];
  if (v is! List) return [];
  return v
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty && e != 'null')
      .toList();
}

Map<String, dynamic>? parseJsonObject(String t) {
  final a = t.indexOf('{');
  final b = t.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  try {
    return jsonDecode(t.substring(a, b + 1)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

bool looksLikeEmail(String e) =>
    RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(e);

/// [subject, body]
List<String> splitEmail(String text) {
  final lines = text.trim().split('\n');
  var subject = '';
  var start = 0;
  if (lines.isNotEmpty && lines.first.toLowerCase().startsWith('subject:')) {
    subject = lines.first.substring(8).trim();
    start = 1;
  }
  return [subject, lines.skip(start).join('\n').trim()];
}

/// Gemini ke combined jawab ko email hisse aur JSON info hisse mein todta hai.
/// (email text, info json text)
(String, String) splitEmailAndInfo(String raw) {
  final emailMark = raw.indexOf('---EMAIL---');
  final infoMark = raw.indexOf('---INFO---');
  if (emailMark == -1 || infoMark == -1 || infoMark < emailMark) {
    // Markers na milein to poora jawab hi email samjho
    return (raw.trim(), '');
  }
  final email = raw.substring(emailMark + '---EMAIL---'.length, infoMark).trim();
  final info = raw.substring(infoMark + '---INFO---'.length).trim();
  return (email, info);
}