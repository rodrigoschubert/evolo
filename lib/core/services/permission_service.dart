import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    final requested = await Permission.camera.request();
    return requested.isGranted;
  }
}
