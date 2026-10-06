import 'package:flutter/material.dart';
import '../services/profile_store.dart';
import '../services/cv_service.dart';
import '../utils/browser.dart';

Future<UserProfile?> showProfileDialog(BuildContext context, UserProfile current) {
  final nameCtrl = TextEditingController(text: current.name);
  final profileCtrl = TextEditingController(text: current.text);
  String currentCvName = current.cvName;
  String currentCvUrl = current.cvUrl;

  return showDialog<UserProfile>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('My Profile & CV'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: profileCtrl,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Profile Details',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Resume / CV', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentCvName.isEmpty ? 'No CV uploaded' : currentCvName,
                        style: TextStyle(
                          color: currentCvName.isEmpty ? Colors.grey : Colors.blue,
                          decoration: currentCvName.isEmpty ? TextDecoration.none : TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (currentCvUrl.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => openUrl(context, currentCvUrl),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await CvService.pickAndUploadCv();
                          if (result != null) {
                            setState(() {
                              currentCvName = result['name']!;
                              currentCvUrl = result['url']!;
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload failed: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final p = UserProfile(
                name: nameCtrl.text.trim(),
                text: profileCtrl.text.trim(),
                cvName: currentCvName,
                cvUrl: currentCvUrl,
              );
              await ProfileStore.save(p);
              if (dialogContext.mounted) Navigator.pop(dialogContext, p);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}