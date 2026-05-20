import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../application/projects_controller.dart';
import '../domain/evolo_project.dart';
import '../../account/application/auth_providers.dart';
import '../../../core/widgets/premium_paywall_sheet.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsControllerProvider);
    final isPremium = ref.watch(isPremiumUserProvider);
    final projectsCount = projects.value?.length ?? 0;

    return CinematicScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: SectionHeader(
                      title: AppStrings.projectsTitle,
                      subtitle: AppStrings.projectsSubtitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push(AppRoutes.premium),
                    icon: Icon(
                      isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                      color: isPremium ? AppColors.amber : null,
                    ),
                    tooltip: isPremium ? 'Evolo Pro Ativo' : 'Conhecer Evolo Pro',
                  ),
                  IconButton.filled(
                    onPressed: () => _showCreateProjectSheet(context, ref),
                    icon: const Icon(Icons.add),
                    tooltip: AppStrings.newProject,
                  ),
                ],
              ),
              if (!isPremium) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Plano Grátis: $projectsCount de 2 projetos criados',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ],
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: projects.when(
                  data: (items) => items.isEmpty
                      ? const _EmptyProjects()
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            return _ProjectCard(project: items[index])
                                .animate()
                                .fadeIn(delay: (60 * index).ms)
                                .slideY(begin: 0.04);
                          },
                        ),
                  error: (_, _) =>
                      const Center(child: Text(AppStrings.somethingWentWrong)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateProjectSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    debugPrint('Evolo [ProjectsScreen]: _showCreateProjectSheet started');

    final projectsVal = ref.read(projectsControllerProvider).value ?? [];
    final isPremium = ref.read(isPremiumUserProvider);

    if (!isPremium && projectsVal.length >= 2) {
      await PremiumPaywallSheet.show(
        context,
        title: AppStrings.projectLimitReached,
        description: AppStrings.projectLimitReachedDesc,
      );
      return;
    }

    final project = await showModalBottomSheet<EvoloProject?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _CreateProjectSheet(ref: ref),
    );

    debugPrint('Evolo [ProjectsScreen]: Modal sheet returned. project=$project, context.mounted=${context.mounted}');

    if (project != null && context.mounted) {
      debugPrint('Evolo [ProjectsScreen]: Pushing CaptureScreen for projectId=${project.id}');
      context.push(AppRoutes.capture(project.id));
    }
  }
}

class _CreateProjectSheet extends StatefulWidget {
  const _CreateProjectSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  late final TextEditingController _controller;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.newProject,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_creating,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: AppStrings.projectNameLabel,
              hintText: AppStrings.projectNameHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _creating
                  ? null
                  : () async {
                      final name = _controller.text.trim();
                      if (name.isEmpty) {
                        return;
                      }

                      debugPrint('Evolo [ProjectsScreen]: Creating project named "$name"...');
                      setState(() => _creating = true);
                      FocusManager.instance.primaryFocus?.unfocus();

                      try {
                        final project = await widget.ref
                            .read(projectsControllerProvider.notifier)
                            .createProject(name);
                        debugPrint('Evolo [ProjectsScreen]: Project created successfully: id=${project.id}, name=${project.name}');

                        if (context.mounted) {
                          debugPrint('Evolo [ProjectsScreen]: Popping modal bottom sheet with project...');
                          Navigator.of(context).pop(project);
                        }
                      } catch (error, stackTrace) {
                        debugPrint('Evolo [ProjectsScreen]: Error creating project: $error\n$stackTrace');
                        if (mounted) {
                          setState(() => _creating = false);
                        }
                      }
                    },
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Text(AppStrings.createProject),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 44,
            color: AppColors.warmWhite.withValues(alpha: 0.72),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.emptyProjectsTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.emptyProjectsBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final EvoloProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('d MMM yyyy', 'pt_BR').format(project.updatedAt);
    final coverPath = project.coverImagePath;

    return InkWell(
      onTap: () => context.push(AppRoutes.timeline(project.id)),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverPath != null)
                EvoloImage(source: coverPath)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceHigh,
                        AppColors.surface,
                        AppColors.black,
                      ],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${project.captures.length} capturas • $date',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.capture(project.id)),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text(AppStrings.capture),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.outlined(
                          onPressed: () =>
                              context.push(AppRoutes.replay(project.id)),
                          icon: const Icon(Icons.play_arrow_rounded),
                          tooltip: AppStrings.replay,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.warmWhite),
                  color: AppColors.surfaceRaised,
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Excluir Projeto?'),
                          content: const Text('Todas as fotos serão perdidas permanentemente.'),
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
                        await ref.read(projectsControllerProvider.notifier).deleteProject(project.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir Projeto', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
