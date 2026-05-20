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
    void Function(double progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      
      // 1. Create a concat file
      final concatFilePath = '${tempDir.path}/ffmpeg_concat.txt';
      final concatFile = File(concatFilePath);
      
      final sb = StringBuffer();
      for (final path in imagePaths) {
        // ffmpeg requires paths in concat files to be quoted if they have spaces,
        // and safely escaped.
        final safePath = path.replaceAll("'", "'\\''");
        sb.writeln("file '$safePath'");
        
        // duration of each frame
        sb.writeln("duration ${1.0 / fps}");
      }
      // Add the last image again to prevent it from disappearing instantly
      final lastSafePath = imagePaths.last.replaceAll("'", "'\\''");
      sb.writeln("file '$lastSafePath'");

      await concatFile.writeAsString(sb.toString());

      // 2. Define output video path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/evolo_timelapse_$timestamp.mp4';

      // Ensure the file doesn't exist
      if (File(outputPath).existsSync()) {
        File(outputPath).deleteSync();
      }

      // 3. Setup FFmpeg Command
      // -f concat: use the concat demuxer
      // -safe 0: allow unsafe paths
      // -i: input file
      // -vsync vfr: variable frame rate to honor the durations
      // -pix_fmt yuv420p: standard pixel format for high compatibility
      // -c:v libx264: H.264 codec
      // -crf 23: constant rate factor (quality)
      // -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black": 
      //    scales and pads the video to a standard 9:16 vertical 1080p without stretching
      final command = "-f concat -safe 0 -i '$concatFilePath' "
          "-vsync vfr -pix_fmt yuv420p -c:v libx264 -crf 23 "
          "-vf \"scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black\" "
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
