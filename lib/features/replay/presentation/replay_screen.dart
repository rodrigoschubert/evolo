import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/video_render_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cinematic_scaffold.dart';
import '../../../core/widgets/evolo_image.dart';
import '../../../core/widgets/before_after_slider.dart';
import '../../projects/application/projects_controller.dart';

enum _ViewMode { timelapse, compare }

class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  Timer? _timer;
  int _index = 0;
  _ViewMode _viewMode = _ViewMode.timelapse;
  bool _isRendering = false;
  double? _renderingProgress;

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.instance.capture(
        AnalyticsEvent.replayGenerated,
        properties: {'project_id': widget.projectId, 'mode': 'preview'},
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _renderVideo(List<String> imagePaths) async {
    setState(() {
      _isRendering = true;
      _renderingProgress = 0.0;
    });

    final outputPath = await VideoRenderService.instance.renderTimelapse(
      imagePaths,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _renderingProgress = progress);
        }
      },
    );

    if (mounted) {
      setState(() {
        _isRendering = false;
        _renderingProgress = null;
      });

      if (outputPath != null) {
        // ignore: deprecated_member_use
        Share.shareXFiles([XFile(outputPath)], text: 'Meu progresso no Evolo!');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar o vídeo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));

    return CinematicScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.replay),
      ),
      child: SafeArea(
        child: project.when(
          data: (item) {
            final captures = item?.captures ?? [];
            if (captures.length < 2) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    AppStrings.replayEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (_viewMode == _ViewMode.timelapse) {
              _timer ??= Timer.periodic(const Duration(milliseconds: 850), (_) {
                if (!mounted) {
                  return;
                }
                setState(() => _index = (_index + 1) % captures.length);
              });
            } else {
              _timer?.cancel();
              _timer = null;
            }

            final capture = captures[_index % captures.length];

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_ViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: _ViewMode.timelapse,
                        icon: Icon(Icons.play_circle_outline),
                        label: Text('Timelapse'),
                      ),
                      ButtonSegment(
                        value: _ViewMode.compare,
                        icon: Icon(Icons.compare),
                        label: Text('Antes e Depois'),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<_ViewMode> newSelection) {
                      setState(() {
                        _viewMode = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppColors.surfaceRaised,
                      selectedBackgroundColor: AppColors.amber.withValues(alpha: 0.2),
                      selectedForegroundColor: AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: _viewMode == _ViewMode.timelapse
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 420),
                                  child: EvoloImage(
                                    source: capture.imagePath,
                                    key: ValueKey(capture.id),
                                  ),
                                ),
                                Positioned(
                                  left: AppSpacing.md,
                                  right: AppSpacing.md,
                                  bottom: AppSpacing.md,
                                  child: LinearProgressIndicator(
                                    value: (_index + 1) / captures.length,
                                    color: AppColors.amber,
                                    backgroundColor: AppColors.warmWhite.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : BeforeAfterSlider(
                              beforeImagePath: captures.first.imagePath,
                              afterImagePath: captures.last.imagePath,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _isRendering
                          ? null
                          : () => _renderVideo(captures.map((c) => c.imagePath).toList()),
                      icon: _isRendering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.warmWhite,
                              ),
                            )
                          : const Icon(Icons.movie_creation_outlined),
                      label: Text(_isRendering && _renderingProgress != null
                          ? 'Gerando vídeo... ${(_renderingProgress! * 100).toStringAsFixed(0)}%'
                          : 'Exportar Timelapse'),
                    ),
                  ),
                ],
              ),
            );
          },
          error: (_, _) =>
              const Center(child: Text(AppStrings.somethingWentWrong)),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
