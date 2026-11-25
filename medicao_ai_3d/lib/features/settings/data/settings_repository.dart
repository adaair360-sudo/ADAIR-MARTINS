import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

class SettingsRepository {
  static const String _keyDefaultUnit = 'settings_default_unit';
  static const String _keyDecimalPlaces = 'settings_decimal_places';
  static const String _keyOfflineOnly = 'settings_offline_only';
  static const String _keyAllowCloudAiUpload = 'settings_allow_cloud_ai_upload';
  static const String _keyShowMetrologyBanner =
      'settings_show_metrology_banner';
  static const String _keyThemePreference = 'settings_theme_preference';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineOnly = prefs.getBool(_keyOfflineOnly) ?? true;
    final allowUpload = offlineOnly
        ? false
        : (prefs.getBool(_keyAllowCloudAiUpload) ?? false);

    return AppSettings(
      defaultUnit: MeasurementUnit.fromSymbol(prefs.getString(_keyDefaultUnit)),
      decimalPlaces: (prefs.getInt(_keyDecimalPlaces) ?? 2).clamp(1, 3),
      offlineOnlyMode: offlineOnly,
      allowCloudAiUpload: allowUpload,
      showMetrologyBanner: prefs.getBool(_keyShowMetrologyBanner) ?? true,
      themePreference: AppThemePreference.fromKey(
        prefs.getString(_keyThemePreference),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultUnit, settings.defaultUnit.symbol);
    await prefs.setInt(_keyDecimalPlaces, settings.decimalPlaces);
    await prefs.setBool(_keyOfflineOnly, settings.offlineOnlyMode);
    await prefs.setBool(
      _keyAllowCloudAiUpload,
      settings.offlineOnlyMode ? false : settings.allowCloudAiUpload,
    );
    await prefs.setBool(_keyShowMetrologyBanner, settings.showMetrologyBanner);
    await prefs.setString(_keyThemePreference, settings.themePreference.storageKey);
  }

  Future<AppSettings> reset() async {
    const defaults = AppSettings();
    await save(defaults);
    return defaults;
  }
}
