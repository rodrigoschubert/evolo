import 'dart:convert';

import 'package:cross_file/cross_file.dart';

class LocalMediaService {
  Future<String> persistCapture({
    required String projectId,
    required String temporaryPath,
  }) async {
    final bytes = await XFile(temporaryPath).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> deleteProjectMedia(String projectId) async {
    // No-op for web (stored as base64 in IndexedDB/Storage via Sqflite)
  }

  Future<void> deleteCaptureMedia(String imagePath) async {
    // No-op for web
  }
}
