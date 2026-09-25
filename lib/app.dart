import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'config/app_colors.dart';
import 'providers/app_providers.dart';
import 'providers/display_prefs.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

const _appLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  FlutterQuillLocalizations.delegate,
];

class TrackerApp extends ConsumerStatefulWidget {
  const TrackerApp({super.key});
  @override
  ConsumerState<TrackerApp> createState() => _TrackerAppState();
}

/// Lets mouse/trackpad drag-scroll any scrollable (web trackpads and
/// drag-to-scroll horizontally in Weekly), like touch does.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

class _TrackerAppState extends ConsumerState<TrackerApp> {
  bool _init = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final identity = ref.read(identityServiceProvider);
      await identity.init();
      final svc = ref.read(supabaseServiceProvider);
      await svc.init();
      if (mounted) setState(() => _init = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(displayPrefsProvider);
    // Drive the AppColors palette from the theme preference. The home key
    // forces a full subtree rebuild so every AppColors read picks up the
    // new palette (widgets read AppColors directly, not via Theme.of).
    AppColors.lightMode = prefs.lightMode;
    if (!_init) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: prefs.lightMode ? _buildLightTheme() : _buildDarkTheme(),
        localizationsDelegates: _appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    // Watch stream so UI switches instantly after Continue without reload
    final identityAsync = ref.watch(identityStreamProvider);
    final identity = ref.watch(identityServiceProvider);
    final loggedIn = identityAsync.maybeWhen(data: (ident) => ident != null, orElse: () => identity.isLoggedIn);
    ref.watch(supabaseServiceProvider);
    return MaterialApp(
      title: '4cus',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: prefs.lightMode ? ThemeMode.light : ThemeMode.dark,
      scrollBehavior: _AppScrollBehavior(),
      localizationsDelegates: _appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Browser/system language drives all text + dates.
      localeResolutionCallback: (locale, supported) {
        if (locale != null) {
          Intl.defaultLocale = locale.toString();
        }
        if (locale != null) {
          for (final s in supported) {
            if (s.languageCode == locale.languageCode) return s;
          }
        }
        return supported.first;
      },
      home: loggedIn
          ? HomeScreen(key: ValueKey('home-${prefs.lightMode}'))
          : AuthScreen(key: ValueKey('auth-${prefs.lightMode}')),
    );
  }
}

ThemeData _buildDarkTheme() {
  return ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.surface,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.header,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 4,
    shadowColor: Colors.black54,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)), side: BorderSide(color: AppColors.border)),
    elevation: 0,
  ),
  dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
  // Inputs / dropdowns: dark fill + 1px border, accent ring on focus, 8px radius
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    labelStyle: TextStyle(color: AppColors.textSecondary),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.accent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cancelBorder, width: 1)),
    isDense: true,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  ),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.inputFill),
      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
      side: WidgetStateProperty.all(BorderSide(color: AppColors.border)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    side: BorderSide(color: AppColors.inputBorder, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent),
    checkColor: WidgetStateProperty.all(Colors.white),
    overlayColor: WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.12)),
  ),
  iconTheme: IconThemeData(color: AppColors.textSecondary, size: 18),
  textTheme: TextTheme(
    bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
    bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
    titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
  ),
  );
}

ThemeData _buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.header,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 4,
      shadowColor: Colors.black26,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)), side: BorderSide(color: AppColors.border)),
      elevation: 1,
      shadowColor: Colors.black12,
    ),
    dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.inputBorder, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.accent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1)),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.inputFill),
        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
        side: WidgetStateProperty.all(BorderSide(color: AppColors.border)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: AppColors.inputBorder, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      overlayColor: WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.12)),
    ),
    iconTheme: IconThemeData(color: AppColors.textSecondary, size: 18),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    ),
  );
}
