import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CvService {
  static Future<Map<String, String>?> pickAndUploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('cvs')
        .child('${user.uid}_${file.name}');

    TaskSnapshot snapshot;
    if (kIsWeb) {
      snapshot = await storageRef.putData(
        file.bytes!,
        SettableMetadata(contentType: 'application/pdf'),
      );
    } else {
      snapshot = await storageRef.putFile(
        File(file.path!),
        SettableMetadata(contentType: 'application/pdf'),
      );
    }

    final downloadUrl = await snapshot.ref.getDownloadURL();
    return {
      'name': file.name,
      'url': downloadUrl,
    };
  }
}