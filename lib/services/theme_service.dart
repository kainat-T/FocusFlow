import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App Theme Model
// ─────────────────────────────────────────────────────────────────────────────
class AppThemeData {
  final String id;
  final String name;
  final String description;
  final Color bg;
  final Color surface;
  final Color border;
  final Color text;
  final Color subText;
  final Color accent;
  final Color drawerBg;
  final Color navBg;
  final Color divider;
  final bool isDark;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.description,
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.subText,
    required this.accent,
    required this.drawerBg,
    required this.navBg,
    required this.divider,
    required this.isDark,
  });

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: accent,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      dividerColor: divider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Curated Themes
// ─────────────────────────────────────────────────────────────────────────────
class AppThemes {
  static const deepAmethyst = AppThemeData(
    id: 'deep_amethyst',
    name: 'Deep Amethyst',
    description: 'Mystic obsidian with soft lavender',
    bg: Color(0xFF110D1B),
    surface: Color(0xFF1C162E),
    border: Color(0xFF2C2245),
    text: Color(0xFFFAF5FF),
    subText: Color(0xFFA59ABF),
    accent: Color(0xFFA78BFA),
    drawerBg: Color(0xFF151022),
    navBg: Color(0xFF0D0A15),
    divider: Color(0xFF241B3B),
    isDark: true,
  );

  static const lightLavender = AppThemeData(
    id: 'light_lavender',
    name: 'Light Lavender',
    description: 'Soft lavender with warm purple accents',
    bg: Color(0xFFF3F0FF),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE8E0F8),
    text: Color(0xFF2D1B4E),
    subText: Color(0xFF7C6A9A),
    accent: Color(0xFF8B7ED8),
    drawerBg: Color(0xFFFFFFFF),
    navBg: Color(0xFFFFFFFF),
    divider: Color(0xFFE8E0F8),
    isDark: false,
  );

  static const List<AppThemeData> all = [
    deepAmethyst,
    lightLavender,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Service (Singleton + ChangeNotifier)
// ─────────────────────────────────────────────────────────────────────────────
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _kPrefKey = 'user_selected_app_theme';

  AppThemeData _currentTheme = AppThemes.deepAmethyst;
  AppThemeData get currentTheme => _currentTheme;

  List<AppThemeData> get availableThemes => AppThemes.all;

  /// Loads saved theme preference from local storage.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kPrefKey);
      if (savedId != null) {
        final found = AppThemes.all.firstWhere(
          (t) => t.id == savedId,
          orElse: () => AppThemes.deepAmethyst,
        );
        _currentTheme = found;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Changes the theme and persists the choice.
  Future<void> setTheme(AppThemeData theme) async {
    if (_currentTheme.id == theme.id) return;
    _currentTheme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, theme.id);
    } catch (_) {}
  }
}
