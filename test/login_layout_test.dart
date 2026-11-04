import 'package:campushub/module_app/screens/login_screen.dart';
import 'package:campushub/module_app/screens/components/auth_form_shell.dart';
import 'package:campushub/module_app/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(360, 640), const Size(412, 915)]) {
      testWidgets(
        'login renders campus photo and selected-theme rounded panel at $size in $brightness',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const LoginScreen(),
            ),
          );

          final surface = find.byKey(const Key('login-form-surface'));
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          final header = tester.widget<Container>(
            find.byKey(const Key('login-header-surface')),
          );
          final decoration =
              tester.widget<Container>(surface).decoration! as BoxDecoration;
          const navyBackground = Color(0xFF1A1851);
          final expectedCardColor = brightness == Brightness.light
              ? Colors.white
              : AuthFormStyle.darkSurface;

          // Campus-photo fallback is navy; the form/scaffold are white.
          expect(scaffold.backgroundColor, expectedCardColor);
          expect(header.color, navyBackground);

          // 2nd container is white card with rounded top corners
          expect(decoration.color, expectedCardColor);
          expect(
            decoration.borderRadius,
            const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          );

          // The original bundled CampusHub logo is retained on the white panel.
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      (brightness == Brightness.light
                          ? 'assets/img/logo.png'
                          : 'assets/img/logo_dark.png'),
            ),
            findsOneWidget,
          );

          // Form outline and labeled fields
          final outline = find.byKey(const Key('login-form-outline'));
          expect(
            find.descendant(
              of: outline,
              matching: find.text('CampusHub', findRichText: true),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: outline, matching: find.text('Login')),
            findsOneWidget,
          );
          expect(find.text('Username or Email'), findsOneWidget);
          expect(find.text('Password'), findsOneWidget);
          expect(find.text('Sign Up'), findsOneWidget);

          // Shared outlined inputs retain a fixed floating label.
          final inputField = tester.widget<TextField>(
            find.byType(TextField).first,
          );
          final inputBorder =
              inputField.decoration?.border as OutlineInputBorder?;
          expect(inputBorder?.borderRadius, BorderRadius.circular(50));
          expect(
            inputField.decoration?.floatingLabelBehavior,
            FloatingLabelBehavior.always,
          );

          // Login button
          final loginButton = find.widgetWithText(FilledButton, 'Log In');
          await tester.ensureVisible(loginButton);
          await tester.pumpAndSettle();
          expect(loginButton.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final brightness in Brightness.values) {
    for (final size in [const Size(360, 640), const Size(412, 915)]) {
      testWidgets(
        'signup renders campus photo and selected-theme rounded panel at $size in $brightness',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const SignUpScreen(),
            ),
          );

          final surface = find.byKey(const Key('signup-form-surface'));
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          final header = tester.widget<Container>(
            find.byKey(const Key('signup-header-surface')),
          );
          final decoration =
              tester.widget<Container>(surface).decoration! as BoxDecoration;
          const navyBackground = Color(0xFF1A1851);
          final expectedCardColor = brightness == Brightness.light
              ? Colors.white
              : AuthFormStyle.darkSurface;

          // Campus-photo fallback is navy; the form/scaffold are white.
          expect(scaffold.backgroundColor, expectedCardColor);
          expect(header.color, navyBackground);

          // 2nd container is white card with rounded top corners
          expect(decoration.color, expectedCardColor);
          expect(
            decoration.borderRadius,
            const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          );

          // Original CampusHub logo remains above the form fields.
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      (brightness == Brightness.light
                          ? 'assets/img/logo.png'
                          : 'assets/img/logo_dark.png'),
            ),
            findsOneWidget,
          );

          final outline = find.byKey(const Key('signup-form-outline'));
          expect(
            find.descendant(
              of: outline,
              matching: find.text('CampusHub', findRichText: true),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: outline, matching: find.text('Create Account')),
            findsOneWidget,
          );
          expect(find.text('First Name'), findsWidgets);
          expect(find.text('Last Name'), findsWidgets);
          expect(find.text('Username'), findsOneWidget);
          expect(find.text('Email'), findsOneWidget);
          expect(find.text('Password'), findsOneWidget);
          expect(find.text('Confirm Password'), findsOneWidget);
          expect(find.text('Log In'), findsOneWidget);

          // Shared outlined inputs retain a fixed floating label.
          final inputField = tester.widget<TextField>(
            find.byType(TextField).first,
          );
          final inputBorder =
              inputField.decoration?.border as OutlineInputBorder?;
          expect(inputBorder?.borderRadius, BorderRadius.circular(50));
          expect(
            inputField.decoration?.floatingLabelBehavior,
            FloatingLabelBehavior.always,
          );

          // Sign Up button
          final signUpButton = find.widgetWithText(FilledButton, 'Sign Up');
          await tester.ensureVisible(signUpButton);
          await tester.pumpAndSettle();
          expect(signUpButton.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'login inline error message renders text without error_outline icon',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'invalid_user');
      await tester.enterText(fields.last, 'wrong_password');

      final loginButton = find.widgetWithText(FilledButton, 'Log In');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.style?.color == const Color(0xFFEF4444) &&
              (widget.data?.isNotEmpty ?? false),
        ),
        findsOneWidget,
      );
    },
  );
}
