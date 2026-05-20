import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/error_tracking_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/evolo_image.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../projects/application/projects_controller.dart';
import '../application/capture_controller.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  // Global reference to the most recent camera controller disposal.
  // This allows new instances of CaptureScreen to await completion of the previous instance's
  // native release sequence, preventing "CameraUnavailable" and "CameraPrioritiesChanged" errors.
  static Future<void>? _lastDisposeFuture;

  CameraController? _cameraController;
  double _overlayOpacity = AppConstants.defaultOverlayOpacity;
  bool _permissionGranted = false;
  bool _saving = false;
  String? _cameraError;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Evolo [CaptureScreen]: initState started for projectId=${widget.projectId}');
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('Evolo [CaptureScreen]: PostFrameCallback fired but widget is not mounted');
        return;
      }
      final route = ModalRoute.of(context);
      debugPrint('Evolo [CaptureScreen]: PostFrameCallback route is ${route?.runtimeType}, isCurrent=${route?.isCurrent}');
      
      if (route != null && route.isCurrent) {
        if (route.animation?.isCompleted == true) {
          debugPrint('Evolo [CaptureScreen]: Route transition is already completed, initializing camera now.');
          _initializeCamera();
        } else {
          debugPrint('Evolo [CaptureScreen]: Route transition is active. Adding status listener.');
          void listener(AnimationStatus status) {
            debugPrint('Evolo [CaptureScreen]: Route animation status changed to $status');
            if (status == AnimationStatus.completed) {
              route.animation?.removeStatusListener(listener);
              debugPrint('Evolo [CaptureScreen]: Transition completed. Initializing camera now.');
              _initializeCamera();
            }
          }
          route.animation?.addStatusListener(listener);
        }
      } else {
        debugPrint('Evolo [CaptureScreen]: No active transition route. Initializing camera now.');
        _initializeCamera();
      }
    });
  }

  Future<void> _disposeController(CameraController? controller) async {
    if (controller == null) {
      debugPrint('Evolo [CaptureScreen]: _disposeController called with null controller');
      return;
    }
    debugPrint('Evolo [CaptureScreen]: _disposeController starting for controller ${controller.hashCode}');
    final disposeFuture = controller.dispose();
    _lastDisposeFuture = disposeFuture;
    try {
      await disposeFuture;
      debugPrint('Evolo [CaptureScreen]: _disposeController finished successfully for controller ${controller.hashCode}');
    } catch (error, stackTrace) {
      debugPrint('Evolo [CaptureScreen]: _disposeController threw error: $error\n$stackTrace');
      await ErrorTrackingService.captureException(
        error,
        stackTrace: stackTrace,
        context: {'feature': 'capture_dispose'},
      );
    } finally {
      if (_lastDisposeFuture == disposeFuture) {
        _lastDisposeFuture = null;
        debugPrint('Evolo [CaptureScreen]: _lastDisposeFuture cleared');
      }
    }
  }

  Future<void> _initializeCamera() async {
    debugPrint('Evolo [CaptureScreen]: _initializeCamera starting. _isInitializing=$_isInitializing, mounted=$mounted');
    if (_isInitializing || !mounted) return;
    _isInitializing = true;

    try {
      final lastDispose = _lastDisposeFuture;
      if (lastDispose != null) {
        debugPrint('Evolo [CaptureScreen]: Awaiting previous camera controller dispose to complete...');
        await lastDispose.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Evolo [CaptureScreen]: WARNING: Previous camera dispose timed out (2s).');
          },
        );
        debugPrint('Evolo [CaptureScreen]: Previous camera dispose finished or timed out.');
      }
      if (!mounted) {
        debugPrint('Evolo [CaptureScreen]: Widget became unmounted while waiting for dispose.');
        return;
      }

      debugPrint('Evolo [CaptureScreen]: Ensuring camera permission...');
      final allowed = await PermissionService().ensureCameraPermission();
      debugPrint('Evolo [CaptureScreen]: Camera permission result: allowed=$allowed, mounted=$mounted');
      if (!mounted) return;

      if (!allowed) {
        await AnalyticsService.instance.capture(AnalyticsEvent.permissionDenied);
        if (mounted) {
          setState(() {
            _permissionGranted = false;
            _isInitializing = false;
          });
        }
        return;
      }

      debugPrint('Evolo [CaptureScreen]: Retrieving available cameras...');
      final cameras = await availableCameras();
      debugPrint('Evolo [CaptureScreen]: Found ${cameras.length} cameras.');
      if (!mounted) return;

      CameraDescription? camera;
      for (final availableCamera in cameras) {
        if (availableCamera.lensDirection == CameraLensDirection.back) {
          camera = availableCamera;
          break;
        }
      }
      camera ??= cameras.isEmpty ? null : cameras.first;
      debugPrint('Evolo [CaptureScreen]: Selected camera: ${camera?.name}');

      if (camera == null) {
        if (mounted) {
          setState(() {
            _permissionGranted = true;
            _cameraError = AppStrings.cameraUnavailable;
          });
        }
        return;
      }

      final oldController = _cameraController;
      _cameraController = null;
      if (oldController != null) {
        debugPrint('Evolo [CaptureScreen]: Disposing old camera controller ${oldController.hashCode} before creating new one');
        await _disposeController(oldController);
      }
      
      if (!mounted) {
        debugPrint('Evolo [CaptureScreen]: Widget became unmounted while disposing old controller.');
        return;
      }

      debugPrint('Evolo [CaptureScreen]: Instantiating new CameraController...');
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      debugPrint('Evolo [CaptureScreen]: Initializing CameraController ${controller.hashCode}...');
      await controller.initialize();
      debugPrint('Evolo [CaptureScreen]: CameraController ${controller.hashCode} initialized successfully. mounted=$mounted');
      
      if (!mounted) {
        debugPrint('Evolo [CaptureScreen]: Widget became unmounted during initialization, disposing new controller.');
        await controller.dispose();
        return;
      }

      setState(() {
        _permissionGranted = true;
        _cameraController = controller;
        _cameraError = null;
      });

      await AnalyticsService.instance.capture(
        AnalyticsEvent.cameraOpened,
        properties: {'project_id': widget.projectId},
      );
      debugPrint('Evolo [CaptureScreen]: Camera setup complete, state updated.');
    } catch (error, stackTrace) {
      debugPrint('Evolo [CaptureScreen]: EXCEPTION inside _initializeCamera: $error\n$stackTrace');
      await ErrorTrackingService.captureException(
        error,
        stackTrace: stackTrace,
        context: {'feature': 'capture'},
      );
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _cameraError = AppStrings.cameraUnavailable;
        });
      }
    } finally {
      _isInitializing = false;
      debugPrint('Evolo [CaptureScreen]: _initializeCamera completed. _isInitializing=$_isInitializing');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    debugPrint('Evolo [CaptureScreen]: didChangeAppLifecycleState: state=$state');

    if (state == AppLifecycleState.paused) {
      final controller = _cameraController;
      _cameraController = null;
      debugPrint('Evolo [CaptureScreen]: App paused. Starting async disposal of camera controller ${controller?.hashCode}');
      _disposeController(controller);
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      final isInitialized = _cameraController?.value.isInitialized ?? false;
      debugPrint('Evolo [CaptureScreen]: App resumed. _cameraController=${_cameraController?.hashCode}, isInitialized=$isInitialized');
      if (_cameraController == null || !isInitialized) {
        _initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    debugPrint('Evolo [CaptureScreen]: dispose() started for _CaptureScreenState');
    WidgetsBinding.instance.removeObserver(this);
    _disposeController(_cameraController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    debugPrint('Evolo [CaptureScreen]: build() called. project.state=${project.runtimeType}, value=${project.value?.name}');

    return Scaffold(
      backgroundColor: AppColors.black,
      body: project.when(
        data: (item) {
          final previousImagePath = item?.latestCapture?.imagePath;
          debugPrint('Evolo [CaptureScreen]: project.when(data) rendered for project="${item?.name}", previousImagePath=$previousImagePath');

          return Stack(
            fit: StackFit.expand,
            children: [
              _CameraPreviewLayer(
                controller: _cameraController,
                permissionGranted: _permissionGranted,
                cameraError: _cameraError,
                onRequestPermission: _initializeCamera,
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: 180.ms,
                  opacity: previousImagePath != null ? _overlayOpacity : 0.0,
                  child: previousImagePath != null
                      ? EvoloImage(source: previousImagePath)
                      : const SizedBox.shrink(),
                ),
              ),
              const _CaptureGrid(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                                return;
                              }

                              context.go(AppRoutes.timeline(widget.projectId));
                            },
                            icon: const Icon(Icons.close),
                            tooltip: AppStrings.cancel,
                          ),
                          const Spacer(),
                          Visibility(
                            visible: previousImagePath != null,
                            maintainState: true,
                            child: GlassPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              child: Text(
                                AppStrings.ghostOpacity,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Visibility(
                        visible: previousImagePath != null,
                        maintainState: true,
                        child: GlassPanel(
                          child: Row(
                            children: [
                              const Icon(Icons.layers_outlined, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Slider(
                                  value: _overlayOpacity,
                                  min: AppConstants.minOverlayOpacity,
                                  max: AppConstants.maxOverlayOpacity,
                                  onChanged: (value) {
                                    setState(() => _overlayOpacity = value);
                                  },
                                  onChangeEnd: (value) {
                                    HapticFeedback.selectionClick();
                                    AnalyticsService.instance.capture(
                                      AnalyticsEvent.opacityAdjusted,
                                      properties: {
                                        'project_id': widget.projectId,
                                        'opacity': value,
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _CaptureButton(
                        isSaving: _saving,
                        onPressed:
                            _cameraController?.value.isInitialized == true &&
                                    !_saving
                                ? _takePicture
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        error: (_, _) =>
            const Center(child: Text(AppStrings.somethingWentWrong)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _takePicture() async {
    HapticFeedback.mediumImpact();
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _saving = true);
    try {
      final file = await controller.takePicture();
      await ref
          .read(captureControllerProvider)
          .saveCapture(projectId: widget.projectId, temporaryPath: file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.captureSaved)));
      }
    } catch (error, stackTrace) {
      await ErrorTrackingService.captureException(
        error,
        stackTrace: stackTrace,
        context: {'feature': 'capture_take_picture'},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.captureFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _CameraPreviewLayer extends StatelessWidget {
  const _CameraPreviewLayer({
    required this.controller,
    required this.permissionGranted,
    required this.cameraError,
    required this.onRequestPermission,
  });

  final CameraController? controller;
  final bool permissionGranted;
  final String? cameraError;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    debugPrint('Evolo [_CameraPreviewLayer]: build() called. permissionGranted=$permissionGranted, cameraError=$cameraError, controller=${controller?.hashCode}, isInitialized=${controller?.value.isInitialized}');
    if (!permissionGranted) {
      debugPrint('Evolo [_CameraPreviewLayer]: rendering _PermissionRequest');
      return _PermissionRequest(onPressed: onRequestPermission);
    }

    if (cameraError != null) {
      debugPrint('Evolo [_CameraPreviewLayer]: rendering cameraError widget: $cameraError');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.warmWhite),
          ),
        ),
      );
    }

    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      debugPrint('Evolo [_CameraPreviewLayer]: rendering CircularProgressIndicator (controller is null or not initialized)');
      return const Center(child: CircularProgressIndicator());
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: cameraController.value.previewSize?.height ?? 1,
        height: cameraController.value.previewSize?.width ?? 1,
        child: GestureDetector(
          onTapDown: (details) {
            if (!context.mounted) return;
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            
            final offset = box.globalToLocal(details.globalPosition);
            final x = offset.dx / box.size.width;
            final y = offset.dy / box.size.height;
            
            // Check initialized again before calling methods
            if (cameraController.value.isInitialized) {
              cameraController.setFocusPoint(Offset(x, y));
              cameraController.setExposurePoint(Offset(x, y));
              HapticFeedback.selectionClick();
            }
          },
          child: CameraPreview(cameraController),
        ),
      ),
    );
  }
}

class _PermissionRequest extends StatelessWidget {
  const _PermissionRequest({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.cameraPermissionTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.cameraPermissionBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onPressed,
                child: const Text(AppStrings.allowCamera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureGrid extends StatelessWidget {
  const _CaptureGrid();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _GridPainter()));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.warmWhite.withValues(alpha: 0.12)
      ..strokeWidth = 0.7;

    canvas
      ..drawLine(
        Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(0, size.height / 3),
        Offset(size.width, size.height / 3),
        paint,
      )
      ..drawLine(
        Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.captureMoment,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: 180.ms,
          opacity: onPressed == null ? 0.45 : 1,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warmWhite, width: 2),
            ),
            padding: const EdgeInsets.all(7),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSaving ? AppColors.amber : AppColors.warmWhite,
              ),
              child: isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
