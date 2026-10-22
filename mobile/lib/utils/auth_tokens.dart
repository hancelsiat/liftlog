import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the auth flow (login / register).
///
/// Kept separate from `app_theme.dart` on purpose: the rest of the app still
/// uses the old theme, the auth screens use only what is defined here.
abstract final class AuthColors {
  static const Color bg = Color(0xFF0E0E0D);
  static const Color surface = Color(0xFF161615);
  static const Color surfaceHi = Color(0xFF1E1E1C);
  static const Color line = Color(0xFF2A2A27);
  static const Color textPrimary = Color(0xFFEDEDE8);
  static const Color textMuted = Color(0xFF8D8D86);
  static const Color textFaint = Color(0xFF5A5A55);
  static const Color accent = Color(0xFFD4FF3A);
  static const Color onAccent = Color(0xFF0E0E0D);
  static const Color danger = Color(0xFFFF5A4E);

  /// Corner tone of the vignette. Darker than [bg] but never pure black.
  static const Color vignette = Color(0xFF050504);

  /// Modal barrier: bg tone, mostly opaque.
  static const Color barrier = Color(0xC70E0E0D);
}

abstract final class AuthSpace {
  static const double xs = 8;
  static const double s = 16;
  static const double m = 24;
  static const double l = 32;
  static const double xl = 48;

  static const double side = 24;
  static const double fieldHeight = 52;
  static const double buttonHeight = 56;
  static const double segmentHeight = 48;
  static const double tapTarget = 48;
}

abstract final class AuthRadius {
  static const double field = 10;
  static const double pill = 8;
  static const double dialog = 14;
  static const double thumb = 6;
}

abstract final class AuthMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration route = Duration(milliseconds: 320);

  // Curves
  static const Curve enter = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve standard = Curves.easeOutCubic;

  // Spring
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 30,
  );

  // Entrance choreography (milliseconds on one shared timeline).
  static const int entranceTotalMs = 780;
  static const int topBarMs = 140;
  static const int barbellStartMs = 60;
  static const int barbellMs = 260;
  static const int headlineStartMs = 40;
  static const int headlineStaggerMs = 70;
  static const int riseStartMs = headlineStartMs + 140;
  static const int riseStaggerMs = 45;
  static const double riseDistance = 12;

  // Feedback
  static const Duration shake = Duration(milliseconds: 360);
  static const double shakeAmplitude = 6;
  static const int shakeOscillations = 3;
  static const Duration repHalf = Duration(milliseconds: 450); // 900ms loop
  static const double repDepth = 6;
  static const double lockoutLift = 4;
  static const Duration lockoutHold = Duration(milliseconds: 200);
  static const Duration barbellFail = Duration(milliseconds: 480);
  static const Duration loaderCycle = Duration(milliseconds: 900);
  static const double pressedScale = 0.97;
  static const double revealSlide = 8;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

abstract final class AuthType {
  static TextStyle display(double size) => GoogleFonts.barlowCondensed(
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 0.95,
    color: AuthColors.textPrimary,
  );

  static TextStyle body({
    Color color = AuthColors.textMuted,
    double size = 15,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    color: color,
  );

  static TextStyle input({Color color = AuthColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.25,
        color: color,
      );

  static TextStyle label({Color color = AuthColors.textMuted}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        height: 1.2,
        color: color,
      );

  static TextStyle button({Color color = AuthColors.onAccent}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        height: 1,
        color: color,
      );

  static TextStyle mono({Color color = AuthColors.textMuted}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.2,
        color: color,
      );

  static TextStyle error() => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AuthColors.danger,
  );
}

abstract final class AuthTheme {
  /// Local theme override for the auth subtree, so the global
  /// `AppTheme.darkTheme` input/button styles never leak into these screens.
  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: AuthColors.bg,
      canvasColor: AuthColors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: AuthColors.accent,
        onPrimary: AuthColors.onAccent,
        secondary: AuthColors.textMuted,
        onSecondary: AuthColors.bg,
        surface: AuthColors.surface,
        onSurface: AuthColors.textPrimary,
        error: AuthColors.danger,
        onError: AuthColors.bg,
        outline: AuthColors.line,
      ),
      inputDecorationTheme: const InputDecorationTheme(),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AuthColors.textPrimary,
        selectionColor: AuthColors.textMuted.withValues(alpha: 0.35),
        selectionHandleColor: AuthColors.textMuted,
      ),
      iconTheme: const IconThemeData(color: AuthColors.textMuted, size: 20),
    );
  }
}
