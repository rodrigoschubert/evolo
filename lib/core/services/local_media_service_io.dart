import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class LocalMediaService {
  Future<String> persistCapture({
    required String projectId,
    required String temporaryPath,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, AppConstants.capturesDirectory, projectId),
    );

    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final extension = p.extension(temporaryPath).isEmpty
        ? '.jpg'
        : p.extension(temporaryPath);
    final targetPath = p.join(
      directory.path,
      '${DateTime.now().millisecondsSinceEpoch}$extension',
    );

    final file = File(temporaryPath);
    await file.copy(targetPath);
    return targetPath;
  }

  Future<void> deleteProjectMedia(String projectId) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, AppConstants.capturesDirectory, projectId),
    );

    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> deleteCaptureMedia(String imagePath) async {
    final file = File(imagePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
