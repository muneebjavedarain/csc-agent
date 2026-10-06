import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prof_info.dart';
import '../utils/browser.dart';
import '../utils/professor_utils.dart';
import '../utils/text_utils.dart';

void showEmailResultDialog(
    BuildContext context,
    Map<String, dynamic> professorData,
    ProfInfo info,
    String text,
    VoidCallback onMarkSent,
    VoidCallback onMarkNoEmail,
    ) {
  final emails = <String, String>{};

  // Database ki email sab se pehle (agar maujood ho)
  final dbEmail = (professorData['email'] ?? '').toString().trim();
  if (dbEmail.isNotEmpty) emails[dbEmail] = 'database';

  for (final e in info.homepageEmails) {
    emails.putIfAbsent(e, () => 'homepage');
  }
  for (final e in info.orcidEmails) {
    emails.putIfAbsent(e, () => 'ORCID');
  }

  final validEmails = emails.keys.where((e) => looksLikeEmail(e)).toList();
  final allEmailsString = validEmails.join(',');
  // Gmail ke "To" mein: database ki email, warna link se mili hui
  final toAddress = looksLikeEmail(dbEmail)
      ? dbEmail
      : (validEmails.isNotEmpty ? allEmailsString : '');

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Email for ${cleanName(professorData['name'])}'),
      content: SizedBox(
        width: 980,
        height: 520,
        child: LayoutBuilder(builder: (c, box) {
          final wide = MediaQuery.of(c).size.width > 850;
          final emailBox = SingleChildScrollView(child: SelectableText(text));
          final side = ProfessorInfoBox(
              professorData: professorData, info: info, emails: emails);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: emailBox),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: side),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: emailBox),
              const Divider(),
              Expanded(child: side),
            ],
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final parts = splitEmail(text);
            openUrl(context,
                'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(toAddress)}&su=${Uri.encodeComponent(parts[0])}&body=${Uri.encodeComponent(parts[1])}');
          },
          child: const Text('Gmail mein kholein'),
        ),
        TextButton(
          onPressed: () {
            final parts = splitEmail(text);
            openUrl(context,
                'mailto:$toAddress?subject=${Uri.encodeComponent(parts[0])}&body=${Uri.encodeComponent(parts[1])}');
          },
          child: const Text('Mail app'),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Email copy ho gayi')),
            );
          },
          child: const Text('Copy'),
        ),
        // Email address nahi mila to isay dabayein
        OutlinedButton.icon(
          onPressed: () {
            onMarkNoEmail(); // Dashboard mein "Email nahi mili" mark ho jayega
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('"Email nahi mili" filter mein add ho gaya')),
            );
          },
          icon: const Icon(Icons.do_not_disturb_alt_outlined),
          label: const Text('Email nahi mili'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade700),
            // Koi email na mili ho to button halka narangi dikhega
            backgroundColor: validEmails.isEmpty ? Colors.orange.shade50 : null,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            onMarkSent(); // Dashboard mein Emailed mark ho jayega
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emailed filter mein add ho gaya!')),
            );
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Mark as Sent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class ProfessorInfoBox extends StatelessWidget {
  final Map<String, dynamic> professorData;
  final ProfInfo info;
  final Map<String, String> emails;

  const ProfessorInfoBox({
    super.key,
    required this.professorData,
    required this.info,
    required this.emails,
  });

  Widget sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(t,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87)),
  );

  Widget linkRow(BuildContext context, String label, String url) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: url, style: const TextStyle(color: Colors.blue)),
              ]),
              style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Kholein',
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () => openUrl(context, url),
        ),
      ],
    );
  }

  Widget emailRow(String email, String source) {
    final ok = looksLikeEmail(email);
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.warning_amber,
            size: 16, color: ok ? Colors.green : Colors.orange),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText('$email  ($source)',
              style: const TextStyle(fontSize: 13)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () => Clipboard.setData(ClipboardData(text: email)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orcid = (professorData['orcid'] ?? '').toString().trim();
    final scholar = (professorData['scholarid'] ?? '').toString().trim();
    final homepage = (professorData['homepage'] ?? '').toString().trim();

    final links = <String, String>{};
    if (homepage.isNotEmpty) links['Homepage'] = homepage;
    // 0000-0000-0000-0000 aur NOSCHOLARPAGE data mein placeholder hain, asli ID nahi
    if (orcid.isNotEmpty && orcid != '0000-0000-0000-0000') {
      links['ORCID'] = 'https://orcid.org/$orcid';
    }
    if (scholar.isNotEmpty && scholar.toUpperCase() != 'NOSCHOLARPAGE') {
      links['Google Scholar'] =
      'https://scholar.google.com/citations?user=$scholar';
    }
    for (var i = 0; i < info.otherLinks.length; i++) {
      links['Link ${i + 1}'] = info.otherLinks[i];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Professor info (bhejne se pehle verify karein)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            sectionTitle('Email address'),
            if (emails.isEmpty)
              const Text(
                  'Database, homepage ya ORCID par koi email nahi mili. '
                      'Professor ke page par khud dhoondein.',
                  style: TextStyle(fontSize: 12)),
            for (final e in emails.entries) emailRow(e.key, e.value),
            if (emails.isNotEmpty)
              const Text(
                  'Email AI ne jama ki hai ya page se padhi hai. Bhejne se pehle homepage se match zaroor karein.',
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
            if (info.title != null || info.department != null) ...[
              sectionTitle('Title / Department'),
              Text(
                  [info.title, info.department]
                      .whereType<String>()
                      .join(' • '),
                  style: const TextStyle(fontSize: 13)),
            ],
            for (final f in const [
              ['research_area', 'Research area (database)'],
              ['last_research', 'Recent work (AI se jama, verify karein)'],
              ['research_topic', 'Suggested topic (AI ka idea, verify karein)'],
            ])
              if ((professorData[f[0]] ?? '').toString().trim().isNotEmpty) ...[
                sectionTitle(f[1]),
                SelectableText(professorData[f[0]].toString(),
                    style: const TextStyle(fontSize: 12)),
              ],
            sectionTitle('Links'),
            if (links.isEmpty)
              const Text('Koi link nahi mila', style: TextStyle(fontSize: 12)),
            for (final l in links.entries) linkRow(context, l.key, l.value),
            if (info.areas.isNotEmpty) ...[
              sectionTitle('Research areas (homepage se)'),
              Text(info.areas.join(', '), style: const TextStyle(fontSize: 13)),
            ],
            if (info.orcidKeywords.isNotEmpty) ...[
              sectionTitle('ORCID keywords'),
              Text(info.orcidKeywords.join(', '),
                  style: const TextStyle(fontSize: 13)),
            ],
            if (info.orcidWorks.isNotEmpty) ...[
              sectionTitle('Papers (ORCID se)'),
              for (final w in info.orcidWorks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $w', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}