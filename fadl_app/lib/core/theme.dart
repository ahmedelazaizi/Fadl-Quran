import 'package:flutter/material.dart';

/// Colors from stitch_ui/fadl_islamic_serenity/DESIGN.md.
abstract final class FadlColors {
  static const primary = Color(0xFF013428);
  static const emerald = Color(0xFF1E4B3E); // primary-container
  static const onEmerald = Color(0xFF8CBAA9);
  static const sage = Color(0xFF176B4D); // secondary
  static const mint = Color(0xFFA4F3CD); // secondary-container
  static const mintSoft = Color(0xFFD5F5E6);
  static const gold = Color(0xFFC7A75C);
  static const goldLight = Color(0xFFE6C687);
  static const goldSoft = Color(0xFFFFF9E6);
  static const parchment = Color(0xFFF1FCF7);
  static const surfaceLow = Color(0xFFEBF6F1);
  static const surfaceContainer = Color(0xFFE5F0EB);
  static const surfaceHigh = Color(0xFFDFEBE6);
  static const text = Color(0xFF141E1B);
  static const textMuted = Color(0xFF404945);
  static const outline = Color(0xFF717975);
  static const outlineVariant = Color(0xFFC0C8C3);
  static const error = Color(0xFFBA1A1A);

  // Dark mode ("ليلي هادئ")
  static const darkCanvas = Color(0xFF0F1B17);
  static const darkSurface = Color(0xFF152822);
  static const darkSurfaceHigh = Color(0xFF1C332B);
  static const darkText = Color(0xFFEAEFEA);
}

/// Font helpers: Tajawal for UI, Amiri Quran for Quran, Amiri for other
/// scripture and decoration, Noto Naskh for headings.
/// The fonts are bundled in assets/fonts so the app works offline.
abstract final class FadlFonts {
  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: 'Tajawal',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => TextStyle(
    fontFamily: 'NotoNaskhArabic',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.5,
  );

  static TextStyle quran({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 2.0,
  }) => TextStyle(
    fontFamily: 'AmiriQuran',
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );

  /// Other scripture and decorative text: generous line height for tashkeel.
  static TextStyle scripture({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 2.0,
  }) => TextStyle(
    fontFamily: 'Amiri',
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? FadlColors.mint : FadlColors.emerald,
    onPrimary: dark ? FadlColors.primary : Colors.white,
    primaryContainer: dark ? FadlColors.darkSurfaceHigh : FadlColors.emerald,
    onPrimaryContainer: dark ? FadlColors.darkText : Colors.white,
    secondary: FadlColors.sage,
    onSecondary: Colors.white,
    secondaryContainer: dark ? const Color(0xFF1F4A3A) : FadlColors.mint,
    onSecondaryContainer: dark ? FadlColors.mint : const Color(0xFF207153),
    tertiary: FadlColors.gold,
    onTertiary: FadlColors.primary,
    error: FadlColors.error,
    onError: Colors.white,
    surface: dark ? FadlColors.darkCanvas : FadlColors.parchment,
    onSurface: dark ? FadlColors.darkText : FadlColors.text,
    onSurfaceVariant: dark ? const Color(0xFFB7C4BE) : FadlColors.textMuted,
    surfaceContainerLowest: dark ? FadlColors.darkSurface : Colors.white,
    surfaceContainerLow: dark ? FadlColors.darkSurface : FadlColors.surfaceLow,
    surfaceContainer: dark
        ? FadlColors.darkSurfaceHigh
        : FadlColors.surfaceContainer,
    surfaceContainerHigh: dark
        ? FadlColors.darkSurfaceHigh
        : FadlColors.surfaceHigh,
    outline: FadlColors.outline,
    outlineVariant: dark ? const Color(0xFF2C443B) : FadlColors.outlineVariant,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Tajawal',
  );
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: FadlFonts.heading(
        size: 20,
        color: dark ? FadlColors.darkText : FadlColors.primary,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: FadlColors.emerald.withValues(alpha: dark ? 0.25 : 0.08),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? FadlColors.sage : FadlColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: FadlFonts.ui(size: 15, weight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      // Explicit per-state colors: unselected labels must stay readable on
      // the light background instead of falling back to faint defaults.
      color: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? FadlColors.sage
            : scheme.surfaceContainerLowest,
      ),
      // RawChip resolves only labelStyle.color against the chip state, so the
      // per-state value must live in the color, not in the TextStyle itself.
      labelStyle: FadlFonts.ui(
        size: 13,
        weight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: FadlFonts.ui(
        size: 13,
        weight: FontWeight.w600,
        color: Colors.white,
      ),
      selectedColor: FadlColors.sage,
      secondarySelectedColor: FadlColors.sage,
      checkmarkColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: dark ? FadlColors.darkSurfaceHigh : FadlColors.mint,
      labelTextStyle: WidgetStatePropertyAll(
        FadlFonts.ui(size: 12, weight: FontWeight.w600),
      ),
      height: 68,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? FadlColors.sage : null,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: FadlColors.emerald.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: FadlColors.emerald.withValues(alpha: 0.12),
        ),
      ),
    ),
  );
}
