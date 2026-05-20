import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/database_service.dart';
import '../domain/capture_entry.dart';
import '../domain/evolo_project.dart';

final projectStoreProvider = Provider<ProjectStore>((ref) {
  return ProjectStore(DatabaseService.instance);
});

class ProjectStore {
  const ProjectStore(this._databaseService);

  final DatabaseService _databaseService;

  Future<List<EvoloProject>> loadProjects() async {
    final db = await _databaseService.database;
    final projectsRaw = await db.query('projects', orderBy: 'updatedAt DESC');
    final capturesRaw = await db.query('captures', orderBy: 'createdAt ASC');

    final capturesByProject = <String, List<CaptureEntry>>{};
    for (final map in capturesRaw) {
      final capture = CaptureEntry(
        id: map['id'] as String,
        projectId: map['projectId'] as String,
        imagePath: map['imagePath'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        note: map['note'] as String?,
      );
      capturesByProject.putIfAbsent(capture.projectId, () => []).add(capture);
    }

    final projects = <EvoloProject>[];
    for (final map in projectsRaw) {
      final id = map['id'] as String;
      projects.add(
        EvoloProject(
          id: id,
          name: map['name'] as String,
          createdAt: DateTime.parse(map['createdAt'] as String),
          updatedAt: DateTime.parse(map['updatedAt'] as String),
          coverImagePath: map['coverImagePath'] as String?,
          captures: capturesByProject[id] ?? [],
        ),
      );
    }

    return projects;
  }

  Future<void> createProject(EvoloProject project) async {
    final db = await _databaseService.database;
    await db.insert('projects', {
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'coverImagePath': project.coverImagePath,
    });
  }

  Future<void> updateProject(EvoloProject project) async {
    final db = await _databaseService.database;
    await db.update(
      'projects',
      {
        'name': project.name,
        'updatedAt': project.updatedAt.toIso8601String(),
        'coverImagePath': project.coverImagePath,
      },
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> addCapture(CaptureEntry capture, EvoloProject project) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.insert('captures', {
        'id': capture.id,
        'projectId': capture.projectId,
        'imagePath': capture.imagePath,
        'createdAt': capture.createdAt.toIso8601String(),
        'note': capture.note,
      });

      await txn.update(
        'projects',
        {
          'updatedAt': project.updatedAt.toIso8601String(),
          'coverImagePath': project.coverImagePath,
        },
        where: 'id = ?',
        whereArgs: [project.id],
      );
    });
  }

  Future<void> deleteProject(String projectId) async {
    final db = await _databaseService.database;
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
    // Note: ON DELETE CASCADE will handle deleting related captures in the SQLite DB.
  }

  Future<void> deleteCapture(String captureId, EvoloProject updatedProject) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.delete('captures', where: 'id = ?', whereArgs: [captureId]);
      
      await txn.update(
        'projects',
        {
          'updatedAt': updatedProject.updatedAt.toIso8601String(),
          'coverImagePath': updatedProject.coverImagePath,
        },
        where: 'id = ?',
        whereArgs: [updatedProject.id],
      );
    });
  }
}
