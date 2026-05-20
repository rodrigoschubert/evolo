import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cinematic_scaffold.dart';
import '../../../core/widgets/evolo_image.dart';
import '../../../core/widgets/section_header.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/capture_entry.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));

    return CinematicScaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timeline),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.replay(projectId)),
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: AppStrings.replay,
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.capture(projectId)),
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: AppStrings.capture,
          ),
        ],
      ),
      child: SafeArea(
        child: project.when(
          data: (item) {
            if (item == null) {
              return const Center(child: Text(AppStrings.somethingWentWrong));
            }

            if (item.captures.isEmpty) {
              return _TimelineEmpty(projectId: projectId);
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SectionHeader(
                  title: item.name,
                  subtitle: '${item.captures.length} registros visuais',
                ),
                const SizedBox(height: AppSpacing.xl),
                _TimelineScrubber(captures: item.captures),
                const SizedBox(height: AppSpacing.xl),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: item.captures.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 4 / 5,
                  ),
                  itemBuilder: (context, index) {
                    return _TimelineTile(
                      capture: item.captures[index],
                      index: index,
                      projectId: projectId,
                    );
                  },
                ),
              ],
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

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timeline_outlined, size: 44),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.timelineEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.capture(projectId)),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text(AppStrings.openCamera),
          ),
        ],
      ),
    );
  }
}

class _TimelineScrubber extends StatelessWidget {
  const _TimelineScrubber({required this.captures});

  final List<CaptureEntry> captures;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: CustomPaint(painter: _TimelinePainter(captures.length)),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.warmWhite.withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    final markerPaint = Paint()..color = AppColors.textMuted;
    final activePaint = Paint()..color = AppColors.amber;

    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);

    for (var index = 0; index < count; index++) {
      final x = count == 1 ? size.width / 2 : size.width * index / (count - 1);
      final isLast = index == count - 1;
      canvas.drawCircle(
        Offset(x, centerY),
        isLast ? 5 : 3,
        isLast ? activePaint : markerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.count != count;
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({
    required this.capture,
    required this.index,
    required this.projectId,
  });

  final CaptureEntry capture;
  final int index;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('d MMM', 'pt_BR').format(capture.createdAt);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          EvoloImage(source: capture.imagePath),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  AppColors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Text(
              '${(index + 1).toString().padLeft(2, '0')} • $date',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.warmWhite, size: 20),
              color: AppColors.surfaceRaised,
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Excluir Foto?'),
                      content: const Text('Esta ação não pode ser desfeita.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.warmWhite)),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Excluir'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await ref.read(projectsControllerProvider.notifier).deleteCapture(projectId, capture.id);
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir Foto', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
