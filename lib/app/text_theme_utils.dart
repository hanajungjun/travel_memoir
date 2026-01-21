import 'package:flutter/material.dart';

TextTheme applyLetterSpacing(TextTheme base, double spacing) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(letterSpacing: spacing),
    displayMedium: base.displayMedium?.copyWith(letterSpacing: spacing),
    displaySmall: base.displaySmall?.copyWith(letterSpacing: spacing),

    headlineLarge: base.headlineLarge?.copyWith(letterSpacing: spacing),
    headlineMedium: base.headlineMedium?.copyWith(letterSpacing: spacing),
    headlineSmall: base.headlineSmall?.copyWith(letterSpacing: spacing),

    titleLarge: base.titleLarge?.copyWith(letterSpacing: spacing),
    titleMedium: base.titleMedium?.copyWith(letterSpacing: spacing),
    titleSmall: base.titleSmall?.copyWith(letterSpacing: spacing),

    bodyLarge: base.bodyLarge?.copyWith(letterSpacing: spacing),
    bodyMedium: base.bodyMedium?.copyWith(letterSpacing: spacing),
    bodySmall: base.bodySmall?.copyWith(letterSpacing: spacing),

    labelLarge: base.labelLarge?.copyWith(letterSpacing: spacing),
    labelMedium: base.labelMedium?.copyWith(letterSpacing: spacing),
    labelSmall: base.labelSmall?.copyWith(letterSpacing: spacing),
  );
}
