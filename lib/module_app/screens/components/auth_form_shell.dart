import 'package:campushub/module_app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_theme_toggle.dart';

/// Presentation shared only by Login and Sign Up; authentication stays in each screen.
abstract final class AuthFormStyle {
  static const navy = Color(0xFF1A1851);
  static const gold = Color(0xFFFCB315);
  static const surface = Colors.white;
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE8EAF0);
  static const fieldSurface = Color(0xFFF9FAFB);
  static const darkSurface = Color(0xFF16153B);
  static const darkFieldSurface = Color(0xFF242347);
  static const darkMuted = Color(0xFFC5C5D6);
  static const darkBorder = Color(0xFF48475E);
  static const fontFamily = AppTypography.family;

  static TextStyle text({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = navy,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
  );

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
    backgroundColor: gold,
    foregroundColor: navy,
    disabledBackgroundColor: gold.withValues(alpha: 0.5),
    disabledForegroundColor: navy.withValues(alpha: 0.65),
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: AppTypography.button.copyWith(fontSize: 15),
    elevation: 0,
  );

  static ButtonStyle linkButton(BuildContext context, {Color? color}) =>
      TextButton.styleFrom(
        foregroundColor: color ?? Theme.of(context).colorScheme.onSurface,
        textStyle: text(size: 13, weight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        minimumSize: const Size(48, 48),
      );

  static ThemeData theme(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final colors =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: isDark ? gold : navy,
              onPrimary: isDark ? navy : Colors.white,
              secondary: gold,
              onSecondary: navy,
              surface: isDark ? darkSurface : surface,
              onSurface: isDark ? Colors.white : navy,
              onSurfaceVariant: isDark ? darkMuted : muted,
              outline: isDark ? darkBorder : border,
              surfaceContainerHighest: isDark ? darkFieldSurface : fieldSurface,
            );
    return base.copyWith(
      colorScheme: colors,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily),
      scaffoldBackgroundColor: colors.surface,
    );
  }
}

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.page,
    required this.child,
    this.onBack,
  });

  final String page;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    // The full view height keeps the photo stable when the keyboard resizes Scaffold.
    final photoHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(
      180.0,
      248.0,
    );
    const overlap = 28.0;
    final panelTop = photoHeight - overlap;
    final formTheme = AuthFormStyle.theme(Theme.of(context));
    final colors = formTheme.colorScheme;
    final isDark = formTheme.brightness == Brightness.dark;

    return Theme(
      data: formTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: colors.surface,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: colors.surface,
          body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: Key('$page-form-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: photoHeight,
                    child: Container(
                      key: Key('$page-header-surface'),
                      color: AuthFormStyle.navy,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset('assets/img/bg.png', fit: BoxFit.cover),
                          ColoredBox(
                            color: AuthFormStyle.navy.withValues(alpha: 0.12),
                          ),
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (onBack != null)
                                    IconButton(
                                      tooltip: 'Back to login',
                                      onPressed: onBack,
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 20,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AuthFormStyle.surface,
                                        foregroundColor: AuthFormStyle.navy,
                                      ),
                                    ),
                                  const Spacer(),
                                  const AuthThemeToggle(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: panelTop),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          key: Key('$page-form-surface'),
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - panelTop).clamp(
                              0.0,
                              double.infinity,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            minimum: const EdgeInsets.only(bottom: 24),
                            child: Padding(
                              key: Key('$page-form-outline'),
                              padding: const EdgeInsets.fromLTRB(24, 56, 24, 8),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -36,
                          child: Container(
                            key: Key('$page-logo-circle'),
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.outline,
                                width: 2,
                              ),
                            ),
                            child: Image.asset(
                              isDark
                                  ? 'assets/img/logo_dark.png'
                                  : 'assets/img/logo.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'CampusHub logo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthFormHeading extends StatelessWidget {
  const AuthFormHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: AuthFormStyle.text(
            size: 24,
            weight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AuthFormStyle.text(
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}

class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.supporting,
    this.serverError,
    this.hintText,
    this.onChanged,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? supporting;
  final String? serverError;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outline = Color.alphaBlend(
      colors.onSurfaceVariant.withValues(alpha: 0.6),
      colors.surface,
    );
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: color, width: width),
          gapPadding: 6,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            obscureText: obscure,
            autocorrect: !obscure,
            enableSuggestions: !obscure,
            onChanged: onChanged,
            validator: validator,
            style: AppTypography.input.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            cursorColor: Theme.of(context).colorScheme.primary,
            scrollPadding: const EdgeInsets.all(24),
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: AppTypography.fieldLabel.copyWith(
                color: colors.onSurface,
              ),
              floatingLabelStyle: WidgetStateTextStyle.resolveWith(
                (states) => AppTypography.fieldLabel.copyWith(
                  color: states.contains(WidgetState.error)
                      ? colors.error
                      : colors.onSurface,
                ),
              ),
              constraints: const BoxConstraints(minHeight: 50),
              hintText: hintText ?? 'Enter your $label',
              hintStyle: AppTypography.placeholder.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              errorText: serverError,
              errorMaxLines: 3,
              errorStyle: AppTypography.error
                  .copyWith(color: colors.error)
                  .copyWith(height: 1.35),
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: icon == null
                  ? null
                  : Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: onToggleObscure == null
                  ? null
                  : IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
              border: border(outline),
              enabledBorder: border(outline),
              focusedBorder: border(AuthFormStyle.gold, width: 2),
              disabledBorder: border(colors.outline),
              errorBorder: border(colors.error),
              focusedErrorBorder: border(colors.error, width: 2),
            ),
          ),
          if (supporting != null) ...[const SizedBox(height: 6), supporting!],
        ],
      ),
    );
  }
}
