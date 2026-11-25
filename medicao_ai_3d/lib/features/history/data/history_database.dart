import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/history_models.dart';

class HistoryDatabase {
  HistoryDatabase({
    this.customDatabaseFactory,
    this.customDbPath,
  });

  final DatabaseFactory? customDatabaseFactory;
  final String? customDbPath;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    final factory = customDatabaseFactory ?? databaseFactory;
    final dbPath = customDbPath ??
        p.join(await factory.getDatabasesPath(), 'medicao_ai_3d_history.db');

    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              equipment_tag TEXT NOT NULL,
              location_or_client TEXT NOT NULL,
              notes TEXT NOT NULL,
              created_at_iso TEXT NOT NULL,
              updated_at_iso TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE records (
              id TEXT PRIMARY KEY,
              project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
              record_type TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              measurements_text TEXT NOT NULL,
              technical_source TEXT NOT NULL,
              uncertainty_or_note TEXT NOT NULL,
              photo_path TEXT,
              created_at_iso TEXT NOT NULL,
              updated_at_iso TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_records_project ON records(project_id)',
          );
          await db.execute(
            'CREATE INDEX idx_records_updated ON records(updated_at_iso)',
          );
        },
      ),
    );
    return _db!;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
  }

  Future<List<MaintenanceProject>> listProjects() async {
    final db = await _open();
    final rows = await db.query(
      'projects',
      orderBy: 'updated_at_iso DESC',
    );
    return rows.map(MaintenanceProject.fromMap).toList();
  }

  Future<void> upsertProject(MaintenanceProject project) async {
    final db = await _open();
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProject(String projectId) async {
    final db = await _open();
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<List<HistoryRecord>> listRecords({
    String? projectId,
    HistoryRecordType? recordType,
    String? searchQuery,
  }) async {
    final db = await _open();
    final clauses = <String>[];
    final args = <Object?>[];

    if (projectId != null && projectId.isNotEmpty) {
      clauses.add('project_id = ?');
      args.add(projectId);
    }
    if (recordType != null) {
      clauses.add('record_type = ?');
      args.add(recordType.name);
    }
    final q = searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      final like = '%$q%';
      clauses.add(
        '(title LIKE ? OR summary LIKE ? OR measurements_text LIKE ? OR technical_source LIKE ? OR uncertainty_or_note LIKE ?)',
      );
      args.addAll([like, like, like, like, like]);
    }

    final rows = await db.query(
      'records',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_iso DESC',
    );
    return rows.map(HistoryRecord.fromMap).toList();
  }

  Future<void> upsertRecord(HistoryRecord record) async {
    final db = await _open();
    await db.insert(
      'records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecord(String recordId) async {
    final db = await _open();
    await db.delete('records', where: 'id = ?', whereArgs: [recordId]);
  }
}
