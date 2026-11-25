import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medicao_ai_3d/app.dart';
import 'package:medicao_ai_3d/core/constants/app_modules.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SettingsController> createLoadedController() async {
    final controller = SettingsController();
    await controller.load();
    return controller;
  }

  testWidgets('Tela Principal displays MEDIÇÃO AI 3D and all 9 modules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await createLoadedController();
    await tester.pumpWidget(MedicaoAiApp(settingsController: controller));
    await tester.pumpAndSettle();

    expect(find.text('MEDIÇÃO AI 3D'), findsWidgets);
    expect(appModules.length, 9);

    for (final module in appModules) {
      await tester.scrollUntilVisible(
        find.text(module.title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(module.title), findsOneWidget);
    }
  });

  testWidgets('Search filters modules and opens Configurações', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await createLoadedController();
    await tester.pumpWidget(MedicaoAiApp(settingsController: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Configurações');
    await tester.pumpAndSettle();

    final configCardFinder = find.descendant(
      of: find.byType(Card),
      matching: find.text('Configurações'),
    );
    expect(configCardFinder, findsOneWidget);
    expect(find.text('Calculadora de torque'), findsNothing);

    await tester.tap(configCardFinder);
    await tester.pumpAndSettle();

    expect(find.text('Unidades e Exibição Técnica'), findsOneWidget);
    expect(find.text('Operar somente offline'), findsOneWidget);

    await tester.tap(find.text('CM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar à Tela Principal'));
    await tester.pumpAndSettle();

    expect(find.text('Unidade: cm'), findsOneWidget);
  });

  testWidgets('All 9 modules are implemented and navigation returns to Tela Principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    expect(appModules.every((m) => m.isImplemented), isTrue);

    final controller = await createLoadedController();
    await tester.pumpWidget(MedicaoAiApp(settingsController: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Torque').last);
    await tester.pumpAndSettle();

    expect(find.text('Calculadora de torque'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar à Tela Principal'));
    await tester.pumpAndSettle();

    expect(find.text('Módulos do Sistema'), findsOneWidget);
  });

  testWidgets('Safety guidelines dialog opens from Tela Principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await createLoadedController();
    await tester.pumpWidget(MedicaoAiApp(settingsController: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diretrizes'));
    await tester.pumpAndSettle();

    expect(find.text('Segurança e Confiabilidade'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Segurança e Confiabilidade'), findsNothing);
  });
}
