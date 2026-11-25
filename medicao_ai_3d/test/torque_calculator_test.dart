import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/fastener_measurement/domain/fastener_standards.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:medicao_ai_3d/features/torque_calculator/domain/torque_calculator_engine.dart';
import 'package:medicao_ai_3d/features/torque_calculator/domain/torque_models.dart';
import 'package:medicao_ai_3d/features/torque_calculator/presentation/torque_calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Blocks torque recommendation when essential parameters are missing', () {
    final result = TorqueCalculatorEngine.calculate(
      const TorqueCalculationInput(
        threadSpec: null,
        strengthClass: null,
        clampedMaterial: ClampedPartMaterial.steel,
        jointType: null,
        lubrication: null,
        washer: null,
        assemblyCondition: null,
        applicableNorm: ApplicableTechnicalNorm.vdi2230,
      ),
    );

    expect(result.hasSafeCalculatedRecommendation, isFalse);
    expect(result.calculatedTorqueNm, isNull);
    expect(result.missingEssentialData, isNotEmpty);
  });

  test('Blocks metallic formula torque for polymer/gasket joints', () {
    final m10 = FastenerStandards.threadCatalog.firstWhere(
      (t) => t.designation == 'M10',
    );
    final result = TorqueCalculatorEngine.calculate(
      TorqueCalculationInput(
        threadSpec: m10,
        strengthClass: FastenerStandards.strengthByCode('8.8'),
        clampedMaterial: ClampedPartMaterial.polymerOrGasket,
        jointType: JointType.gasketOrSeal,
        lubrication: LubricationCondition.lightlyOiled,
        washer: WasherCondition.flatHardened,
        assemblyCondition: AssemblyCondition.controlledTorqueWrench,
        applicableNorm: ApplicableTechnicalNorm.vdi2230,
      ),
    );

    expect(result.hasSafeCalculatedRecommendation, isFalse);
    expect(result.calculatedTorqueNm, isNull);
  });

  test('Computes realistic VDI 2230 torque for M10 8.8 and distinguishes lubrication & stainless warnings', () {
    final m10 = FastenerStandards.threadCatalog.firstWhere(
      (t) => t.designation == 'M10',
    );
    final dryOrOiled = TorqueCalculatorEngine.calculate(
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

    expect(dryOrOiled.hasSafeCalculatedRecommendation, isTrue);
    expect(dryOrOiled.calculatedTorqueNm, inInclusiveRange(35.0, 58.0));
    expect(dryOrOiled.technicalSource, contains('VDI 2230'));

    final moly = TorqueCalculatorEngine.calculate(
      TorqueCalculationInput(
        threadSpec: m10,
        strengthClass: FastenerStandards.strengthByCode('8.8'),
        clampedMaterial: ClampedPartMaterial.steel,
        jointType: JointType.throughBoltNut,
        lubrication: LubricationCondition.molyGrease,
        washer: WasherCondition.flatHardened,
        assemblyCondition: AssemblyCondition.controlledTorqueWrench,
        applicableNorm: ApplicableTechnicalNorm.vdi2230,
      ),
    );

    expect(moly.calculatedTorqueNm!, lessThan(dryOrOiled.calculatedTorqueNm!));

    final dryStainless = TorqueCalculatorEngine.calculate(
      TorqueCalculationInput(
        threadSpec: m10,
        strengthClass: FastenerStandards.strengthByCode('A4'),
        clampedMaterial: ClampedPartMaterial.steel,
        jointType: JointType.throughBoltNut,
        lubrication: LubricationCondition.dryDegreased,
        washer: WasherCondition.flatHardened,
        assemblyCondition: AssemblyCondition.controlledTorqueWrench,
        applicableNorm: ApplicableTechnicalNorm.iso3506,
      ),
    );

    expect(
      dryStainless.warnings.any((w) => w.contains('ENGRIPAMENTO')),
      isTrue,
    );
  });

  testWidgets(
    'TorqueCalculatorScreen blocks incomplete data and distinguishes calculated, manufacturer, and project torque',
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
            body: TorqueCalculatorScreen(settingsController: controller),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Cálculo bloqueado — faltam dados essenciais'),
        findsOneWidget,
      );

      await tester.tap(find.text('Exemplo M10 8.8'));
      await tester.pump();

      expect(
        find.text('Cálculo bloqueado — faltam dados essenciais'),
        findsNothing,
      );
      expect(
        find.text('TORQUE CALCULADO TEÓRICO (REFERÊNCIA ANALÍTICA)'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Torque fabricante (N·m)'),
        '48.5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Torque de projeto (N·m)'),
        '52.0',
      );
      await tester.pump();

      expect(
        find.text('TORQUE ESPECIFICADO EM PROJETO (PRIORIDADE 1)'),
        findsOneWidget,
      );
      expect(
        find.text('TORQUE RECOMENDADO PELO FABRICANTE (PRIORIDADE 2)'),
        findsOneWidget,
      );
    },
  );
}
