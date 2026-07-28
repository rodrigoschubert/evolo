import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/projects/domain/capture_entry.dart';
import '../constants/app_constants.dart';

/// Result of an import operation.
class ImportResult {
  const ImportResult({
    required this.captures,
    required this.totalSelected,
    required this.totalImported,
    required this.withExifCount,
  });

  final List<CaptureEntry> captures;
  final int totalSelected;
  final int totalImported;
  final int withExifCount;
}

/// Handles picking, processing, and persisting imported images.
class ImportService {
  static const _uuid = Uuid();
  static const int maxBatchSize = 50;
  static const int maxDimensionPx = 3840; // 4K max
  static const int jpegQuality = 92;

  final ImagePicker _picker = ImagePicker();

  /// Opens the system gallery picker for multi-image selection.
  /// Returns null if the user cancels.
  Future<List<XFile>?> pickImages() async {
    final files = await _picker.pickMultiImage(
      limit: maxBatchSize,
      requestFullMetadata: true,
    );
    if (files.isEmpty) return null;
    return files.take(maxBatchSize).toList();
  }

  /// Processes selected images: reads EXIF, resizes, converts to JPEG,
  /// copies to project directory, and returns CaptureEntry list.
  ///
  /// [onProgress] is called with (currentIndex, totalCount) for UI updates.
  Future<ImportResult> processImages({
    required String projectId,
    required List<XFile> files,
    required int existingSortOrderMax,
    void Function(int current, int total)? onProgress,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      p.join(documents.path, AppConstants.capturesDirectory, projectId),
    );
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    // Step 1: Read EXIF dates for all files
    final fileDataList = <_FileWithDate>[];
    for (final file in files) {
      final exifDate = await _readExifDate(file);
      fileDataList.add(_FileWithDate(file: file, exifDate: exifDate));
    }

    // Step 2: Sort — files with EXIF by date, files without EXIF keep selection order
    final withExif = fileDataList.where((f) => f.exifDate != null).toList()
      ..sort((a, b) => a.exifDate!.compareTo(b.exifDate!));
    final withoutExif = fileDataList.where((f) => f.exifDate == null).toList();
    final sorted = [...withExif, ...withoutExif];

    // Step 3: Process each image
    final captures = <CaptureEntry>[];
    var sortOrder = existingSortOrderMax + 1;

    for (var i = 0; i < sorted.length; i++) {
      onProgress?.call(i + 1, sorted.length);

      final item = sorted[i];
      try {
        final persistedPath = await _processAndSaveImage(
          item.file,
          targetDir.path,
        );

        final createdAt = item.exifDate ?? DateTime.now();

        captures.add(CaptureEntry(
          id: _uuid.v4(),
          projectId: projectId,
          imagePath: persistedPath,
          createdAt: createdAt,
          source: 'import',
          sortOrder: sortOrder,
        ));
        sortOrder++;
      } catch (e) {
        debugPrint('Evolo [ImportService]: Failed to process image ${item.file.name}: $e');
        // Skip failed images, continue with the rest
      }
    }

    return ImportResult(
      captures: captures,
      totalSelected: files.length,
      totalImported: captures.length,
      withExifCount: withExif.length,
    );
  }

  /// Reads the EXIF DateTimeOriginal from an image file.
  Future<DateTime?> _readExifDate(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);
      if (tags.isEmpty) return null;

      // Try DateTimeOriginal first, then DateTimeDigitized, then DateTime
      final dateTag = tags['EXIF DateTimeOriginal']
          ?? tags['EXIF DateTimeDigitized']
          ?? tags['Image DateTime'];

      if (dateTag == null) return null;

      // EXIF format: "2024:07:15 14:30:00"
      final dateStr = dateTag.toString().trim();
      if (dateStr.isEmpty || dateStr == '0000:00:00 00:00:00') return null;

      final normalized = dateStr.replaceFirst(
        RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
        r'$1-$2-$3',
      );
      return DateTime.tryParse(normalized);
    } catch (_) {
      return null;
    }
  }

  /// Decodes, resizes (if needed), converts to JPEG, and saves to target dir.
  Future<String> _processAndSaveImage(XFile file, String targetDirPath) async {
    final bytes = await file.readAsBytes();

    // Run the heavy image processing in an isolate
    final processedBytes = await compute(_resizeAndEncode, bytes);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = p.join(targetDirPath, '$timestamp.jpg');
    await File(targetPath).writeAsBytes(processedBytes);

    return targetPath;
  }

  /// Static function for compute() isolate — decodes, resizes, and encodes.
  static Uint8List _resizeAndEncode(Uint8List inputBytes) {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }

    img.Image result = decoded;

    // Resize if larger than max dimension
    final maxSide = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (maxSide > maxDimensionPx) {
      if (decoded.width > decoded.height) {
        result = img.copyResize(decoded, width: maxDimensionPx);
      } else {
        result = img.copyResize(decoded, height: maxDimensionPx);
      }
    }

    // Encode to JPEG
    return Uint8List.fromList(img.encodeJpg(result, quality: jpegQuality));
  }
}

class _FileWithDate {
  const _FileWithDate({required this.file, this.exifDate});
  final XFile file;
  final DateTime? exifDate;
}
