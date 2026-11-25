import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/camera_measurement/data/opencv_service.dart';
import 'package:medicao_ai_3d/features/camera_measurement/domain/camera_measurement_models.dart';
import 'package:medicao_ai_3d/features/camera_measurement/domain/measurement_math.dart';
import 'package:medicao_ai_3d/features/camera_measurement/presentation/camera_measurement_screen.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _createSyntheticPartPng({
  int width = 320,
  int height = 240,
  int rectX1 = 60,
  int rectY1 = 70,
  int rectX2 = 260,
  int rectY2 = 170,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, 25, 32));
  img.fillRect(
    image,
    x1: rectX1,
    y1: rectY1,
    x2: rectX2,
    y2: rectY2,
    color: img.ColorRgb8(220, 230, 240),
  );
  final tempDir = await Directory.systemTemp.createTemp('medicao_test_');
  final file = File('${tempDir.path}/peca_teste.png');
  await file.writeAsBytes(img.encodePng(image));
  return file.path;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Uncalibrated measurement never returns mm/cm/m values', () {
    final mm = MeasurementMath.convertPixelsToMillimeters(200, null);
    expect(mm, isNull);

    final uncertainty = MeasurementMath.evaluateUncertainty(
      calibration: null,
      measuredPixels: 200,
      sharpnessVariance: 180,
      contrastStdDev: 40,
    );
    expect(uncertainty.qualityLevel, MeasurementQualityLevel.uncalibrated);
    expect(uncertainty.uncertaintyMm, isNull);
    expect(uncertainty.confidenceScore, 0);
  });

  test('Visual calibration converts pixels to mm, cm, and m accurately', () {
    final calibration = MeasurementMath.buildVisualCalibration(
      referencePixelSpan: 200,
      knownReferenceMm: 85.60,
      referenceName: 'Cartão ISO ID-1',
    );
    expect(calibration, isNotNull);
    expect(calibration!.isCalibrated, isTrue);

    final measuredMm = MeasurementMath.convertPixelsToMillimeters(
      100,
      calibration,
    );
    expect(measuredMm, closeTo(42.80, 0.01));
    expect(UnitConversions.toCentimeters(measuredMm!), closeTo(4.28, 0.001));
    expect(UnitConversions.toMeters(measuredMm), closeTo(0.0428, 0.0001));
  });

  test('OpenCvService pure-Dart fallback detects crisp rectangular contour', () async {
    final path = await _createSyntheticPartPng();
    final service = OpenCvService();
    final result = await service.analyzeImage(path);

    expect(result.imageWidth, 320);
    expect(result.imageHeight, 240);
    expect(result.contours, isNotEmpty);
    final contour = result.contours.first;
    expect(contour.shapeHint, 'rectangular');
    expect(contour.majorPx, closeTo(200, 6));
    expect(contour.minorPx, closeTo(100, 6));
    expect(result.sharpnessVariance, greaterThan(50));
  });

  testWidgets(
    'CameraMeasurementScreen enforces calibration before displaying mm/cm/m',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final imagePath = await tester.runAsync(() => _createSyntheticPartPng());
      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraMeasurementScreen(
              settingsController: controller,
              initialImagePath: imagePath,
              skipHardwareChecks: true,
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('MEDIDA NÃO CALIBRADA'), findsOneWidget);
      expect(find.textContaining('Contornos detectados'), findsOneWidget);

      // Adopt detected contour as calibration reference (ISO card 85.60 mm)
      final calButton = find.widgetWithText(TextButton, 'Calibrar').first;
      await tester.ensureVisible(calButton);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(calButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Calibração ativa:'), findsWidgets);
      expect(find.textContaining('MEDIDA NÃO CALIBRADA'), findsNothing);

      // Measure detected contour
      final measureButton = find.widgetWithText(TextButton, 'Medir').first;
      await tester.ensureVisible(measureButton);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(measureButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('85.60 mm'), findsOneWidget);
      expect(find.textContaining('8.56 cm'), findsOneWidget);
      expect(find.textContaining('0.0856 m'), findsOneWidget);
      expect(find.textContaining('Incerteza: ±'), findsWidgets);
    },
  );
}
