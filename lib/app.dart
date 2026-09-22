import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_colors.dart';
import 'providers/app_providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

class TrackerApp extends ConsumerStatefulWidget {
  const TrackerApp({super.key});
  @override
  ConsumerState<TrackerApp> createState() => _TrackerAppState();
}

class _TrackerAppState extends ConsumerState<TrackerApp> {
  bool _init = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final svc = ref.read(supabaseServiceProvider);
      await svc.init();
      if (mounted) setState(() => _init = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_init) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _darkTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final loggedIn = ref.watch(supabaseServiceProvider).isLoggedIn;
    return MaterialApp(
      title: 'Tracker Sheet',
      debugShowCheckedModeBanner: false,
      theme: _darkTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: loggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}

final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.surface,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  ),
  appBarTheme: const AppBarTheme(
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
  dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
  // Inputs / dropdowns: dark fill + 1px border, accent ring on focus, 8px radius
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder, width: 1)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder, width: 1)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cancelBorder, width: 1)),
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
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  ),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.inputFill),
      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
      side: WidgetStateProperty.all(const BorderSide(color: AppColors.border)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent),
    checkColor: WidgetStateProperty.all(Colors.white),
    overlayColor: WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.12)),
  ),
  iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 18),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
    bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
    titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
  ),
);
