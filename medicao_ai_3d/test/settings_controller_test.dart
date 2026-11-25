import 'package:flutter_test/flutter_test.dart';
import 'package:medicao_ai_3d/features/settings/domain/app_settings.dart';
import 'package:medicao_ai_3d/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SettingsController loads default values', () async {
    final controller = SettingsController();
    await controller.load();

    expect(controller.isLoaded, isTrue);
    expect(controller.settings.defaultUnit, MeasurementUnit.millimeters);
    expect(controller.settings.decimalPlaces, 2);
    expect(controller.settings.offlineOnlyMode, isTrue);
    expect(controller.settings.allowCloudAiUpload, isFalse);
    expect(controller.settings.showMetrologyBanner, isTrue);
  });

  test('SettingsController persists unit, decimals, and theme', () async {
    final controller = SettingsController();
    await controller.load();

    await controller.updateDefaultUnit(MeasurementUnit.centimeters);
    await controller.updateDecimalPlaces(3);
    await controller.updateThemePreference(AppThemePreference.lightWorkshop);

    final reloaded = SettingsController();
    await reloaded.load();

    expect(reloaded.settings.defaultUnit, MeasurementUnit.centimeters);
    expect(reloaded.settings.decimalPlaces, 3);
    expect(reloaded.settings.themePreference, AppThemePreference.lightWorkshop);
  });

  test('Enabling offlineOnlyMode disables allowCloudAiUpload', () async {
    final controller = SettingsController();
    await controller.load();

    await controller.updateAllowCloudAiUpload(true);
    expect(controller.settings.offlineOnlyMode, isFalse);
    expect(controller.settings.allowCloudAiUpload, isTrue);

    await controller.updateOfflineOnlyMode(true);
    expect(controller.settings.offlineOnlyMode, isTrue);
    expect(controller.settings.allowCloudAiUpload, isFalse);
  });

  test('resetToDefaults restores factory settings', () async {
    final controller = SettingsController();
    await controller.load();

    await controller.updateDefaultUnit(MeasurementUnit.meters);
    await controller.updateDecimalPlaces(1);
    await controller.updateShowMetrologyBanner(false);

    await controller.resetToDefaults();
    expect(controller.settings, const AppSettings());
  });
}
