import '../models/prof_info.dart';
import '../utils/text_utils.dart';
import 'gemini_service.dart';

class HomepageService {
  /// Gemini (url_context tool) se professor ka homepage khulwa kar
  /// title, email, research areas aur links nikalta hai.
  static Future<void> enrich(String url, ProfInfo info) async {
    if (!url.startsWith('http')) return;

    final prompt = '''
Open this professor's web page: $url

Return ONLY a JSON object (no markdown, no commentary) with exactly these keys:
{"title": ..., "email": [...], "department": ..., "research_areas": [...], "links": [...]}

Rules:
- "title": the academic title exactly as the page shows it (e.g. "Professor", "Associate Professor", "Dr"), or null.
- "email": list of email addresses that are written on the page. Copy them exactly. If the page obfuscates them (e.g. "name [at] uni.edu"), convert to normal form. NEVER guess or construct an address; use [] if none is shown.
- "department": the department/school shown on the page, or null.
- "research_areas": up to 6 short research topics stated on the page; [] if none.
- "links": up to 5 other useful absolute URLs found on the page (lab website, Google Scholar, GitHub, personal site); [] if none.
- If you cannot open the page, return {"error": "cannot open"}.
''';

    try {
      // Homepage parhna sab se sust step hai; 20 second se zyada wait na karo,
      // warna bina homepage info ke email jaldi ban jaye.
      final text = await GeminiService.generate(prompt,
          useUrlContext: true, allowNoToolFallback: false)
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
      if (text == null) return;
      final j = parseJsonObject(text);
      if (j == null || j['error'] != null) return;

      final title = j['title']?.toString().trim();
      final dept = j['department']?.toString().trim();
      info.title = (title == null || title.isEmpty || title == 'null')
          ? null
          : title;
      info.department = (dept == null || dept.isEmpty || dept == 'null')
          ? null
          : dept;
      info.homepageEmails = asStrings(j['email']);
      info.areas = asStrings(j['research_areas']);
      info.otherLinks =
          asStrings(j['links']).where((l) => l.startsWith('http')).toList();
    } catch (_) {}
  }
}