import 'package:material_ui/material_ui.dart';

abstract final class SpendSpace {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const extraLarge = 32.0;
}

abstract final class SpendColors {
  static const ink = Color(0xFF16342C);
  static const mint = Color(0xFFD9F4A1);
  static const forest = Color(0xFF235D47);
  static const canvas = Color(0xFFF4F6F0);
}

abstract final class SpendTheme {
  static ThemeData build(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: SpendColors.forest,
      brightness: brightness,
      contrastLevel: highContrast ? 1 : 0,
    ).copyWith(surface: dark ? const Color(0xFF14211C) : Colors.white);
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0E1814)
          : SpendColors.canvas,
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
