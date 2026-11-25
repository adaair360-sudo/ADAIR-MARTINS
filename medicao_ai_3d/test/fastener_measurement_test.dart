import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/data/head_marking_ocr_service.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_classifier.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_models.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_standards.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/presentation/fastener_measurement_screen.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _createTempHeadPng() async {
  final image = img.Image(width: 80, height: 80);
  img.fill(image, color: img.ColorRgb8(180, 185, 190));
  final dir = await Directory.systemTemp.createTemp('head_ocr_');
  final file = File('${dir.path}/head.png');
  await file.writeAsBytes(img.encodePng(image));
  return file.path;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Standards include all fastener types, examples, and strength classes', () {
    expect(FastenerType.values.length, 7);
    expect(FastenerStandards.quickExamples, ['M6', 'M8', 'M10', 'M12', 'M16', 'M20']);
    final codes = FastenerStandards.strengthClasses.map((s) => s.code).toSet();
    expect(codes, containsAll(['4.6', '5.8', '8.8', '10.9', '12.9', 'A2', 'A4']));
  });

  test('Thread matching distinguishes ISO coarse, ISO fine, UNC, and UNF', () {
    final m10 = FastenerClassifier.matchThread(
      outerDiameterMm: 9.95,
      threadPitchMm: 1.50,
    );
    expect(m10.first.spec.designation, 'M10');
    expect(m10.first.spec.standard, ThreadStandard.metricIso);
    expect(m10.first.spec.series, ThreadSeries.coarse);

    final m12Fine = FastenerClassifier.matchThread(
      outerDiameterMm: 11.92,
      threadPitchMm: 1.25,
    );
    expect(m12Fine.first.spec.designation, 'M12x1,25');
    expect(m12Fine.first.spec.series, ThreadSeries.fine);

    final halfUnc = FastenerClassifier.matchThread(
      outerDiameterMm: 12.68,
      threadPitchMm: 1.95,
    );
    expect(halfUnc.first.spec.designation, '1/2"-13 UNC');
    expect(halfUnc.first.spec.standard, ThreadStandard.unc);

    final halfUnf = FastenerClassifier.matchThread(
      outerDiameterMm: 12.68,
      threadPitchMm: 1.27,
    );
    expect(halfUnf.first.spec.designation, '1/2"-20 UNF');
    expect(halfUnf.first.spec.standard, ThreadStandard.unf);
  });

  test('OCR strength parser recognizes stamped classes and refuses guessing', () {
    final r88 = FastenerClassifier.classifyStrengthFromOcr('THE 8.8');
    expect(r88.isIdentified, isTrue);
    expect(r88.spec?.code, '8.8');
    expect(r88.source, StrengthClassSource.ocrReading);

    final rA4 = FastenerClassifier.classifyStrengthFromOcr(
      'A4-80',
      hasStainlessAppearanceEvidence: true,
    );
    expect(rA4.isIdentified, isTrue);
    expect(rA4.spec?.code, 'A4');

    final empty = FastenerClassifier.classifyStrengthFromOcr('');
    expect(empty.isIdentified, isFalse);
    expect(empty.source, StrengthClassSource.indeterminate);

    final illegible = FastenerClassifier.classifyStrengthFromOcr('###');
    expect(illegible.isIdentified, isFalse);
    expect(illegible.source, StrengthClassSource.indeterminate);
  });

  test('Luminance profile pitch estimator recovers 1.5 mm pitch when calibrated', () {
    const pxPerMm = 10.0;
    const pitchMm = 1.5;
    final profile = List<double>.generate(
      120,
      (i) => 128 + 80 * math.sin(2 * math.pi * i / (pitchMm * pxPerMm)),
    );
    final est = FastenerClassifier.estimatePitchFromLuminanceProfile(
      axialLuminance: profile,
      pixelsPerMm: pxPerMm,
    );
    expect(est, closeTo(1.5, 0.15));

    final lowRes = FastenerClassifier.estimatePitchFromLuminanceProfile(
      axialLuminance: profile,
      pixelsPerMm: 3.0,
    );
    expect(lowRes, isNull);
  });

  testWidgets(
    'FastenerMeasurementScreen supports quick metric lookup, manual editing, and OCR strength class',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final headPath = await tester.runAsync(_createTempHeadPng);
      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      final mockOcr = HeadMarkingOcrService(
        customExtractor: (_) async => '10.9',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FastenerMeasurementScreen(
              settingsController: controller,
              ocrService: mockOcr,
              initialHeadImagePath: headPath,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final m12Chip = find.widgetWithText(ActionChip, 'M12');
      await tester.ensureVisible(m12Chip);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(m12Chip);
      await tester.pump();

      expect(find.textContaining('M12  •  Rosca direita'), findsOneWidget);
      expect(find.textContaining('Classe 10.9'), findsOneWidget);
      expect(find.textContaining('1000 MPa'), findsOneWidget);
    },
  );
}
