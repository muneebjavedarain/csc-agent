import 'package:flutter/material.dart';
import '../services/search_service.dart';
import 'message_dialog.dart';

/// Search index banane ka flow (confirm -> progress -> result).
/// true wapas deta hai agar index chala (taake list refresh ho sake).
Future<bool> showIndexBuilder(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Search index banayein?'),
      content: const Text(
          'Yeh har professor ke document mein search ke liye ek field '
          '(searchTokens) likhega. 20,000 docs ke liye takreeban 20,000 writes '
          'lagengi (Firebase free limit 20,000 writes/din hai). Beech mein '
          'ruk jaye to dobara chalayein, jo ho chuke woh skip ho jayenge.\n\n'
          'Sirf ek dafa karna hai.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Shuru karein')),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;

  final status = ValueNotifier<String>('Shuru ho raha hai...');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Index ban raha hai'),
      content: ValueListenableBuilder<String>(
        valueListenable: status,
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(v),
          ],
        ),
      ),
    ),
  );

  final report = await SearchService.buildIndex((s) => status.value = s);

  if (!context.mounted) return true;
  Navigator.pop(context); // progress dialog band
  showMessageDialog(
    context,
    report.error == null ? 'Index tayyar' : 'Index adhoora reh gaya',
    report.error == null
        ? 'Update hue: ${report.updated}, pehle se theek: ${report.skipped}. Ab search poore 20,000 professors mein chalegi.'
        : 'Update hue: ${report.updated}.\n\nError: ${report.error}\n\nAgar "permission-denied" hai to Firestore Rules mein professors par write allow karein, aur agar quota ka error hai to kal dobara chalayein (jo ho chuke woh skip honge).',
  );
  return true;
}
