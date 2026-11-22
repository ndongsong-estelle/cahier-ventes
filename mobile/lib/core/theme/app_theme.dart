import 'package:material_ui/material_ui.dart';

/// Couleurs du cahier : vert = reçu, rouge = on vous doit, orange = une partie.
abstract final class AppColors {
  static const green = Color(0xFF1B873F);
  static const red = Color(0xFFC62828);
  static const orange = Color(0xFFE37400);
  // Orange plus foncé pour du texte sur fond clair (contraste AA).
  static const orangeText = Color(0xFFA35300);
  static const background = Color(0xFFFAFAF7);
  static const text = Color(0xFF1C1C1C);
  static const muted = Color(0xFF555555);
}

abstract final class AppSizes {
  static const bodyText = 18.0;
  static const amountSmall = 32.0;
  static const amountLarge = 56.0;
  static const mainButtonHeight = 64.0;
  static const animation = Duration(milliseconds: 150);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.green,
    error: AppColors.red,
    surface: AppColors.background,
  );
  const textTheme = TextTheme(
    bodyLarge: TextStyle(fontSize: 20, color: AppColors.text),
    bodyMedium: TextStyle(fontSize: AppSizes.bodyText, color: AppColors.text),
    bodySmall: TextStyle(fontSize: AppSizes.bodyText, color: AppColors.muted),
    titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(
      fontSize: AppSizes.amountSmall,
      fontWeight: FontWeight.w800,
    ),
    displaySmall: TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
  );
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppSizes.mainButtonHeight),
        textStyle: textTheme.labelLarge,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, AppSizes.mainButtonHeight),
        textStyle: textTheme.labelLarge,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      labelStyle: TextStyle(fontSize: AppSizes.bodyText),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
