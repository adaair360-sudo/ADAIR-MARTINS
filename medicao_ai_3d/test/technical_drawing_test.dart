import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/settings/domain/app_settings.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:medicao_ai_3d/features/technical_drawing/data/technical_drawing_pdf_service.dart';
import 'package:medicao_ai_3d/features/technical_drawing/data/technical_drawing_storage.dart';
import 'package:medicao_ai_3d/features/technical_drawing/domain/technical_drawing_geometry.dart';
import 'package:medicao_ai_3d/features/technical_drawing/domain/technical_drawing_models.dart';
import 'package:medicao_ai_3d/features/technical_drawing/presentation/technical_drawing_screen.dart';
import 'package:medicao_ai_3d/features/technical_drawing/presentation/widgets/technical_drawing_2d_painter.dart';
import 'package:medicao_ai_3d/features/technical_drawing/presentation/widgets/technical_model_3d_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('medicao_dwg_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Validator blocks missing or physically impossible dimensions', () {
    const missingBolt = TechnicalDrawingSpec(
      id: 'b1',
      partType: DrawingPartType.hexBolt,
      partName: 'M10',
      drawingCode: 'D-1',
      materialName: 'Aço carbono',
      authorName: 'Adair',
      toleranceNote: 'ISO 2768-m',
      unit: MeasurementUnit.millimeters,
    );
    final res1 = TechnicalDrawingValidator.validate(missingBolt);
    expect(res1.isValid, isFalse);
    expect(res1.missingOrInvalidFields.length, greaterThanOrEqualTo(4));

    const badTube = TechnicalDrawingSpec(
      id: 't1',
      partType: DrawingPartType.tube,
      partName: 'Tubo inválido',
      drawingCode: 'D-2',
      materialName: 'Bronze',
      authorName: 'Adair',
      toleranceNote: 'ISO 2768-m',
      unit: MeasurementUnit.millimeters,
      outerDiameter: 20,
      innerDiameter: 25,
      length: 50,
    );
    final res2 = TechnicalDrawingValidator.validate(badTube);
    expect(res2.isValid, isFalse);
    expect(
      res2.missingOrInvalidFields.any((e) => e.contains('Diâmetro interno')),
      isTrue,
    );
  });

  test('Mesh3DBuilder generates non-empty 3D geometry for all 5 part types', () {
    final specs = [
      const TechnicalDrawingSpec(
        id: '1',
        partType: DrawingPartType.hexBolt,
        partName: 'Hex M10',
        drawingCode: 'D1',
        materialName: 'Aço carbono',
        authorName: 'Teste',
        toleranceNote: 'ISO 2768-m',
        unit: MeasurementUnit.millimeters,
        outerDiameter: 10,
        length: 40,
        headHeight: 6.4,
        wrenchSize: 17,
        threadPitch: 1.5,
      ),
      const TechnicalDrawingSpec(
        id: '2',
        partType: DrawingPartType.socketBolt,
        partName: 'Allen M8',
        drawingCode: 'D2',
        materialName: 'Aço inoxidável',
        authorName: 'Teste',
        toleranceNote: 'ISO 2768-m',
        unit: MeasurementUnit.millimeters,
        outerDiameter: 8,
        length: 30,
        headHeight: 8,
        wrenchSize: 13,
      ),
      const TechnicalDrawingSpec(
        id: '3',
        partType: DrawingPartType.shaft,
        partName: 'Eixo',
        drawingCode: 'D3',
        materialName: 'Aço carbono',
        authorName: 'Teste',
        toleranceNote: 'ISO 2768-m',
        unit: MeasurementUnit.millimeters,
        outerDiameter: 30,
        length: 100,
        stepDiameter: 20,
        stepLength: 30,
      ),
      const TechnicalDrawingSpec(
        id: '4',
        partType: DrawingPartType.tube,
        partName: 'Tubo',
        drawingCode: 'D4',
        materialName: 'Bronze',
        authorName: 'Teste',
        toleranceNote: 'ISO 2768-m',
        unit: MeasurementUnit.millimeters,
        outerDiameter: 50,
        innerDiameter: 30,
        length: 60,
      ),
      const TechnicalDrawingSpec(
        id: '5',
        partType: DrawingPartType.plate,
        partName: 'Chapa',
        drawingCode: 'D5',
        materialName: 'Alumínio',
        authorName: 'Teste',
        toleranceNote: 'ISO 2768-m',
        unit: MeasurementUnit.millimeters,
        length: 120,
        width: 80,
        heightOrThickness: 12,
        holeDiameter: 20,
      ),
    ];

    for (final spec in specs) {
      expect(TechnicalDrawingValidator.validate(spec).isValid, isTrue);
      final mesh = Mesh3DBuilder.build(spec);
      expect(mesh.vertices, isNotEmpty);
      expect(mesh.triangles, isNotEmpty);
      expect(mesh.edges, isNotEmpty);
    }
  });

  test('Storage saves/loads/deletes and PDF service exports valid PDF bytes', () async {
    final storage = TechnicalDrawingStorage(
      directoryProvider: () async => tempDir,
    );
    final pdfService = TechnicalDrawingPdfService(
      directoryProvider: () async => tempDir,
    );

    const spec = TechnicalDrawingSpec(
      id: 'dwg-test-1',
      partType: DrawingPartType.tube,
      partName: 'Bucha de Bronze',
      drawingCode: 'BUC-001',
      materialName: 'Bronze',
      authorName: 'Adair',
      toleranceNote: 'ISO 2768-m',
      unit: MeasurementUnit.millimeters,
      outerDiameter: 50,
      innerDiameter: 32,
      length: 60,
    );

    await storage.save(spec);
    final loaded = await storage.loadAll();
    expect(loaded.length, 1);
    expect(loaded.first.partName, 'Bucha de Bronze');

    final pdfFile = await pdfService.exportPdfToFile(spec);
    expect(await pdfFile.exists(), isTrue);
    final bytes = await pdfFile.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final afterDelete = await storage.delete('dwg-test-1');
    expect(afterDelete, isEmpty);
  });

  testWidgets(
    'TechnicalDrawingScreen blocks empty inputs, renders 2D+3D on valid inputs, and saves locally',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      final storage = TechnicalDrawingStorage(
        directoryProvider: () async => tempDir,
      );
      final pdfService = TechnicalDrawingPdfService(
        directoryProvider: () async => tempDir,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TechnicalDrawingScreen(
              settingsController: controller,
              storage: storage,
              pdfService: pdfService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts blocked without invented dimensions
      expect(
        find.textContaining('Desenho 2D/3D e PDF bloqueados'),
        findsOneWidget,
      );
      expect(find.byType(TechnicalDrawing2DCanvas), findsNothing);

      // Load editable example
      await tester.tap(find.text('Exemplo Sextavado'));
      await tester.pumpAndSettle();

      expect(find.byType(TechnicalDrawing2DCanvas), findsOneWidget);
      expect(find.byType(TechnicalModel3DView), findsOneWidget);

      // Save locally
      await tester.dragUntilVisible(
        find.text('Salvar desenho local'),
        find.byType(ListView),
        const Offset(0, -350),
      );
      await tester.ensureVisible(find.text('Salvar desenho local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar desenho local'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        if (find.textContaining('Desenhos salvos localmente (1)').evaluate().isNotEmpty) {
          break;
        }
      }

      await tester.dragUntilVisible(
        find.textContaining('Desenhos salvos localmente'),
        find.byType(ListView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Desenhos salvos localmente (1)'), findsOneWidget);
    },
  );
}
