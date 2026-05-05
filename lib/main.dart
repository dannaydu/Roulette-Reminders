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
      title: 'Roulette Reminders',
      theme: _buildAppTheme(),
      darkTheme: _buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

ThemeData _buildAppTheme() {
  const midnightBlack = Color(0xFF08080A);
  const velvetBlack = Color(0xFF111115);
  const slateBlack = Color(0xFF18181D);
  const iron = Color(0xFF23232A);
  const rouletteRed = Color(0xFFC52D2F);
  const crimson = Color(0xFF8E1B22);
  const wine = Color(0xFF4A1115);
  const ivory = Color(0xFFF5EDE3);
  const ash = Color(0xFFB8ADA1);
  final baseTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
  );
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: rouletteRed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: crimson,
        secondary: rouletteRed,
        tertiary: ash,
        error: rouletteRed,
        surface: midnightBlack,
        onSurface: ivory,
        onPrimary: ivory,
        onSecondary: ivory,
        onSurfaceVariant: ash,
        primaryContainer: wine,
        onPrimaryContainer: ivory,
        secondaryContainer: const Color(0xFF331216),
        onSecondaryContainer: ivory,
        surfaceContainerLowest: velvetBlack,
        surfaceContainerLow: slateBlack,
        surfaceContainerHigh: iron,
        outlineVariant: const Color(0xFF4B2C31),
      );
  final cardColor = velvetBlack;
  final inputFill = slateBlack;
  final textTheme = baseTheme.textTheme.copyWith(
    headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
    ),
    headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    ),
    headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
    titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
    titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
      letterSpacing: 0.15,
    ),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: cardColor,
    textTheme: textTheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: midnightBlack,
      foregroundColor: ivory,
      elevation: 0,
      toolbarHeight: 72,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: ivory,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
      iconTheme: IconThemeData(
        color: rouletteRed,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A0E10),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: TextStyle(
        color: ivory,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.26),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: rouletteRed,
        backgroundColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
        minimumSize: const Size(42, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.28),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.26),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.88),
          width: 1.8,
        ),
      ),
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      ),
      prefixIconColor: colorScheme.secondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(96, 48),
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        elevation: 0,
        textStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(96, 48),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.7),
        ),
        foregroundColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.24),
        ),
      ),
    ),
    chipTheme: baseTheme.chipTheme.copyWith(
      side: BorderSide(
        color: colorScheme.secondary.withValues(alpha: 0.3),
      ),
      selectedColor: colorScheme.secondaryContainer,
      backgroundColor: colorScheme.surfaceContainerLow,
      labelStyle: textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.secondaryContainer;
          }
          return cardColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onSecondaryContainer;
          }
          return colorScheme.onSurface;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: colorScheme.secondary.withValues(alpha: 0.32)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.secondary,
      linearTrackColor: colorScheme.surfaceContainerHigh,
      circularTrackColor: colorScheme.surfaceContainerHigh,
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.secondary,
      textColor: colorScheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
  );
}
