import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CvService {
  static Future<Map<String, String>?> pickAndUploadCv() async {
    // ---- Stage 1: file pick ----
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
    } catch (e, st) {
      debugPrint('CV [PICK] error: $e\n$st');
      throw Exception('PICK stage failed: $e');
    }

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('PICK stage: file data read nahi ho saka');
    }

    final fileName = file.name;
    debugPrint('CV [PICK] ok: $fileName (${bytes.length} bytes)');

    // ---- Stage 2: upload to Firebase Storage ----
    final String path =
        'cvs/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    late final Reference ref;
    try {
      ref = FirebaseStorage.instance.ref(path);
      await ref
          .putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      )
          .timeout(const Duration(seconds: 60));
    } catch (e, st) {
      debugPrint('CV [UPLOAD] error: $e\n$st');
      throw Exception('UPLOAD stage failed: $e');
    }
    debugPrint('CV [UPLOAD] ok: $path');

    // ---- Stage 3: download URL ----
    String url;
    try {
      url = await ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('CV [URL] error: $e\n$st');
      throw Exception('URL stage failed: $e');
    }
    debugPrint('CV [URL] ok');

    return {
      'name': fileName,
      'url': url,
    };
  }
}