import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/history/data/history_database.dart';
import 'package:medicao_ai_3d/features/history/data/history_report_pdf_service.dart';
import 'package:medicao_ai_3d/features/history/domain/history_models.dart';
import 'package:medicao_ai_3d/features/history/presentation/history_screen.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('medicao_history_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SQLite HistoryDatabase creates, searches, edits, and deletes projects & records', () async {
    final db = HistoryDatabase(
      customDatabaseFactory: databaseFactoryFfi,
      customDbPath: p.join(tempDir.path, 'test_history.db'),
    );

    final project = MaintenanceProject(
      id: 'prj-1',
      name: 'Bomba Centrífuga B-04',
      equipmentTag: 'BMB-04',
      locationOrClient: 'Linha 1',
      notes: 'Parada programada',
      createdAtIso: '2026-11-25T10:00:00Z',
      updatedAtIso: '2026-11-25T10:00:00Z',
    );
    await db.upsertProject(project);

    final projects = await db.listProjects();
    expect(projects.length, 1);
    expect(projects.first.equipmentTag, 'BMB-04');

    final rec1 = HistoryRecord(
      id: 'rec-1',
      projectId: 'prj-1',
      recordType: HistoryRecordType.torque,
      title: 'Torque flange M12 8.8',
      summary: 'Aperto cruzado lubrificado',
      measurementsText: 'M12 x 1.75 | 79.5 N·m',
      technicalSource: 'VDI 2230 / ISO 898-1',
      uncertaintyOrNote: 'Torquímetro calibrado ±3%',
      createdAtIso: '2026-11-25T10:05:00Z',
      updatedAtIso: '2026-11-25T10:05:00Z',
    );
    await db.upsertRecord(rec1);

    // Search
    final found = await db.listRecords(searchQuery: 'VDI 2230');
    expect(found.length, 1);
    expect(found.first.title, 'Torque flange M12 8.8');

    // Edit
    await db.upsertRecord(
      rec1.copyWith(
        measurementsText: 'M12 x 1.75 | 82.0 N·m',
        updatedAtIso: '2026-11-25T10:10:00Z',
      ),
    );
    final updated = await db.listRecords(projectId: 'prj-1');
    expect(updated.first.measurementsText, 'M12 x 1.75 | 82.0 N·m');

    // Delete
    await db.deleteRecord('rec-1');
    expect(await db.listRecords(), isEmpty);

    await db.deleteProject('prj-1');
    expect(await db.listProjects(), isEmpty);
    await db.close();
  });

  test('HistoryReportPdfService exports complete PDF including embedded photo', () async {
    final photoFile = File(p.join(tempDir.path, 'sample.png'));
    final bitmap = img.Image(width: 64, height: 64);
    img.fill(bitmap, color: img.ColorRgb8(180, 110, 60));
    await photoFile.writeAsBytes(img.encodePng(bitmap));

    final pdfService = HistoryReportPdfService(
      directoryProvider: () async => tempDir,
    );

    const project = MaintenanceProject(
      id: 'prj-pdf',
      name: 'Redutor R-09',
      equipmentTag: 'RED-09',
      locationOrClient: 'Moagem',
      notes: 'Troca de retentor e rolamento',
      createdAtIso: '2026-11-25T10:00:00Z',
      updatedAtIso: '2026-11-25T10:00:00Z',
    );
    final records = [
      HistoryRecord(
        id: 'rec-photo',
        projectId: 'prj-pdf',
        recordType: HistoryRecordType.mechanicalComponent,
        title: 'Rolamento 6205-2RS',
        summary: 'Substituição preventiva',
        measurementsText: 'd=25 mm, D=52 mm, B=15 mm',
        technicalSource: 'ISO 15 / Catálogo SKF',
        uncertaintyOrNote: 'Conferido com micrômetro',
        photoPath: photoFile.path,
        createdAtIso: '2026-11-25T10:15:00Z',
        updatedAtIso: '2026-11-25T10:15:00Z',
      ),
    ];

    final outFile = await pdfService.exportReportToFile(
      project: project,
      records: records,
      reportTitle: 'Relatório Técnico Redutor R-09',
    );
    expect(await outFile.exists(), isTrue);
    final bytes = await outFile.readAsBytes();
    expect(bytes.length, greaterThan(1200));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets(
    'HistoryScreen displays SQLite records, filters by search, and deletes record',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = HistoryDatabase(
        customDatabaseFactory: databaseFactoryFfi,
        customDbPath: p.join(tempDir.path, 'widget_history.db'),
      );
      await tester.runAsync(() async {
        await db.upsertProject(
          const MaintenanceProject(
            id: 'p1',
            name: 'Prensa P-01',
            equipmentTag: 'PRS-01',
            locationOrClient: 'Estamparia',
            notes: '',
            createdAtIso: '2026-11-25T09:00:00Z',
            updatedAtIso: '2026-11-25T09:00:00Z',
          ),
        );
        await db.upsertRecord(
          const HistoryRecord(
            id: 'r1',
            projectId: 'p1',
            recordType: HistoryRecordType.fastener,
            title: 'Parafuso Base M16',
            summary: 'Verificado passo 2.0 mm',
            measurementsText: 'D=16 mm, L=60 mm, Classe 10.9',
            technicalSource: 'ISO 898-1',
            uncertaintyOrNote: 'OCR confirmado',
            createdAtIso: '2026-11-25T09:05:00Z',
            updatedAtIso: '2026-11-25T09:05:00Z',
          ),
        );
      });

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryScreen(
              settingsController: controller,
              database: db,
              pdfService: HistoryReportPdfService(
                directoryProvider: () async => tempDir,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('Prensa P-01'), findsOneWidget);
      expect(find.text('Parafuso Base M16'), findsOneWidget);
      expect(find.text('Registros salvos (1)'), findsOneWidget);

      await tester.runAsync(() => db.close());
    },
  );
}
