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
import '../../account/application/auth_providers.dart';
import '../../../core/widgets/premium_paywall_sheet.dart';

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
  String _selectedResolution = '1080p';
  String _selectedTransition = 'cut';
  double _fps = 4.0; // Default speed

  void _resetTimer() {
    _timer?.cancel();
    if (_viewMode == _ViewMode.timelapse) {
      final interval = (1000 / _fps).round();
      _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
        if (!mounted) return;
        final project = ref.read(projectByIdProvider(widget.projectId));
        final capturesCount = project.value?.captures.length ?? 0;
        if (capturesCount > 0) {
          setState(() => _index = (_index + 1) % capturesCount);
        }
      });
    } else {
      _timer = null;
    }
  }

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
    final isPremium = ref.read(isPremiumUserProvider);
    
    setState(() {
      _isRendering = true;
      _renderingProgress = 0.0;
    });

    final outputPath = await VideoRenderService.instance.renderTimelapse(
      imagePaths,
      fps: _fps.round(),
      resolution: _selectedResolution,
      transition: _selectedTransition,
      isPremium: isPremium,
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
    final isPremium = ref.watch(isPremiumUserProvider);

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
              if (_timer == null) {
                _resetTimer();
              }
            } else {
              _timer?.cancel();
              _timer = null;
            }

            final capture = captures[_index % captures.length];
            // Dynamic duration: transition lasts 40% of the frame's total time
            final dynamicDuration = Duration(milliseconds: (400 / _fps).round());

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_ViewMode>(
                    segments: [
                      const ButtonSegment(
                        value: _ViewMode.timelapse,
                        icon: Icon(Icons.play_circle_outline),
                        label: Text('Timelapse'),
                      ),
                      ButtonSegment(
                        value: _ViewMode.compare,
                        icon: Icon(
                          isPremium ? Icons.compare : Icons.lock_outline_rounded,
                          color: isPremium ? null : AppColors.amber,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Antes e Depois'),
                            if (!isPremium) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.workspace_premium_rounded, size: 12, color: AppColors.amber),
                            ],
                          ],
                        ),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<_ViewMode> newSelection) async {
                      if (newSelection.first == _ViewMode.compare && !isPremium) {
                        await PremiumPaywallSheet.show(
                          context,
                          title: AppStrings.lockedFeatureTitle,
                          description: AppStrings.lockedFeatureBeforeAfterDesc,
                        );
                        return;
                      }
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
                                  duration: dynamicDuration,
                                  layoutBuilder: (currentChild, previousChildren) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        if (previousChildren.isNotEmpty) previousChildren.last,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    // This animation logic applies to the CHILD ENTERING the screen
                                    // The child leaving will simply disappear or remain behind 
                                    // based on the layoutBuilder above.
                                    
                                    if (_selectedTransition == 'zoom') {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: animation.drive(
                                            Tween(begin: 1.15, end: 1.0).chain(
                                              CurveTween(curve: Curves.easeOutQuart),
                                            ),
                                          ),
                                          child: child,
                                        ),
                                      );
                                    }
                                    
                                    if (_selectedTransition == 'slide') {
                                      return SlideTransition(
                                        position: animation.drive(
                                          Tween<Offset>(
                                            begin: const Offset(1.0, 0.0),
                                            end: Offset.zero,
                                          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                                        ),
                                        child: child,
                                      );
                                    }

                                    if (_selectedTransition == 'fade') {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    }

                                    // Default (cut) or others: immediate appearance
                                    return child;
                                  },
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
                  if (_viewMode == _ViewMode.timelapse) ...[
                    const SizedBox(height: AppSpacing.md),
                    // Transição Selector
                    const Text('Efeito:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: [
                          const ButtonSegment(value: 'cut', label: Text('Corte')),
                          ButtonSegment(
                            value: 'fade',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Fade'),
                                if (!isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.amber),
                                ],
                              ],
                            ),
                          ),
                          ButtonSegment(
                            value: 'zoom',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Zoom'),
                                if (!isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.amber),
                                ],
                              ],
                            ),
                          ),
                          ButtonSegment(
                            value: 'slide',
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Slide'),
                                if (!isPremium) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.amber),
                                ],
                              ],
                            ),
                          ),
                        ],
                        selected: {_selectedTransition},
                        onSelectionChanged: (val) async {
                          if (val.first != 'cut' && !isPremium) {
                            await PremiumPaywallSheet.show(
                              context,
                              title: AppStrings.lockedFeatureTitle,
                              description: AppStrings.lockedFeatureTransitionsDesc,
                            );
                            return;
                          }
                          setState(() => _selectedTransition = val.first);
                        },
                        style: SegmentedButton.styleFrom(
                          backgroundColor: AppColors.surfaceRaised,
                          selectedBackgroundColor: AppColors.amber.withValues(alpha: 0.15),
                          selectedForegroundColor: AppColors.amber,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero, // Remove padding interno para caber mais
                          textStyle: const TextStyle(fontSize: 11), // Diminui levemente a fonte
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SizedBox(height: AppSpacing.sm),
                    // Velocidade Selector
                    Row(
                      children: [
                        const Text('Velocidade:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Slider(
                            value: _fps,
                            min: 1,
                            max: 12,
                            divisions: 11,
                            label: '${_fps.round()} fps',
                            activeColor: AppColors.amber,
                            onChanged: (val) async {
                              if (val > 5 && !isPremium) {
                                await PremiumPaywallSheet.show(
                                  context,
                                  title: 'Velocidade Premium',
                                  description: 'Velocidades acima de 5 FPS são exclusivas para assinantes Evolo Pro.',
                                );
                                return;
                              }
                              setState(() {
                                _fps = val;
                                _resetTimer();
                              });
                            },
                          ),
                        ),
                        Text('${_fps.round()} FPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Resolução Selector
                    Row(
                      children: [
                        const Text('Resolução:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: [
                              const ButtonSegment(value: '1080p', label: Text('1080p')),
                              ButtonSegment(
                                value: '4k',
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Cinema 4K'),
                                    if (!isPremium) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.amber),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            selected: {_selectedResolution},
                            onSelectionChanged: (val) async {
                              if (val.first == '4k' && !isPremium) {
                                await PremiumPaywallSheet.show(
                                  context,
                                  title: AppStrings.lockedFeatureTitle,
                                  description: AppStrings.lockedFeature4KDesc,
                                );
                                return;
                              }
                              setState(() => _selectedResolution = val.first);
                            },
                            style: SegmentedButton.styleFrom(
                              backgroundColor: AppColors.surfaceRaised,
                              selectedBackgroundColor: AppColors.amber.withValues(alpha: 0.15),
                              selectedForegroundColor: AppColors.amber,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
