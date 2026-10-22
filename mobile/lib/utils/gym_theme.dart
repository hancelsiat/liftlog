import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_tokens.dart';

/// Extra colours for the in-app (post-login) screens. Everything else comes
/// from [AuthColors] so login, signup and the app share one palette.
abstract final class GymColors {
  static const Color warn = Color(0xFFFFB547);
}

/// Theme for the restyled in-app screens.
///
/// Builds on [AuthTheme] and also styles the stock Material widgets
/// (Card, TextFormField, buttons, TabBar, SnackBar, AlertDialog) so widgets
/// that were not rewritten still match the new look.
abstract final class GymTheme {
  static ThemeData of(BuildContext context) {
    final base = AuthTheme.of(context);
    final radius = BorderRadius.circular(AuthRadius.field);

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AuthColors.textPrimary,
        displayColor: AuthColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AuthColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuthRadius.dialog),
          side: const BorderSide(color: AuthColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AuthColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuthColors.surfaceHi,
        labelStyle: AuthType.body(size: 14),
        floatingLabelStyle: AuthType.label(color: AuthColors.textPrimary),
        hintStyle: AuthType.body(color: AuthColors.textFaint),
        prefixIconColor: AuthColors.textMuted,
        errorStyle: AuthType.error(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuthSpace.s,
          vertical: 16,
        ),
        border: outline(AuthColors.line),
        enabledBorder: outline(AuthColors.line),
        disabledBorder: outline(AuthColors.line.withValues(alpha: 0.5)),
        focusedBorder: outline(AuthColors.accent, 1.5),
        errorBorder: outline(AuthColors.danger.withValues(alpha: 0.6)),
        focusedErrorBorder: outline(AuthColors.danger, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.accent,
          foregroundColor: AuthColors.onAccent,
          disabledBackgroundColor: AuthColors.surfaceHi,
          disabledForegroundColor: AuthColors.textFaint,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: AuthType.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AuthColors.textPrimary,
          side: const BorderSide(color: AuthColors.line),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: AuthType.button(color: AuthColors.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuthColors.accent,
          textStyle: AuthType.button(color: AuthColors.accent),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AuthColors.accent,
        linearTrackColor: AuthColors.line,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AuthColors.surfaceHi,
        contentTextStyle: AuthType.body(
          color: AuthColors.textPrimary,
          size: 14,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AuthColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AuthColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuthRadius.dialog),
          side: const BorderSide(color: AuthColors.line),
        ),
        titleTextStyle: AuthType.display(26),
        contentTextStyle: AuthType.body(),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AuthColors.textPrimary,
        unselectedLabelColor: AuthColors.textMuted,
        labelStyle: AuthType.label(color: AuthColors.textPrimary),
        unselectedLabelStyle: AuthType.label(),
        indicatorColor: AuthColors.accent,
        dividerColor: AuthColors.line,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AuthColors.textPrimary,
        iconColor: AuthColors.textMuted,
      ),
    );
  }
}
