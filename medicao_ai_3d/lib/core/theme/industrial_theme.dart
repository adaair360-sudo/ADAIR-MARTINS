import 'package:material_ui/material_ui.dart';

class IndustrialColors {
  const IndustrialColors._();

  // Dark industrial palette (steel, graphite, precision cyan & safety amber)
  static const Color darkBackground = Color(0xFF0B1117);
  static const Color darkSurface = Color(0xFF131C26);
  static const Color darkSurfaceElevated = Color(0xFF1A2634);
  static const Color darkBorder = Color(0xFF28384A);

  static const Color cyanAccent = Color(0xFF00BCD4);
  static const Color cyanBright = Color(0xFF4DD0E1);
  static const Color safetyAmber = Color(0xFFFFB300);
  static const Color safetyOrange = Color(0xFFFF7043);
  static const Color industrialGreen = Color(0xFF26A69A);
  static const Color blueprintBlue = Color(0xFF42A5F5);

  // Light workshop palette (high contrast for bright industrial environments)
  static const Color lightBackground = Color(0xFFF1F4F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFE5ECF3);
  static const Color lightBorder = Color(0xFFC9D5E2);
  static const Color navyPrimary = Color(0xFF0F2942);
}

class IndustrialTheme {
  const IndustrialTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: IndustrialColors.cyanAccent,
      onPrimary: const Color(0xFF002026),
      primaryContainer: const Color(0xFF004F5A),
      onPrimaryContainer: const Color(0xFFB2EBF2),
      secondary: IndustrialColors.safetyAmber,
      onSecondary: const Color(0xFF261900),
      secondaryContainer: const Color(0xFF4A3400),
      onSecondaryContainer: const Color(0xFFFFE082),
      tertiary: IndustrialColors.industrialGreen,
      surface: IndustrialColors.darkSurface,
      onSurface: const Color(0xFFE8EEF5),
      onSurfaceVariant: const Color(0xFF9FB0C3),
      outline: IndustrialColors.darkBorder,
      outlineVariant: const Color(0xFF1F2D3D),
      error: const Color(0xFFEF5350),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: IndustrialColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: IndustrialColors.darkSurface,
        foregroundColor: Color(0xFFE8EEF5),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: IndustrialColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: IndustrialColors.darkBorder, width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: IndustrialColors.darkSurface,
        indicatorColor: const Color(0xFF004F5A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? IndustrialColors.cyanBright
                : const Color(0xFF9FB0C3),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: IndustrialColors.darkSurfaceElevated,
        selectedColor: const Color(0xFF004F5A),
        side: const BorderSide(color: IndustrialColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IndustrialColors.darkSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IndustrialColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IndustrialColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: IndustrialColors.cyanAccent,
            width: 1.8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: IndustrialColors.darkBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: IndustrialColors.navyPrimary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3E4F8),
      onPrimaryContainer: const Color(0xFF081D33),
      secondary: const Color(0xFFD97706),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFEF3C7),
      onSecondaryContainer: const Color(0xFF451A03),
      tertiary: const Color(0xFF0D9488),
      surface: IndustrialColors.lightSurface,
      onSurface: const Color(0xFF102030),
      onSurfaceVariant: const Color(0xFF4B5E73),
      outline: IndustrialColors.lightBorder,
      outlineVariant: const Color(0xFFE2E8F0),
      error: const Color(0xFFC62828),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: IndustrialColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: IndustrialColors.navyPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: IndustrialColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: IndustrialColors.lightBorder,
            width: 1.2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: IndustrialColors.lightSurface,
        indicatorColor: const Color(0xFFD3E4F8),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? IndustrialColors.navyPrimary
                : const Color(0xFF4B5E73),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IndustrialColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IndustrialColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IndustrialColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: IndustrialColors.navyPrimary,
            width: 1.8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: IndustrialColors.lightBorder,
        thickness: 1,
      ),
    );
  }
}
