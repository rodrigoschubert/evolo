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

    final projectIndex = current.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;
    
    final project = current[projectIndex];
    final maxSortOrder = project.captures.fold<int>(
      -1, 
      (max, c) => (c.sortOrder ?? -1) > max ? (c.sortOrder ?? -1) : max
    );

    final capture = CaptureEntry(
      id: _uuid.v4(),
      projectId: projectId,
      imagePath: imagePath,
      createdAt: now,
      source: 'camera',
      sortOrder: maxSortOrder + 1,
    );

    final captures = [...project.captures, capture];

    final updatedProject = project.copyWith(
      updatedAt: now,
      coverImagePath: imagePath,
      captures: captures,
    );

    final updated = [...current];
    updated[projectIndex] = updatedProject;
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = AsyncData(updated);

    await ref.read(projectStoreProvider).addCapture(capture, updatedProject);
    // Sync to cloud fire-and-forget
    unawaited(SupabaseService.instance.upsertCapture(capture));
    unawaited(SupabaseService.instance.upsertProject(updatedProject));
    await AnalyticsService.instance.capture(
      updatedProject.captures.length == 1
          ? AnalyticsEvent.firstCaptureTaken
          : AnalyticsEvent.captureAdded,
      properties: {
        'project_id': projectId,
        'capture_count': updatedProject.captures.length,
        'source': 'camera',
      },
    );
  }

  /// Adds multiple imported captures in a batch transaction.
  Future<void> addCaptures({
    required String projectId,
    required List<CaptureEntry> newCaptures,
  }) async {
    if (newCaptures.isEmpty) return;

    final current = state.value ?? await future;
    final now = DateTime.now();

    final projectIndex = current.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;

    final project = current[projectIndex];
    final captures = [...project.captures, ...newCaptures];

    final updatedProject = project.copyWith(
      updatedAt: now,
      coverImagePath: newCaptures.last.imagePath,
      captures: captures,
    );

    final updated = [...current];
    updated[projectIndex] = updatedProject;
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = AsyncData(updated);

    await ref.read(projectStoreProvider).addCaptures(newCaptures, updatedProject);
    
    // Sync to cloud fire-and-forget
    for (final capture in newCaptures) {
      unawaited(SupabaseService.instance.upsertCapture(capture));
    }
    unawaited(SupabaseService.instance.upsertProject(updatedProject));
  }

  /// Reorders existing captures within a project.
  Future<void> reorderCaptures({
    required String projectId,
    required List<String> orderedCaptureIds,
  }) async {
    final current = state.value ?? await future;
    final projectIndex = current.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;

    final project = current[projectIndex];
    
    // Create a new list of captures with updated sortOrder
    final updatedCaptures = project.captures.map((capture) {
      final newIndex = orderedCaptureIds.indexOf(capture.id);
      if (newIndex != -1 && capture.sortOrder != newIndex) {
        return capture.copyWith(sortOrder: newIndex);
      }
      return capture;
    }).toList();
    
    // Sort the list so the UI reflects the new order immediately
    updatedCaptures.sort((a, b) {
      final orderA = a.sortOrder ?? 0;
      final orderB = b.sortOrder ?? 0;
      if (orderA == orderB) {
         return a.createdAt.compareTo(b.createdAt);
      }
      return orderA.compareTo(orderB);
    });

    final updatedProject = project.copyWith(captures: updatedCaptures);
    final updated = [...current];
    updated[projectIndex] = updatedProject;
    
    state = AsyncData(updated);

    await ref.read(projectStoreProvider).updateCaptureOrder(projectId, orderedCaptureIds);
    
    // Sync to cloud fire-and-forget
    for (final capture in updatedCaptures) {
       unawaited(SupabaseService.instance.upsertCapture(capture));
    }
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
