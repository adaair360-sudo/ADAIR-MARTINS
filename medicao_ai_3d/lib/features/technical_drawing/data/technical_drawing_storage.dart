import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/technical_drawing_models.dart';

class TechnicalDrawingStorage {
  TechnicalDrawingStorage({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'technical_drawings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'drawings_index.json'));
  }

  Future<List<TechnicalDrawingSpec>> loadAll() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) {
        return const [];
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(TechnicalDrawingSpec.fromJson)
          .toList();
      items.sort((a, b) => (b.updatedAtIso ?? '').compareTo(a.updatedAtIso ?? ''));
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<TechnicalDrawingSpec>> save(TechnicalDrawingSpec spec) async {
    final nowIso = DateTime.now().toIso8601String();
    final updated = spec.copyWith(updatedAtIso: nowIso);
    final current = await loadAll();
    final next = <TechnicalDrawingSpec>[
      updated,
      ...current.where((item) => item.id != updated.id),
    ];
    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        next.map((item) => item.toJson()).toList(),
      ),
    );
    return next;
  }

  Future<List<TechnicalDrawingSpec>> delete(String id) async {
    final current = await loadAll();
    final next = current.where((item) => item.id != id).toList();
    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        next.map((item) => item.toJson()).toList(),
      ),
    );
    return next;
  }
}
