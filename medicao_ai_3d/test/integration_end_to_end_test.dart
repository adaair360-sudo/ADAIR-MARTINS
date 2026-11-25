import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/app.dart';
import 'package:medicao_ai_3d/core/constants/app_modules.dart';
import 'package:medicao_ai_3d/features/camera_measurement/domain/measurement_math.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_classifier.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_standards.dart';
import 'package:medicao_ai_3d/features/history/data/history_database.dart';
import 'package:medicao_ai_3d/features/history/data/history_report_pdf_service.dart';
import 'package:medicao_ai_3d/features/history/domain/history_models.dart';
import 'package:medicao_ai_3d/features/material_id/data/material_analyzer_service.dart';
import 'package:medicao_ai_3d/features/mechanical_components/domain/mechanical_component_matcher.dart';
import 'package:medicao_ai_3d/features/mechanical_components/domain/mechanical_component_models.dart';
import 'package:medicao_ai_3d/features/settings/domain/app_settings.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:medicao_ai_3d/features/shared/presentation/planned_module_screen.dart';
import 'package:medicao_ai_3d/features/technical_drawing/data/technical_drawing_pdf_service.dart';
import 'package:medicao_ai_3d/features/technical_drawing/domain/technical_drawing_geometry.dart';
import 'package:medicao_ai_3d/features/technical_drawing/domain/technical_drawing_models.dart';
import 'package:medicao_ai_3d/features/torque_calculator/domain/torque_calculator_engine.dart';
import 'package:medicao_ai_3d/features/torque_calculator/domain/torque_models.dart';
import 'package:medicao_ai_3d/features/weight_volume/domain/volume_weight_calculator.dart';
import 'package:medicao_ai_3d/features/weight_volume/domain/weight_volume_models.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('medicao_e2e_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('App routes every module cleanly with zero planned placeholders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = SettingsController();
    await controller.load();

    await tester.pumpWidget(MedicaoAiApp(settingsController: controller));
    await tester.pumpAndSettle();

    expect(appModules.every((m) => m.isImplemented), isTrue);

    final navTitles = [
      'Medição por câmera',
      'Identificação de materiais',
      'Medição de parafusos e roscas',
      'Calculadora de torque',
      'Cálculo de peso e volume',
      'Desenho técnico 2D e 3D',
      'Identificação de componentes mecânicos',
      'Histórico e relatórios',
      'Configurações',
    ];

    for (final title in navTitles) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PlannedModuleScreen), findsNothing);
      await tester.tap(find.byTooltip('Voltar à Tela Principal'));
      await tester.pumpAndSettle();
    }
  });

  test('End-to-end engineering pipeline from measurement to SQLite and PDF report', () async {
    // 1. Calibrated camera measurement (100 px reference = 50 mm => 2.0 px/mm)
    final calibration = MeasurementMath.buildVisualCalibration(
      referencePixelSpan: 100.0,
      knownReferenceMm: 50.0,
      referenceName: 'Bloco padrão 50 mm',
    );
    final measuredWidthMm = MeasurementMath.convertPixelsToMillimeters(
      200.0,
      calibration,
    );
    expect(measuredWidthMm, closeTo(100.0, 0.001));

    // 2. Local visual material analysis on copper-toned metallic image with specular reflection
    final imgPath = p.join(tempDir.path, 'copper_part.png');
    final bitmap = img.Image(width: 160, height: 120);
    img.fill(bitmap, color: img.ColorRgb8(196, 102, 54));
    img.fillRect(
      bitmap,
      x1: 60,
      y1: 45,
      x2: 95,
      y2: 75,
      color: img.ColorRgb8(248, 245, 240),
    );
    await File(imgPath).writeAsBytes(img.encodePng(bitmap));

    final materialService = MaterialAnalyzerService();
    final matAnalysis = await materialService.analyzeImage(imgPath);
    expect(matAnalysis.topCandidate.material.name, 'Cobre');
    expect(matAnalysis.topCandidate.confidencePercent, lessThanOrEqualTo(84));

    // 3. Weight & volume using identified material density
    final volWeight = VolumeWeightCalculator.calculate(
      input: VolumeCalculationInput(
        shape: GeometryShapeType.tube,
        dimensionUnit: MeasurementUnit.millimeters,
        outerDiameter: measuredWidthMm,
        innerDiameter: 60,
        heightOrThickness: 80,
      ),
      densityGcm3: matAnalysis.topCandidate.material.densityGcm3,
      materialName: matAnalysis.topCandidate.material.name,
    );
    expect(volWeight.isValid, isTrue);
    expect(volWeight.volumeCm3, greaterThan(400));
    expect(volWeight.weightKilograms, greaterThan(3.5));

    // 4. Fastener classification + OCR + Torque calculation
    final ocrParsed = FastenerClassifier.classifyStrengthFromOcr('8.8 M10');
    expect(ocrParsed.isIdentified, isTrue);
    expect(ocrParsed.spec?.code, '8.8');

    final m10 = FastenerStandards.threadCatalog.firstWhere(
      (t) => t.designation == 'M10',
    );
    final torque = TorqueCalculatorEngine.calculate(
      TorqueCalculationInput(
        threadSpec: m10,
        strengthClass: FastenerStandards.strengthByCode('8.8'),
        clampedMaterial: ClampedPartMaterial.steel,
        jointType: JointType.throughBoltNut,
        lubrication: LubricationCondition.lightlyOiled,
        washer: WasherCondition.flatHardened,
        assemblyCondition: AssemblyCondition.controlledTorqueWrench,
        applicableNorm: ApplicableTechnicalNorm.vdi2230,
      ),
    );
    expect(torque.hasSafeCalculatedRecommendation, isTrue);
    expect(torque.calculatedTorqueNm, inInclusiveRange(35.0, 58.0));

    // 5. Technical drawing 2D/3D + PDF export
    const dwgSpec = TechnicalDrawingSpec(
      id: 'e2e-dwg',
      partType: DrawingPartType.tube,
      partName: 'Bucha de Cobre B-100',
      drawingCode: 'E2E-001',
      materialName: 'Cobre',
      authorName: 'Eng. Adair',
      toleranceNote: 'ISO 2768-m',
      unit: MeasurementUnit.millimeters,
      outerDiameter: 100,
      innerDiameter: 60,
      length: 80,
    );
    expect(TechnicalDrawingValidator.validate(dwgSpec).isValid, isTrue);
    final dwgPdf = await TechnicalDrawingPdfService(
      directoryProvider: () async => tempDir,
    ).exportPdfToFile(dwgSpec);
    expect(await dwgPdf.exists(), isTrue);

    // 6. Mechanical component identification
    final compResult = MechanicalComponentMatcher.identify(
      const ComponentQueryInput(
        category: MechanicalComponentCategory.bearing,
        innerDiameterMm: 25,
        outerDiameterMm: 52,
        widthOrLengthMm: 15,
      ),
    );
    expect(compResult.status, ComponentMatchStatus.identified);
    expect(compResult.candidates.first.spec.referenceCode, '6205');

    // 7. SQLite persistence + consolidated PDF report
    final db = HistoryDatabase(
      customDatabaseFactory: databaseFactoryFfi,
      customDbPath: p.join(tempDir.path, 'e2e_history.db'),
    );
    const project = MaintenanceProject(
      id: 'e2e-prj',
      name: 'Inspeção Integrada E2E',
      equipmentTag: 'TAG-E2E-01',
      locationOrClient: 'Planta Piloto',
      notes: 'Validação ponta a ponta',
      createdAtIso: '2026-11-25T12:00:00Z',
      updatedAtIso: '2026-11-25T12:00:00Z',
    );
    await db.upsertProject(project);
    await db.upsertRecord(
      HistoryRecord(
        id: 'e2e-rec-1',
        projectId: project.id,
        recordType: HistoryRecordType.weightVolume,
        title: 'Bucha ${matAnalysis.topCandidate.material.name} 100×60×80 mm',
        summary: 'Volume e massa calculados offline',
        measurementsText:
            'Vol: ${volWeight.volumeCm3?.toStringAsFixed(1)} cm³ | Massa: ${volWeight.weightKilograms?.toStringAsFixed(2)} kg',
        technicalSource: 'Fórmula cilíndrica vazada + catálogo visual',
        uncertaintyOrNote: 'Calibração 2.0 px/mm',
        photoPath: imgPath,
        createdAtIso: '2026-11-25T12:01:00Z',
        updatedAtIso: '2026-11-25T12:01:00Z',
      ),
    );
    await db.upsertRecord(
      HistoryRecord(
        id: 'e2e-rec-2',
        projectId: project.id,
        recordType: HistoryRecordType.torque,
        title: 'Parafuso M10 Classe ${ocrParsed.spec?.code}',
        summary: 'Torque teórico calculado',
        measurementsText:
            '${torque.calculatedTorqueNm?.toStringAsFixed(1)} N·m',
        technicalSource: torque.technicalSource,
        uncertaintyOrNote: 'União rígida lubrificada com arruela',
        createdAtIso: '2026-11-25T12:02:00Z',
        updatedAtIso: '2026-11-25T12:02:00Z',
      ),
    );

    final records = await db.listRecords(projectId: project.id);
    expect(records.length, 2);

    final reportFile = await HistoryReportPdfService(
      directoryProvider: () async => tempDir,
    ).exportReportToFile(
      project: project,
      records: records,
      reportTitle: 'Relatório Final Integrado — MEDIÇÃO AI 3D',
    );
    expect(await reportFile.exists(), isTrue);
    final reportBytes = await reportFile.readAsBytes();
    expect(String.fromCharCodes(reportBytes.take(4)), '%PDF');
    expect(reportBytes.length, greaterThan(1500));

    await db.close();
  });
}
