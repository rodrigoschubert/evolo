import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/local_media_service.dart';
import '../../../core/services/supabase_service.dart';
import '../data/project_store.dart';
import '../domain/capture_entry.dart';
import '../domain/evolo_project.dart';

final projectsControllerProvider =
    AsyncNotifierProvider<ProjectsController, List<EvoloProject>>(
      ProjectsController.new,
    );

final projectByIdProvider = Provider.family<AsyncValue<EvoloProject?>, String>((
  ref,
  projectId,
) {
  final projects = ref.watch(projectsControllerProvider);
  return projects.whenData((items) {
    for (final project in items) {
      if (project.id == projectId) {
        return project;
      }
    }

    return null;
  });
});

class ProjectsController extends AsyncNotifier<List<EvoloProject>> {
  static const _uuid = Uuid();

  @override
  Future<List<EvoloProject>> build() async {
    final projects = await ref.watch(projectStoreProvider).loadProjects();
    unawaited(SupabaseService.instance.syncLocalData(projects));
    return projects;
  }

  Future<EvoloProject> createProject(String name) async {
    final now = DateTime.now();
    final project = EvoloProject(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final current = state.value ?? await future;
    final updated = [project, ...current];
    state = AsyncData(updated);
    await ref.read(projectStoreProvider).createProject(project);
    // Sync to cloud fire-and-forget (local-first, no blocking)
    unawaited(SupabaseService.instance.upsertProject(project));
    await AnalyticsService.instance.capture(
      AnalyticsEvent.projectCreated,
      properties: {'project_id': project.id},
    );

    return project;
  }

  Future<void> addCapture({
    required String projectId,
    required String imagePath,
  }) async {
    final current = state.value ?? await future;
    final now = DateTime.now();

    final capture = CaptureEntry(
      id: _uuid.v4(),
      projectId: projectId,
      imagePath: imagePath,
      createdAt: now,
    );

    final updated = current.map((project) {
      if (project.id != projectId) {
        return project;
      }

      final captures = [...project.captures, capture];

      return project.copyWith(
        updatedAt: now,
        coverImagePath: imagePath,
        captures: captures,
      );
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = AsyncData(updated);

    final project = updated.firstWhere((item) => item.id == projectId);
    await ref.read(projectStoreProvider).addCapture(capture, project);
    // Sync to cloud fire-and-forget
    unawaited(SupabaseService.instance.upsertCapture(capture));
    unawaited(SupabaseService.instance.upsertProject(project));
    await AnalyticsService.instance.capture(
      project.captures.length == 1
          ? AnalyticsEvent.firstCaptureTaken
          : AnalyticsEvent.captureAdded,
      properties: {
        'project_id': projectId,
        'capture_count': project.captures.length,
      },
    );
  }

  Future<void> deleteProject(String projectId) async {
    final current = state.value ?? await future;
    final updated = current.where((p) => p.id != projectId).toList();
    
    state = AsyncData(updated);
    
    await ref.read(projectStoreProvider).deleteProject(projectId);
    await LocalMediaService().deleteProjectMedia(projectId);
    // Sync to cloud fire-and-forget
    unawaited(SupabaseService.instance.deleteProject(projectId));
  }

  Future<void> deleteCapture(String projectId, String captureId) async {
    final current = state.value ?? await future;
    final now = DateTime.now();

    final projectIndex = current.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;

    final project = current[projectIndex];
    final captureToDelete = project.captures.firstWhere((c) => c.id == captureId);
    final updatedCaptures = project.captures.where((c) => c.id != captureId).toList();

    // Determine new cover image (latest capture if any)
    final newCoverPath = updatedCaptures.isEmpty ? null : updatedCaptures.last.imagePath;

    final updatedProject = project.copyWith(
      updatedAt: now,
      coverImagePath: newCoverPath,
      captures: updatedCaptures,
    );

    final updated = [...current];
    updated[projectIndex] = updatedProject;
    
    // Maintain sorting
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = AsyncData(updated);

    await ref.read(projectStoreProvider).deleteCapture(captureId, updatedProject);
    await LocalMediaService().deleteCaptureMedia(captureToDelete.imagePath);
    // Sync to cloud fire-and-forget
    unawaited(SupabaseService.instance.deleteCapture(captureId));
    unawaited(SupabaseService.instance.upsertProject(updatedProject));
  }
}
