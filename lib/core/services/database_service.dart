import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('evolo.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        coverImagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE captures (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        note TEXT,
        source TEXT,
        sortOrder INTEGER,
        FOREIGN KEY (projectId) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE captures ADD COLUMN source TEXT');
      await db.execute('ALTER TABLE captures ADD COLUMN sortOrder INTEGER');

      // Backfill sortOrder for existing captures based on createdAt order
      final captures = await db.rawQuery(
        'SELECT id, projectId, createdAt FROM captures ORDER BY projectId, createdAt ASC',
      );

      String? currentProjectId;
      int order = 0;
      for (final row in captures) {
        final pid = row['projectId'] as String;
        if (pid != currentProjectId) {
          currentProjectId = pid;
          order = 0;
        }
        await db.update(
          'captures',
          {'sortOrder': order},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        order++;
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
