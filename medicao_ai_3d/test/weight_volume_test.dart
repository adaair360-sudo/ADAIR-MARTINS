import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/settings/domain/app_settings.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:medicao_ai_3d/features/weight_volume/domain/volume_weight_calculator.dart';
import 'package:medicao_ai_3d/features/weight_volume/domain/weight_volume_models.dart';
import 'package:medicao_ai_3d/features/weight_volume/presentation/weight_volume_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Calculates rectangular block, plate, and cylinder volumes and weights accurately', () {
    // 100 x 50 x 20 mm steel block = 10 x 5 x 2 cm = 100 cm^3; 100 * 7.85 = 785 g
    final block = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.rectangularBlock,
        dimensionUnit: MeasurementUnit.millimeters,
        length: 100,
        width: 50,
        heightOrThickness: 20,
      ),
      densityGcm3: 7.85,
      materialName: 'Aço carbono',
    );
    expect(block.isValid, isTrue);
    expect(block.volumeCm3, closeTo(100.0, 0.001));
    expect(block.volumeLiters, closeTo(0.1, 0.0001));
    expect(block.volumeM3, closeTo(0.0001, 0.000001));
    expect(block.weightGrams, closeTo(785.0, 0.01));
    expect(block.weightKilograms, closeTo(0.785, 0.001));

    // Cylinder D=10 cm, H=20 cm => pi * 25 * 20 = 500*pi cm^3
    final cyl = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.cylinder,
        dimensionUnit: MeasurementUnit.centimeters,
        outerDiameter: 10,
        heightOrThickness: 20,
      ),
      densityGcm3: 2.70,
      materialName: 'Alumínio',
    );
    expect(cyl.isValid, isTrue);
    expect(cyl.volumeCm3, closeTo(500 * math.pi, 0.01));
  });

  test('Calculates tube, sphere, cone, hollow part, and irregular geometry', () {
    // Tube D_ext=6 cm, D_int=4 cm, L=10 cm => pi * (9 - 4) * 10 = 50*pi
    final tube = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.tube,
        dimensionUnit: MeasurementUnit.centimeters,
        outerDiameter: 6,
        innerDiameter: 4,
        heightOrThickness: 10,
      ),
      densityGcm3: 7.93,
      materialName: 'Aço inoxidável',
    );
    expect(tube.isValid, isTrue);
    expect(tube.isHollowCalculation, isTrue);
    expect(tube.volumeCm3, closeTo(50 * math.pi, 0.01));

    // Sphere D=6 cm (R=3) => (4/3)*pi*27 = 36*pi
    final sphere = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.sphere,
        dimensionUnit: MeasurementUnit.centimeters,
        outerDiameter: 6,
      ),
      densityGcm3: 8.96,
      materialName: 'Cobre',
    );
    expect(sphere.isValid, isTrue);
    expect(sphere.volumeCm3, closeTo(36 * math.pi, 0.01));

    // Cone D=6 cm (R=3), H=10 cm => (1/3)*pi*9*10 = 30*pi
    final cone = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.cone,
        dimensionUnit: MeasurementUnit.centimeters,
        outerDiameter: 6,
        heightOrThickness: 10,
      ),
      densityGcm3: 7.85,
      materialName: 'Aço carbono',
    );
    expect(cone.isValid, isTrue);
    expect(cone.volumeCm3, closeTo(30 * math.pi, 0.01));

    // Hollow block 10x10x10 cm, wall=1 cm => 1000 - 8^3 = 488 cm^3
    final hollow = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.hollowPart,
        dimensionUnit: MeasurementUnit.centimeters,
        length: 10,
        width: 10,
        heightOrThickness: 10,
        wallThickness: 1,
      ),
      densityGcm3: 2.70,
      materialName: 'Alumínio',
    );
    expect(hollow.isValid, isTrue);
    expect(hollow.isHollowCalculation, isTrue);
    expect(hollow.volumeCm3, closeTo(488.0, 0.01));

    // Irregular geometry missing data returns invalid instead of inventing
    final irregularInvalid = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.irregularGeometry,
        dimensionUnit: MeasurementUnit.centimeters,
        irregularMethod: IrregularInputMethod.crossSectionAreaAndThickness,
      ),
      densityGcm3: 7.85,
      materialName: 'Aço carbono',
    );
    expect(irregularInvalid.isValid, isFalse);

    // Irregular fluid displacement 500 mL -> 640 mL = 140 cm^3
    final irregularValid = VolumeWeightCalculator.calculate(
      input: const VolumeCalculationInput(
        shape: GeometryShapeType.irregularGeometry,
        dimensionUnit: MeasurementUnit.centimeters,
        irregularMethod: IrregularInputMethod.fluidDisplacement,
        fluidInitialMl: 500,
        fluidFinalMl: 640,
      ),
      densityGcm3: 7.85,
      materialName: 'Aço carbono',
    );
    expect(irregularValid.isValid, isTrue);
    expect(irregularValid.volumeCm3, closeTo(140.0, 0.001));
  });

  testWidgets(
    'WeightVolumeScreen calculates volume in cm3/m3/L and weight with editable density',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = SettingsController();
      await tester.runAsync(() => controller.load());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightVolumeScreen(settingsController: controller),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Comprimento (mm)'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Largura (mm)'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Altura (mm)'),
        '100',
      );
      await tester.pump();

      // 100x100x100 mm = 1000 cm3 = 1 L = 0.001 m3; at 7.85 g/cm3 = 7.85 kg (7850 g)
      expect(find.textContaining('1000.00 cm³'), findsOneWidget);
      expect(find.textContaining('1.0000 L'), findsOneWidget);
      expect(find.textContaining('7.850 kg'), findsOneWidget);
      expect(find.textContaining('7850.00 g'), findsOneWidget);

      // Edit density manually to 2.70 g/cm3
      await tester.enterText(
        find.widgetWithText(TextField, 'Densidade (g/cm³)'),
        '2.70',
      );
      await tester.pump();

      expect(find.textContaining('2.700 kg'), findsOneWidget);
      expect(find.textContaining('2700.00 g'), findsOneWidget);
    },
  );
}
