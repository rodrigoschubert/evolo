import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_https_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_https_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'error_tracking_service.dart';

class VideoRenderService {
  VideoRenderService._();

  static final instance = VideoRenderService._();

  /// Renders a timelapse video from a list of image paths.
  /// [fps] is frames per second.
  Future<String?> renderTimelapse(
      List<String> imagePaths, {
        int fps = 4,
        String resolution = '1080p',
        String transition = 'cut',
        bool isPremium = false,
        void Function(double progress)? onProgress,
      }) async {
    debugPrint('Evolo [VideoRenderService]: renderTimelapse starting for ${imagePaths.length} images');
    if (imagePaths.isEmpty) {
      debugPrint('Evolo [VideoRenderService]: imagePaths is empty');
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();

      // Define resolution dimensions
      int width = 1080;
      int height = 1920;
      if (resolution == '4k') {
        width = 2160;
        height = 3840;
      }

      // 1. Create a concat file
      final concatFilePath = '${tempDir.path}/ffmpeg_concat.txt';
      final concatFile = File(concatFilePath);

      final sb = StringBuffer();
      for (final path in imagePaths) {
        // Use forward slashes for ffmpeg paths even on windows/android
        final normalizedPath = path.replaceAll('\\', '/');
        final safePath = normalizedPath.replaceAll("'", "'\\''");
        sb.writeln("file '$safePath'");
        sb.writeln("duration ${1.0 / fps}");
      }
      // Add the last image again to prevent it from disappearing instantly
      final lastPath = imagePaths.last.replaceAll('\\', '/');
      final lastSafePath = lastPath.replaceAll("'", "'\\''");
      sb.writeln("file '$lastSafePath'");

      await concatFile.writeAsString(sb.toString());
      debugPrint('Evolo [VideoRenderService]: Concat file created at $concatFilePath');

      // 2. Prepare watermark if not premium
      String? watermarkPath;
      if (!isPremium) {
        try {
          final byteData = await rootBundle.load('assets/images/watermark.png');
          final watermarkFile = File('${tempDir.path}/watermark_temp.png');
          await watermarkFile.writeAsBytes(byteData.buffer.asUint8List());
          watermarkPath = watermarkFile.path.replaceAll('\\', '/');
          debugPrint('Evolo [VideoRenderService]: Watermark prepared at $watermarkPath');
        } catch (e) {
          debugPrint('Evolo [VideoRenderService]: Could not load watermark asset: $e');
        }
      }

      // 3. Define output video path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/evolo_timelapse_$timestamp.mp4';

      if (File(outputPath).existsSync()) {
        File(outputPath).deleteSync();
      }

      // 4. Setup FFmpeg Command
      String filter = "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:black";

      String command;
      if (watermarkPath != null) {
        // Complex filter to overlay the watermark
        // [0:v] is the main video, [1:v] is the watermark
        // We scale the watermark to 40% of the video width and center it at the bottom
        final watermarkWidth = (width * 0.40).round();
        command = "-f concat -safe 0 -i '$concatFilePath' -i '$watermarkPath' "
            "-filter_complex \"[0:v]$filter[base]; [1:v]scale=$watermarkWidth:-1[wm]; [base][wm]overlay=(main_w-overlay_w)/2:main_h-overlay_h-100\" "
            "-fps_mode vfr -pix_fmt yuv420p -c:v libx264 -crf 18 "
            "-y '$outputPath'";
      } else {
        command = "-f concat -safe 0 -i '$concatFilePath' "
            "-fps_mode vfr -pix_fmt yuv420p -c:v libx264 -crf 18 "
            "-vf \"$filter\" "
            "-y '$outputPath'";
      }

      debugPrint('Evolo [VideoRenderService]: Executing command: $command');

      final totalFrames = imagePaths.length;

      // Listen to progress
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((statistics) {
          final time = statistics.getTime(); // in milliseconds
          final totalDurationMs = (totalFrames * (1000 / fps)).round();
          
          if (time > 0 && totalDurationMs > 0) {
            double progress = time / totalDurationMs;
            if (progress > 1.0) progress = 1.0;
            onProgress(progress);
          }
        });
      }

      // 5. Run FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getLogsAsString();

      debugPrint('Evolo [VideoRenderService]: FFmpeg finished with ReturnCode: $returnCode');
      if (!ReturnCode.isSuccess(returnCode)) {
        debugPrint('Evolo [VideoRenderService]: FFmpeg Logs:\n$logs');
      }

      // Clear callback
      if (onProgress != null) {
        FFmpegKitConfig.disableStatistics();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('Evolo [VideoRenderService]: Video generated at $outputPath');
        return outputPath;
      } else {
        await ErrorTrackingService.captureException(
          Exception('FFmpeg failed with code $returnCode: $logs'),
          context: {'feature': 'video_render', 'command': command},
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Evolo [VideoRenderService]: EXCEPTION during render: $e\n$stackTrace');
      await ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: {'feature': 'video_render_exception'},
      );
      return null;
    }
  }
}
