import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    debugPrint('Evolo [PermissionService]: current camera status: $status');
    return status.isGranted;
  }

  Future<bool> ensureCameraPermission() async {
    final statusBefore = await Permission.camera.status;
    debugPrint('Evolo [PermissionService]: status before request: $statusBefore');
    
    if (statusBefore.isGranted) {
      return true;
    }

    // On Android, if it's already denied, request() will show the dialog again.
    // If it's permanently denied, it won't.
    final requested = await Permission.camera.request();
    debugPrint('Evolo [PermissionService]: status after request: $requested');

    return requested.isGranted;
  }

  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
