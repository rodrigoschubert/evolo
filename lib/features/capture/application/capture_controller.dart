import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_media_service.dart';
import '../../projects/application/projects_controller.dart';

final captureControllerProvider = Provider<CaptureController>((ref) {
  return CaptureController(ref);
});

class CaptureController {
  const CaptureController(this._ref);

  final Ref _ref;

  Future<void> saveCapture({
    required String projectId,
    required String temporaryPath,
  }) async {
    final imagePath = await LocalMediaService().persistCapture(
      projectId: projectId,
      temporaryPath: temporaryPath,
    );

    await _ref
        .read(projectsControllerProvider.notifier)
        .addCapture(projectId: projectId, imagePath: imagePath);
  }
}
