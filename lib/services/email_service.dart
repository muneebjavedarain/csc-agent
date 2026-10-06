import '../models/prof_info.dart';
import '../utils/professor_utils.dart';
import '../utils/text_utils.dart';
import 'gemini_service.dart';
import 'orcid_service.dart';
import 'profile_store.dart';

class EmailDraft {
  final String text;
  final ProfInfo info;
  const EmailDraft({required this.text, required this.info});
}

class EmailService {
  static bool _plausibleEmail(String e) {
    if (!looksLikeEmail(e)) return false;
    final lower = e.toLowerCase();
    const fakeParts = ['example.com', 'domain.com', 'yourdomain', 'youremail'];
    if (fakeParts.any(lower.contains)) return false;
    const genericLocals = [
      'name',
      'email',
      'user',
      'yourname',
      'firstname.lastname'
    ];
    return !genericLocals.contains(lower.split('@').first);
  }

  static Future<EmailDraft?> generate({
    required Map<String, dynamic> professor,
    required UserProfile profile,
  }) async {
    String field(String k) => (professor[k] ?? '').toString().trim();

    final name = profile.name.isEmpty ? '[Your Name]' : profile.name;
    final profName = cleanName(field('name'))
        .replaceAll(RegExp(r'\s*[\(（].*?[\)）]'), '')
        .trim();
    final affiliation = field('affiliation');
    final area = field('research_area');
    final lastResearch = field('last_research');
    final topic = field('research_topic');
    final country = field('country');
    final homepage = field('homepage');
    final orcid = field('orcid');
    final profileText = profile.text;

    final hasDbResearch = area.isNotEmpty || lastResearch.isNotEmpty;
    final canOpenPage = !hasDbResearch && homepage.startsWith('http');
    final isKorea = country.toLowerCase().contains('korea') ||
        affiliation.toLowerCase().contains('korea');

    final info = ProfInfo();
    if (!hasDbResearch && orcid.isNotEmpty && orcid != '0000-0000-0000-0000') {
      await OrcidService.enrich(orcid, info);
      info.orcidEmails = [];
    }

    final basic = [
      if (profName.isNotEmpty) '- name: $profName',
      if (affiliation.isNotEmpty) '- affiliation: $affiliation',
      if (country.isNotEmpty) '- country: $country',
    ].join('\n');

    final dbBlock = StringBuffer();
    if (area.isNotEmpty) dbBlock.writeln('- Research areas: $area');
    if (lastResearch.isNotEmpty) {
      dbBlock.writeln('- Recent work: $lastResearch');
    }
    if (topic.isNotEmpty) {
      dbBlock.writeln(
          '- A possible research direction (written for a different applicant, use only as loose inspiration): $topic');
    }

    final orcidBlock = StringBuffer();
    if (info.orcidKeywords.isNotEmpty) {
      orcidBlock.writeln('ORCID keywords: ${info.orcidKeywords.join(', ')}');
    }
    if (info.orcidWorks.isNotEmpty) {
      orcidBlock.writeln('Publication titles (ORCID):');
      for (final t in info.orcidWorks) {
        orcidBlock.writeln('- $t');
      }
    }

    final String scholarshipRule;
    if (isMainlandChina(professor)) {
      scholarshipRule =
      'The university is in mainland China. Naturally mention that the applicant plans to apply for the Chinese Government Scholarship (CSC) for Fall 2027 and would need the professor\'s acceptance/support for it.';
    } else if (isKorea) {
      scholarshipRule =
      'Do NOT mention CSC or the Chinese Government Scholarship. The university is in South Korea, so you may briefly say the applicant intends to apply for the Global Korea Scholarship (GKS) or university scholarships for the 2027 intake.';
    } else {
      scholarshipRule =
      'IMPORTANT: Do NOT mention CSC or the Chinese Government Scholarship anywhere in this email. Instead, say briefly that the applicant intends to apply for scholarships/funding available through the university or its country for the 2027 intake, without naming a specific scheme unless you are certain it exists.';
    }

    String buildPrompt({required bool withPage}) {
      final outputRule = withPage
          ? '''Output format — EXACTLY this, nothing else:
---EMAIL---
(the email here, starting with the Subject line)
---INFO---
(a single JSON object with exactly these keys: {"title": ..., "email": [...], "department": ..., "research_areas": [...], "links": [...]}.
"title": the professor's academic title if the page shows it, else null.
"email": email addresses written on the page for THIS professor. Look at mailto: links, "Contact" sections and obfuscated forms such as "name [at] uni.edu" or "name at uni dot edu" and convert them to normal form. Copy exactly. Do not return department, secretary or admin addresses unless the page shows nothing else. Never guess or build an address from the name or the university domain; use [] if none is shown.
"department": department/school shown on the page, else null.
"research_areas": up to 6 short research topics actually stated on the page; [] if none.
"links": up to 5 other useful absolute URLs found on the page (lab site, Google Scholar, GitHub); [] if none.
If you could not open the page, use null/[] for all of the above.)'''
          : 'Output ONLY the email text, starting with the Subject line. No commentary.';

      return '''
${withPage ? 'First, open this professor\'s web page: $homepage\n' : ''}
Write a professional, personalised cold email FROM the applicant TO the professor below, asking about MS supervision / openings.

Professor information from our database:
$basic

Research information from our database (collected earlier by an AI web search, so it may contain mistakes):
${dbBlock.isEmpty ? '(none available)' : dbBlock}
${orcidBlock.isEmpty ? '' : 'Extra research info from ORCID:\n$orcidBlock'}
Applicant name: $name
Applicant details (written by the applicant, may be in Urdu/Roman Urdu/English):
"""
$profileText
"""

Personalisation rules:
- Mention the university by name and show the email was written for this specific university and country, using only safe, general and well-known facts. Do not invent facts about the university.
- Surname: if the professor's name contains a comma, the part before the comma is the surname; otherwise the surname is usually the last word. Use the exact title shown on the page if you opened it; otherwise write "Dear Professor [Surname]" and do not guess a title.
- If research areas or recent work are given (database, ORCID or the page), build the email around 1-2 of those themes and pick the 1-2 applicant strengths or projects that match best. Refer to recent work in a hedged way (for example "I noticed your group's recent work on ...") and never claim to have read the papers in depth. If no research info is available, do NOT invent research topics; keep the research reference general.
- Never claim applicant skills or experience that are not in the applicant details, even if the "possible research direction" mentions them.
- $scholarshipRule

General rules:
- Formal, natural English. Include a Subject line at the top (specific, e.g. include the university or field). Do not use markdown or asterisks.
- Use ONLY facts from the applicant details. Never invent degrees, grades, publications or projects. If something important is missing, use a placeholder like [add detail].
- When you mention the applicant's flagship project (CRAFT), include its live demo link exactly as given in the applicant details.
- Use "Fall 2027" only for universities in China, the USA or Canada. For other countries write "2027 intake" instead of "Fall".
- Do not paste every detail of the profile; keep it focused, about 150-200 words, so it does not read like a template.
- End with a polite request for guidance/openings and sign off with the applicant's name and email (and phone only if it fits naturally).

$outputRule
''';
    }

    String? raw;
    var pageRead = false;
    if (canOpenPage) {
      raw = await GeminiService.generate(buildPrompt(withPage: true),
          useUrlContext: true, allowNoToolFallback: false);
      pageRead = raw != null && raw.trim().isNotEmpty;
    }
    if (raw == null || raw.trim().isEmpty) {
      pageRead = false;
      raw = await GeminiService.generate(buildPrompt(withPage: false));
    }
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = splitEmailAndInfo(raw);
    var text = parts.$1.replaceAll('**', '').trim();
    if (text.isEmpty) return null;

    if (profile.cvUrl.isNotEmpty) {
      text += '\n\nMy Resume/CV: ${profile.cvUrl}';
    }

    if (pageRead) {
      final j = parseJsonObject(parts.$2);
      if (j != null && j['error'] == null) {
        final title = j['title']?.toString().trim();
        final dept = j['department']?.toString().trim();
        info.title =
        (title == null || title.isEmpty || title == 'null') ? null : title;
        info.department =
        (dept == null || dept.isEmpty || dept == 'null') ? null : dept;
        info.homepageEmails =
            asStrings(j['email']).where(_plausibleEmail).toList();
        info.areas = asStrings(j['research_areas']);
        info.otherLinks =
            asStrings(j['links']).where((l) => l.startsWith('http')).toList();
      }
    }

    return EmailDraft(text: text, info: info);
  }
}