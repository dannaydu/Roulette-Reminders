import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flow State',
      theme: _buildAppTheme(Brightness.light),
      darkTheme: _buildAppTheme(Brightness.dark),
      home: const AuthWrapper(),
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const feltGreen = Color(0xFF0F6B3B);
  const gold = Color(0xFFD6A63A);
  const rouletteRed = Color(0xFFC53A32);
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: feltGreen,
        brightness: brightness,
      ).copyWith(
        primary: feltGreen,
        secondary: gold,
        error: rouletteRed,
        surface: isDark ? const Color(0xFF08140D) : const Color(0xFFF8F2E3),
        primaryContainer: isDark
            ? const Color(0xFF103F27)
            : const Color(0xFFD5E8D7),
        secondaryContainer: isDark
            ? const Color(0xFF564312)
            : const Color(0xFFF0E0B1),
      );
  final cardColor = isDark ? const Color(0xFF0F1E15) : const Color(0xFFFFFBF4);
  final inputFill = isDark ? const Color(0xFF122319) : const Color(0xFFFFFCF6);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: colorScheme.surfaceTint,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? const Color(0xFF15261B)
          : const Color(0xFF173223),
      contentTextStyle: TextStyle(
        color: isDark ? Colors.white : const Color(0xFFF8F2E3),
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(96, 48),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(96, 48),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return cardColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimaryContainer;
          }
          return colorScheme.onSurface;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: colorScheme.secondary.withValues(alpha: 0.28)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.secondary;
        }
        return null;
      }),
      checkColor: WidgetStateProperty.all(colorScheme.onSecondary),
      side: BorderSide(
        color: colorScheme.secondary.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}
