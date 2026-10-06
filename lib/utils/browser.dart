import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Link browser mein kholta hai (Flutter web). Na khule to link copy kar deta hai.
Future<void> openUrl(BuildContext context, String u) async {
  try {
    final isMail = u.startsWith('mailto:');
    final w = web.window.open(u, isMail ? '_self' : '_blank');
    if (isMail || w != null) return;
  } catch (e) {
    debugPrint('openUrl error: $e');
  }
  await Clipboard.setData(ClipboardData(text: u));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Popup block ho gaya. Link copy kar diya hai, browser mein paste karein.')),
    );
  }
}
