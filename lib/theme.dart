import 'package:material_ui/material_ui.dart';

const uiFont = 'Segoe UI';
const uiFallbackFont = 'Heebo';
const textFont = 'FrankRuhlLibre';

/// Colors of the desktop chrome and the reading page.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.window,
    required this.panel,
    required this.panelAlt,
    required this.page,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.gold,
    required this.activity,
    required this.onActivity,
    required this.mark,
    required this.selection,
    required this.note,
    required this.noteBorder,
    required this.noteInk,
    required this.dark,
  });

  final Color window, panel, panelAlt, page, border, ink, muted, accent, gold, activity, onActivity, mark, selection;
  final Color note, noteBorder, noteInk; // personal notes
  final bool dark;

  static const light = Palette(
    window: Color(0xFFEDEAE3),
    panel: Color(0xFFF7F5F0),
    panelAlt: Color(0xFFEFEBE3),
    page: Color(0xFFFFFDF8),
    border: Color(0xFFD9D2C5),
    ink: Color(0xFF2A241D),
    muted: Color(0xFF7A6F62),
    accent: Color(0xFF1F3A63),
    gold: Color(0xFFB08B3A),
    activity: Color(0xFF1C2B47),
    onActivity: Color(0xFFE9E4D8),
    mark: Color(0x80F2CF6B),
    selection: Color(0xFFE6DDCB),
    note: Color(0xFFFFF4CF),
    noteBorder: Color(0xFFE0BE5C),
    noteInk: Color(0xFF4A3B12),
    dark: false,
  );

  static const darkPalette = Palette(
    window: Color(0xFF16181D),
    panel: Color(0xFF1D2026),
    panelAlt: Color(0xFF23262D),
    page: Color(0xFF202329),
    border: Color(0xFF30343C),
    ink: Color(0xFFE4DFD3),
    muted: Color(0xFF959086),
    accent: Color(0xFFD6B46A),
    gold: Color(0xFFD6B46A),
    activity: Color(0xFF111318),
    onActivity: Color(0xFFCFC9BC),
    mark: Color(0x66D6B46A),
    selection: Color(0xFF2E323A),
    note: Color(0xFF2E2919),
    noteBorder: Color(0xFF8F7637),
    noteInk: Color(0xFFE9D9A8),
    dark: true,
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.darkPalette : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F3A63), brightness: b).copyWith(
    primary: p.accent,
    onPrimary: p.dark ? const Color(0xFF1A1407) : Colors.white,
    secondary: p.gold,
    surface: p.panel,
    onSurface: p.ink,
    outline: p.border,
    outlineVariant: p.border,
    surfaceContainerHighest: p.panelAlt,
    surfaceContainerHigh: p.panelAlt,
    surfaceContainer: p.panel,
    surfaceContainerLow: p.panel,
    secondaryContainer: p.selection,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    fontFamily: uiFont,
    // Segoe UI is a Windows font; elsewhere (the web, Mac, Linux) the bundled Heebo is used.
    fontFamilyFallback: const [uiFallbackFont],
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: p.window,
    canvasColor: p.panel,
    dividerColor: p.border,
    splashFactory: NoSplash.splashFactory,
    hoverColor: p.ink.withValues(alpha: 0.05),
    extensions: [p],
  );
  final radius = BorderRadius.circular(4);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: uiFont),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(4),
      thumbColor: WidgetStatePropertyAll(p.muted.withValues(alpha: 0.45)),
      crossAxisMargin: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.page,
      hintStyle: TextStyle(color: p.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border)),
      textStyle: TextStyle(fontFamily: uiFont, fontSize: 13, color: p.ink),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.panel),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.border))),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(color: p.activity, borderRadius: radius),
      textStyle: TextStyle(fontFamily: uiFont, color: p.onActivity, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 360,
      backgroundColor: p.activity,
      contentTextStyle: TextStyle(fontFamily: uiFont, color: p.onActivity),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.accent, thumbColor: p.accent, inactiveTrackColor: p.border),
    listTileTheme: ListTileThemeData(dense: true, iconColor: p.muted, selectedColor: p.accent, selectedTileColor: p.selection),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : null),
    ),
  );
}

IconData categoryIcon(String category) => switch (category) {
      'אמונה' => Icons.wb_sunny_outlined,
      'קבצים ופנקסים' => Icons.edit_note,
      'מוסר ומידות' => Icons.spa_outlined,
      'תפילה ומועדים' => Icons.local_fire_department_outlined,
      'דרשות ומאמרים' => Icons.record_voice_over_outlined,
      'אגרות' => Icons.mail_outline,
      'שירה' => Icons.music_note_outlined,
      'הלכה' => Icons.gavel_outlined,
      _ => Icons.book_outlined,
    };
