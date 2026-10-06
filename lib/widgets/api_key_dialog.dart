import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/profile_store.dart';

/// Gemini key paste karne ka dialog. Key sirf is browser mein save hoti hai.
Future<void> showApiKeyDialog(BuildContext context) async {
  final ctrl = TextEditingController(text: GeminiService.runtimeKey);
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Gemini API key'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key sirf is browser mein save hoti hai, code ya GitHub mein nahi jati.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final key = ctrl.text.trim();
            await ProfileStore.saveGeminiKey(key);
            GeminiService.runtimeKey = key;
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}