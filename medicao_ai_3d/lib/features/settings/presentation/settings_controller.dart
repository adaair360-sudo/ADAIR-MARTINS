import 'package:material_ui/material_ui.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository();

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode {
    switch (_settings.themePreference) {
      case AppThemePreference.darkIndustrial:
        return ThemeMode.dark;
      case AppThemePreference.lightWorkshop:
        return ThemeMode.light;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    _settings = await _repository.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateDefaultUnit(MeasurementUnit unit) async {
    await _update(_settings.copyWith(defaultUnit: unit));
  }

  Future<void> updateDecimalPlaces(int decimalPlaces) async {
    await _update(_settings.copyWith(decimalPlaces: decimalPlaces));
  }

  Future<void> updateThemePreference(AppThemePreference preference) async {
    await _update(_settings.copyWith(themePreference: preference));
  }

  Future<void> updateOfflineOnlyMode(bool enabled) async {
    await _update(_settings.copyWith(offlineOnlyMode: enabled));
  }

  Future<void> updateAllowCloudAiUpload(bool allowed) async {
    await _update(
      _settings.copyWith(
        offlineOnlyMode: allowed ? false : _settings.offlineOnlyMode,
        allowCloudAiUpload: allowed,
      ),
    );
  }

  Future<void> updateShowMetrologyBanner(bool show) async {
    await _update(_settings.copyWith(showMetrologyBanner: show));
  }

  Future<void> resetToDefaults() async {
    _settings = await _repository.reset();
    notifyListeners();
  }

  Future<void> _update(AppSettings next) async {
    if (next == _settings) {
      return;
    }
    _settings = next;
    notifyListeners();
    await _repository.save(next);
  }
}
