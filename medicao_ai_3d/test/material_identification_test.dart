import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/material_id/data/material_analyzer_service.dart';
import 'package:medicao_ai_3d/features/material_id/domain/industrial_material.dart';
import 'package:medicao_ai_3d/features/material_id/presentation/material_identification_screen.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _createMaterialSamplePng({
  required int r,
  required int g,
  required int b,
  bool addSpecularHighlight = false,
}) async {
  final image = img.Image(width: 160, height: 120);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  if (addSpecularHighlight) {
    img.fillRect(
      image,
      x1: 60,
      y1: 45,
      x2: 95,
      y2: 75,
      color: img.ColorRgb8(248, 245, 240),
    );
  }
  final dir = await Directory.systemTemp.createTemp('mat_test_');
  final file = File('${dir.path}/sample.png');
  await file.writeAsBytes(img.encodePng(image));
  return file.path;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Catalog contains all 14 required industrial materials', () {
    expect(industrialMaterialsCatalog.length, 14);
    final names = industrialMaterialsCatalog.map((m) => m.name).toSet();
    expect(
      names,
      containsAll([
        'Aço carbono',
        'Aço inoxidável',
        'Ferro fundido',
        'Alumínio',
        'Cobre',
        'Bronze',
        'Latão',
        'PVC',
        'Nylon',
        'Polietileno',
        'Borracha',
        'Madeira',
        'Vidro',
        'Cerâmica',
      ]),
    );
  });

  test('Copper-like image identifies copper with bounded confidence', () async {
    final path = await _createMaterialSamplePng(
      r: 196,
      g: 102,
      b: 54,
      addSpecularHighlight: true,
    );
    final service = MaterialAnalyzerService();
    final result = await service.analyzeImage(path);

    expect(result.topCandidate.material.id, 'copper');
    expect(result.topCandidate.confidencePercent, lessThanOrEqualTo(84));
    expect(result.opticalWarnings, contains(materialChemicalDisclaimer));
  });

  test('Dark matte image favors rubber/dark matte material and supports manual correction', () async {
    final path = await _createMaterialSamplePng(
      r: 28,
      g: 30,
      b: 32,
      addSpecularHighlight: false,
    );
    final service = MaterialAnalyzerService();
    final result = await service.analyzeImage(path);

    expect(result.topCandidate.material.id, 'rubber');
    expect(result.isManuallyCorrected, isFalse);

    final corrected = result.copyWithManualSelection(materialById('cast_iron'));
    expect(corrected.isManuallyCorrected, isTrue);
    expect(corrected.selectedMaterial.id, 'cast_iron');
  });

  testWidgets(
    'MaterialIdentificationScreen displays analysis, disclaimer, and allows manual correction',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final path = await tester.runAsync(
        () => _createMaterialSamplePng(
          r: 196,
          g: 102,
          b: 54,
          addSpecularHighlight: true,
        ),
      );
      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialIdentificationScreen(
              settingsController: controller,
              initialImagePath: path,
              skipHardwareChecks: true,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Material Mais Provável (IA Visual)'), findsOneWidget);
      expect(find.text('Cobre'), findsOneWidget);
      expect(find.textContaining('8.96 g/cm³'), findsOneWidget);
      expect(find.text(materialChemicalDisclaimer), findsOneWidget);

      final fixBtn = find.text('Corrigir Material Manualmente');
      await tester.ensureVisible(fixBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(fixBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Aço inoxidável');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aço inoxidável').last);
      await tester.pumpAndSettle();

      expect(find.text('Material Confirmado Manualmente'), findsOneWidget);
      expect(find.text('Aço inoxidável'), findsOneWidget);
      expect(find.textContaining('7.93 g/cm³'), findsOneWidget);
    },
  );
}
