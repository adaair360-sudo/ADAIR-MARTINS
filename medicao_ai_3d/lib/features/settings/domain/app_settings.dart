enum MeasurementUnit {
  millimeters('mm', 'Milímetros (mm)'),
  centimeters('cm', 'Centímetros (cm)'),
  meters('m', 'Metros (m)');

  const MeasurementUnit(this.symbol, this.label);

  final String symbol;
  final String label;

  static MeasurementUnit fromSymbol(String? value) {
    return MeasurementUnit.values.firstWhere(
      (unit) => unit.symbol == value,
      orElse: () => MeasurementUnit.millimeters,
    );
  }
}

enum AppThemePreference {
  darkIndustrial('dark', 'Industrial Escuro'),
  lightWorkshop('light', 'Oficina Claro'),
  system('system', 'Seguir Sistema');

  const AppThemePreference(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static AppThemePreference fromKey(String? value) {
    return AppThemePreference.values.firstWhere(
      (pref) => pref.storageKey == value,
      orElse: () => AppThemePreference.darkIndustrial,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.defaultUnit = MeasurementUnit.millimeters,
    this.decimalPlaces = 2,
    this.offlineOnlyMode = true,
    this.allowCloudAiUpload = false,
    this.showMetrologyBanner = true,
    this.themePreference = AppThemePreference.darkIndustrial,
  });

  final MeasurementUnit defaultUnit;
  final int decimalPlaces;
  final bool offlineOnlyMode;
  final bool allowCloudAiUpload;
  final bool showMetrologyBanner;
  final AppThemePreference themePreference;

  AppSettings copyWith({
    MeasurementUnit? defaultUnit,
    int? decimalPlaces,
    bool? offlineOnlyMode,
    bool? allowCloudAiUpload,
    bool? showMetrologyBanner,
    AppThemePreference? themePreference,
  }) {
    final nextOffline = offlineOnlyMode ?? this.offlineOnlyMode;
    final nextAllowUpload = nextOffline
        ? false
        : (allowCloudAiUpload ?? this.allowCloudAiUpload);

    return AppSettings(
      defaultUnit: defaultUnit ?? this.defaultUnit,
      decimalPlaces: (decimalPlaces ?? this.decimalPlaces).clamp(1, 3),
      offlineOnlyMode: nextOffline,
      allowCloudAiUpload: nextAllowUpload,
      showMetrologyBanner: showMetrologyBanner ?? this.showMetrologyBanner,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppSettings &&
            other.defaultUnit == defaultUnit &&
            other.decimalPlaces == decimalPlaces &&
            other.offlineOnlyMode == offlineOnlyMode &&
            other.allowCloudAiUpload == allowCloudAiUpload &&
            other.showMetrologyBanner == showMetrologyBanner &&
            other.themePreference == themePreference;
  }

  @override
  int get hashCode => Object.hash(
    defaultUnit,
    decimalPlaces,
    offlineOnlyMode,
    allowCloudAiUpload,
    showMetrologyBanner,
    themePreference,
  );
}
