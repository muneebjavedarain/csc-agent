import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CvService {
  static Future<Map<String, String>?> pickAndUploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) throw Exception('File data read nahi ho saka');

    final fileName = file.name;
    final ref = FirebaseStorage.instance
        .ref('cvs/${DateTime.now().millisecondsSinceEpoch}_$fileName');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final url = await ref.getDownloadURL();

    return {
      'name': fileName,
      'url': url,
    };
  }
}