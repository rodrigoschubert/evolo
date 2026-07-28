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
import '../../account/application/auth_providers.dart';
import '../../projects/application/projects_controller.dart';
import '../../projects/domain/capture_entry.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/premium_paywall_sheet.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({required this.projectId, super.key});

  final String projectId;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  bool _isReordering = false;
  List<CaptureEntry>? _reorderedCaptures;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));

    return CinematicScaffold(
      appBar: AppBar(
        title: Text(_isReordering ? 'Reordenar' : AppStrings.timeline),
        actions: [
          if (_isReordering)
            TextButton(
              onPressed: () async {
                if (_reorderedCaptures != null) {
                  final ids = _reorderedCaptures!.map((c) => c.id).toList();
                  await ref.read(projectsControllerProvider.notifier).reorderCaptures(
                    projectId: widget.projectId,
                    orderedCaptureIds: ids,
                  );
                }
                setState(() {
                  _isReordering = false;
                  _reorderedCaptures = null;
                });
              },
              child: const Text('Salvar', style: TextStyle(color: AppColors.amber)),
            )
          else ...[
            IconButton(
              onPressed: () async {
                final isPremium = ref.read(isPremiumUserProvider);
                if (!isPremium) {
                  HapticFeedback.heavyImpact();
                  await PremiumPaywallSheet.show(
                    context,
                    title: 'Organização Premium',
                    description: 'Faça upgrade para o Evolo Pro para reordenar as fotos dos seus projetos livremente.',
                  );
                  return;
                }
                setState(() => _isReordering = true);
              },
              icon: const Icon(Icons.swap_vert),
              tooltip: 'Reordenar',
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.replay(widget.projectId)),
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: AppStrings.replay,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.capture(widget.projectId)),
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: AppStrings.capture,
            ),
          ],
        ],
      ),
      child: SafeArea(
        child: project.when(
          data: (item) {
            if (item == null) {
              return const Center(child: Text(AppStrings.somethingWentWrong));
            }

            if (item.captures.isEmpty) {
              return _TimelineEmpty(projectId: widget.projectId);
            }

            final displayList = _isReordering && _reorderedCaptures != null
                ? _reorderedCaptures!
                : item.captures;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SectionHeader(
                  title: item.name,
                  subtitle: '${displayList.length} registros visuais',
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!_isReordering) _TimelineScrubber(captures: displayList),
                if (!_isReordering) const SizedBox(height: AppSpacing.xl),
                ReorderableBuilder(
                  enableDraggable: _isReordering,
                  enableLongPress: _isReordering,
                  onReorder: (ReorderedListFunction reorderedListFunction) {
                    setState(() {
                      _reorderedCaptures = reorderedListFunction(displayList) as List<CaptureEntry>;
                    });
                  },
                  children: displayList.asMap().entries.map((entry) {
                    return _TimelineTile(
                      key: ValueKey(entry.value.id),
                      capture: entry.value,
                      index: entry.key,
                      projectId: widget.projectId,
                      isReordering: _isReordering,
                    );
                  }).toList(),
                  builder: (children) {
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: 4 / 5,
                      ),
                      children: children,
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
    this.isReordering = false,
    super.key,
  });

  final CaptureEntry capture;
  final int index;
  final String projectId;
  final bool isReordering;

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
          if (isReordering)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drag_indicator, color: AppColors.warmWhite, size: 20),
              ),
            )
          else
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
