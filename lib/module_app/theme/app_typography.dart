import 'package:flutter/material.dart';

/// Compatibility helper for existing Home/navigation callers.
abstract final class InterTypography {
  static const family = AppTypography.family;

  static TextStyle text({
    Color? color,
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontVariations: [FontVariation('wght', fontWeight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle sized(
    double size, {
    int weight = 400,
    Color color = const Color(0xFF1A1851),
  }) => text(
    fontSize: size,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    color: color,
    height: 1.45,
  );

  static ThemeData theme(ThemeData base) => base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(sized(13, weight: 500)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(sized(13, weight: 500)),
      ),
    ),
  );
}

/// Bundled UI fonts: no network request or Google Fonts cache is required.
abstract final class AppTypography {
  static const family = 'Inter';

  static const screenHeader = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  static const fieldLabel = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const input = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  static const helper = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
  static const placeholder = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static const progress = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const tooltip = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const error = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static TextStyle text({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: family,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextTheme textTheme(TextTheme base) {
    final inter = base.apply(fontFamily: family);
    // Merge roles so existing light/dark foreground colors remain intact.
    return inter.copyWith(
      titleLarge: inter.titleLarge?.merge(screenHeader),
      titleMedium: inter.titleMedium?.merge(cardTitle.copyWith(fontSize: 16)),
      titleSmall: inter.titleSmall?.merge(cardTitle),
      bodyLarge: inter.bodyLarge?.merge(input),
      bodyMedium: inter.bodyMedium?.merge(input.copyWith(fontSize: 14)),
      bodySmall: inter.bodySmall?.merge(helper),
      labelLarge: inter.labelLarge?.merge(button),
      labelMedium: inter.labelMedium?.merge(fieldLabel),
      labelSmall: inter.labelSmall?.merge(progress),
    );
  }

  /// Changes typography only; component colors, padding and shape stay local.
  static ThemeData theme(ThemeData base) {
    ButtonStyle buttonStyle(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          textStyle: const WidgetStatePropertyAll(button),
        );
    return base.copyWith(
      textTheme: textTheme(base.textTheme),
      primaryTextTheme: textTheme(base.primaryTextTheme),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: (base.appBarTheme.titleTextStyle ?? const TextStyle())
            .merge(screenHeader),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: (base.inputDecorationTheme.labelStyle ?? const TextStyle())
            .merge(fieldLabel),
        hintStyle: (base.inputDecorationTheme.hintStyle ?? const TextStyle())
            .merge(placeholder),
        helperStyle:
            (base.inputDecorationTheme.helperStyle ?? const TextStyle()).merge(
              helper,
            ),
        errorStyle: (base.inputDecorationTheme.errorStyle ?? const TextStyle())
            .merge(error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle(base.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle(base.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle(base.textButtonTheme.style),
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        textStyle:
            (base.tooltipTheme.textStyle ??
                    TextStyle(color: base.colorScheme.onInverseSurface))
                .merge(tooltip),
      ),
    );
  }
}
