import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/features/mechanical_components/data/component_code_ocr_service.dart';
import 'package:medicao_ai_3d/features/mechanical_components/domain/mechanical_component_matcher.dart';
import 'package:medicao_ai_3d/features/mechanical_components/domain/mechanical_component_models.dart';
import 'package:medicao_ai_3d/features/mechanical_components/domain/mechanical_components_catalog.dart';
import 'package:medicao_ai_3d/features/mechanical_components/presentation/mechanical_components_screen.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Catalog covers all 10 required mechanical component categories', () {
    final expected = [
      MechanicalComponentCategory.bearing,
      MechanicalComponentCategory.oilSeal,
      MechanicalComponentCategory.gear,
      MechanicalComponentCategory.shaft,
      MechanicalComponentCategory.pulley,
      MechanicalComponentCategory.bushing,
      MechanicalComponentCategory.coupling,
      MechanicalComponentCategory.chain,
      MechanicalComponentCategory.belt,
      MechanicalComponentCategory.housing,
    ];
    for (final category in expected) {
      expect(
        mechanicalComponentsCatalog.any((c) => c.category == category),
        isTrue,
        reason: 'Missing catalog entry for $category',
      );
    }
  });

  test('Requests additional data when dimensions are ambiguous or insufficient', () {
    // Only d = 25 mm matches multiple bearings (6005, 6205, 6305, 22205), seals, bushings, housings
    final ambiguous = MechanicalComponentMatcher.identify(
      const ComponentQueryInput(
        category: MechanicalComponentCategory.bearing,
        innerDiameterMm: 25,
      ),
    );
    expect(ambiguous.status, ComponentMatchStatus.needsMoreData);
    expect(ambiguous.requestedAdditionalData, isNotEmpty);

    // Providing d=25, D=52, B=15 resolves unambiguously to 6205
    final exact = MechanicalComponentMatcher.identify(
      const ComponentQueryInput(
        category: MechanicalComponentCategory.bearing,
        innerDiameterMm: 25,
        outerDiameterMm: 52,
        widthOrLengthMm: 15,
      ),
    );
    expect(exact.status, ComponentMatchStatus.identified);
    expect(exact.candidates.first.spec.referenceCode, '6205');
  });

  test('Identifies components by reference code and extracts OCR tokens cleanly', () {
    final token1 = ComponentCodeOcrService.extractBestReferenceToken(
      'SKF ITALY 6204-2RSH C3',
    );
    expect(token1, contains('6204'));

    final housing = MechanicalComponentMatcher.identify(
      const ComponentQueryInput(referenceText: 'ucp205'),
    );
    expect(housing.status, ComponentMatchStatus.identified);
    expect(housing.candidates.first.spec.referenceCode, 'UCP 205');
  });

  testWidgets(
    'MechanicalComponentsScreen requests complementary measurements for ambiguous input and identifies exact code',
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
            body: MechanicalComponentsScreen(
              settingsController: controller,
              ocrService: ComponentCodeOcrService(
                customExtractor: (_) async => 'SKF 6204-2RS',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter only d = 25 -> must ask for complementary dimensions
      await tester.enterText(
        find.widgetWithText(TextField, 'Diâm. interno / eixo d (mm)'),
        '25',
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.textContaining('Dados complementares necessários'),
        find.byType(ListView),
        const Offset(0, -250),
      );
      expect(
        find.textContaining('Dados complementares necessários'),
        findsOneWidget,
      );

      // Clear and search by exact reference code UCP 205
      await tester.dragUntilVisible(
        find.text('Limpar busca'),
        find.byType(ListView),
        const Offset(0, 250),
      );
      await tester.tap(find.text('Limpar busca'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Código ou fabricante'),
        'UCP 205',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('UCP 205'), findsWidgets);
      expect(
        find.textContaining('Mancal pedestal com rolamento autoalinhável UCP 205'),
        findsOneWidget,
      );
    },
  );
}
