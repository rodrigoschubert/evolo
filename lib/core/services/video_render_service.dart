import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
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
    void Function(double progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) return null;

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
        final safePath = path.replaceAll("'", "'\\''");
        sb.writeln("file '$safePath'");
        sb.writeln("duration ${1.0 / fps}");
      }
      final lastSafePath = imagePaths.last.replaceAll("'", "'\\''");
      sb.writeln("file '$lastSafePath'");

      await concatFile.writeAsString(sb.toString());

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/evolo_timelapse_$timestamp.mp4';

      if (File(outputPath).existsSync()) {
        File(outputPath).deleteSync();
      }

      // 3. Setup FFmpeg Command
      // Note: Implementing real xfade in FFmpeg via concat demuxer is extremely complex.
      // For now, we apply the chosen resolution and maintain high quality.
      String filter = "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:black";
      
      final command = "-f concat -safe 0 -i '$concatFilePath' "
          "-vsync vfr -pix_fmt yuv420p -c:v libx264 -crf 18 "
          "-vf \"$filter\" "
          "'$outputPath'";

      final totalFrames = imagePaths.length;
      
      // Listen to progress
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((statistics) {
          // statistics.getVideoFrameNumber() gives the encoded frames so far.
          // Due to the way concat works with duration, the frame count might differ,
          // but we can estimate progress based on time or just give a generic progress.
          // Since we use variable framerate, estimating via time is better.
          final time = statistics.getTime(); // in milliseconds
          final totalDurationMs = (totalFrames * (1000 / fps)).round();
          
          if (time > 0 && totalDurationMs > 0) {
            double progress = time / totalDurationMs;
            if (progress > 1.0) progress = 1.0;
            onProgress(progress);
          }
        });
      }

      // 4. Run FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clear callback
      if (onProgress != null) {
        FFmpegKitConfig.disableStatistics();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      } else {
        final logs = await session.getLogsAsString();
        await ErrorTrackingService.captureException(
          Exception('FFmpeg failed with code $returnCode: $logs'),
          context: {'feature': 'video_render'},
        );
        return null;
      }
    } catch (e, stackTrace) {
      await ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: {'feature': 'video_render_exception'},
      );
      return null;
    }
  }
}
