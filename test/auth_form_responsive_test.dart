import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/routes/app_router.dart';
import 'package:campushub/module_app/screens/components/auth_form_shell.dart';
import 'package:campushub/module_app/screens/login_screen.dart';
import 'package:campushub/module_app/screens/signup_screen.dart';
import 'package:campushub/module_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openForm(
  WidgetTester tester, {
  required bool signup,
  Size size = const Size(320, 568),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  GlobalKey? captureKey,
  bool followSavedTheme = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
  Widget app() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: followSavedTheme ? Brightness.light : brightness,
    ),
    darkTheme: followSavedTheme ? ThemeData.dark() : null,
    themeMode: followSavedTheme
        ? ThemeService.instance.themeMode
        : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: RepaintBoundary(
      key: captureKey,
      child: signup ? const SignUpScreen() : const LoginScreen(),
    ),
  );
  await tester.pumpWidget(
    followSavedTheme
        ? AnimatedBuilder(
            animation: ThemeService.instance,
            builder: (context, _) => app(),
          )
        : app(),
  );
  await tester.pumpAndSettle();
}

Finder submitButton(bool signup) =>
    find.widgetWithText(FilledButton, signup ? 'Sign Up' : 'Log In');

void main() {
  setUpAll(() async {
    // Measure the actual bundled font, rather than the test framework's Ahem font.
    await (FontLoader('Montserrat')..addFont(
          rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
        ))
        .load();
  });
  for (final signup in [false, true]) {
    final page = signup ? 'signup' : 'login';
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(640, 360),
    ]) {
      for (final brightness in Brightness.values) {
        testWidgets('$page fits $size/$brightness with actual panel overlap', (
          tester,
        ) async {
          await openForm(
            tester,
            signup: signup,
            size: size,
            brightness: brightness,
          );
          final header = tester.getRect(
            find.byKey(Key('$page-header-surface')),
          );
          final panel = tester.getRect(find.byKey(Key('$page-form-surface')));
          expect(panel.top, lessThan(header.bottom));
          expect(panel.top, greaterThan(header.top));
          final logo = find.byKey(Key('$page-logo-circle'));
          final logoRect = tester.getRect(logo);
          final logoDecoration =
              tester.widget<Container>(logo).decoration! as BoxDecoration;
          expect(logoDecoration.shape, BoxShape.circle);
          expect(logoRect.center.dx, closeTo(size.width / 2, 1));
          expect(logoRect.center.dy, closeTo(panel.top, 1));
          expect(logoRect.top, lessThan(panel.top));
          expect(logoRect.bottom, greaterThan(panel.top));
          final heading = tester.getRect(
            find.text(signup ? 'Create Account' : 'Login'),
          );
          expect(heading.center.dx, closeTo(size.width / 2, 1));
          final input = tester.widget<TextField>(find.byType(TextField).first);
          expect(input.style!.fontFamily, 'Montserrat');
          expect(
            tester.getSize(find.byType(TextFormField).first).height,
            inInclusiveRange(52, 56),
          );
          expect(
            input.style!.color,
            brightness == Brightness.light ? AuthFormStyle.navy : Colors.white,
          );
          expect(find.text('CampusHub', findRichText: true), findsNothing);
          expect(AuthFormStyle.gold, const Color(0xFFFCB315));
          final submit = submitButton(signup);
          final style = tester.widget<FilledButton>(submit).style!;
          expect(style.backgroundColor!.resolve({}), AuthFormStyle.gold);
          expect(style.foregroundColor!.resolve({}), AuthFormStyle.navy);
          if (!signup) {
            expect(
              tester
                  .widget<TextButton>(
                    find.byKey(const Key('login-recovery-link')),
                  )
                  .style!
                  .foregroundColor!
                  .resolve({}),
              const Color(0xFFFCB315),
            );
            final remember = tester.getRect(
              find.byKey(const Key('login-remember-control')),
            );
            final recovery = tester.getRect(
              find.byKey(const Key('login-recovery-link')),
            );
            final recoveryText = tester.widget<Text>(
              find.text('Forgot Username or Password?'),
            );
            expect(recoveryText.maxLines, 1);
            expect(recoveryText.softWrap, isFalse);
            if (size.width >= 390) {
              expect(recovery.left, greaterThan(remember.right));
              expect(recovery.center.dy, closeTo(remember.center.dy, 1));
            } else {
              expect(recovery.top, greaterThanOrEqualTo(remember.bottom));
            }
            expect(
              recovery.right,
              closeTo(
                tester.getRect(find.byType(TextFormField).first).right,
                1,
              ),
            );
          }
          if (signup) {
            final fields = find.byType(TextFormField);
            final first = tester.getRect(fields.at(0));
            final last = tester.getRect(fields.at(1));
            final username = tester.getRect(fields.at(2));
            expect(first.top, last.top);
            expect(first.right, lessThan(last.left));
            expect(username.width, greaterThan(first.width * 1.8));
            final checkbox = tester.getRect(
              find.byKey(const Key('signup-terms-checkbox')),
            );
            final agreementFinder = find.byKey(const Key('signup-terms-label'));
            final agreement = tester.getRect(agreementFinder);
            final agreementText = tester.widget<Text>(agreementFinder);
            expect(
              agreementText.textSpan!.toPlainText(),
              'I agree to the Terms and Conditions and Privacy Policy',
            );
            expect(agreementText.maxLines, 1);
            expect(agreementText.softWrap, isFalse);
            expect(agreement.left, greaterThan(checkbox.right - 1));
            expect(agreement.center.dy, closeTo(checkbox.center.dy, 1));
            expect(agreement.right, lessThanOrEqualTo(username.right + 1));
          }
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$page keeps validation and buttons reachable with keyboard/$scale',
        (tester) async {
          await openForm(tester, signup: signup, textScale: scale);
          final headerHeight = tester
              .getSize(find.byKey(Key('$page-header-surface')))
              .height;
          final fields = find.byType(TextFormField);
          await tester.ensureVisible(fields.last);
          await tester.tap(fields.last);
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          tester.view.padding = const FakeViewPadding(top: 24);
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(Key('$page-header-surface'))).height,
            headerHeight,
          );
          final submit = submitButton(signup);
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.getRect(submit).bottom, lessThanOrEqualTo(568 - 280));
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(
            find.text(
              signup ? 'Please enter a password' : 'Please enter your password',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              signup
                  ? 'Please enter a username'
                  : 'Please enter your username or email',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Login to Sign Up and Log In link return without losing input', (
    tester,
  ) async {
    await openForm(tester, signup: false, size: const Size(360, 800));
    final identifier = find.byType(TextFormField).first;
    await tester.enterText(identifier, 'campus_test');
    final link = find.widgetWithText(TextButton, 'Sign Up');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    final loginLink = find.widgetWithText(TextButton, 'Log In');
    await tester.ensureVisible(loginLink);
    await tester.tap(loginLink);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester.widget<TextFormField>(identifier).controller!.text,
      'campus_test',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signup return value still prefills Login identifier', (
    tester,
  ) async {
    await openForm(tester, signup: false);
    final link = find.widgetWithText(TextButton, 'Sign Up');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pop('new_campus_account');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'new_campus_account',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional actual form renders with bundled fonts and photo', (
    tester,
  ) async {
    final output = Platform.environment['AUTH_LAYOUT_CAPTURE_DIR'];
    if (output == null || output.isEmpty) return;
    await tester.runAsync(() async {
      await (FontLoader('Montserrat')..addFont(
            rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    SharedPreferences.setMockInitialValues({});
    for (final signup in [false, true]) {
      for (final brightness in Brightness.values) {
        await ThemeService.instance.setLightMode(
          brightness == Brightness.light,
        );
        final page = '${signup ? 'signup' : 'login'}-${brightness.name}';
        final capture = GlobalKey();
        await openForm(
          tester,
          signup: signup,
          size: const Size(390, 844),
          captureKey: capture,
          brightness: brightness,
        );
        await tester.runAsync(() async {
          final context = capture.currentContext!;
          await precacheImage(const AssetImage('assets/img/bg.png'), context);
          if (!context.mounted) return;
          await precacheImage(
            AssetImage(
              brightness == Brightness.light
                  ? 'assets/img/logo.png'
                  : 'assets/img/logo_dark.png',
            ),
            context,
          );
        });
        await tester.pumpAndSettle();
        Future<void> save(String suffix) => tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(output)..createSync(recursive: true);
          File(
            '${directory.path}/$page-$suffix.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await save('top');
        await tester.ensureVisible(submitButton(signup));
        await tester.pumpAndSettle();
        await save('submit');
        final firstInput = find.byType(TextFormField).first;
        await tester.ensureVisible(firstInput);
        await tester.tap(firstInput);
        await tester.pumpAndSettle();
        await save('focused');
        tester.state<FormState>(find.byType(Form)).validate();
        await tester.pumpAndSettle();
        await tester.ensureVisible(firstInput);
        await tester.pumpAndSettle();
        await save('validation');
        expect(tester.takeException(), isNull);
      }
    }
  });

  for (final signup in [false, true]) {
    final page = signup ? 'signup' : 'login';
    testWidgets(
      '$page theme toggle changes the actual form and saves the choice',
      (tester) async {
        SharedPreferences.setMockInitialValues({'campushub_light_theme': true});
        await ThemeService.instance.load();
        await openForm(
          tester,
          signup: signup,
          size: const Size(390, 844),
          followSavedTheme: true,
        );
        final panel = find.byKey(Key('$page-form-surface'));
        Color? panelColor() =>
            (tester.widget<Container>(panel).decoration! as BoxDecoration)
                .color;
        expect(panelColor(), Colors.white);
        await tester.enterText(find.byType(TextFormField).first, 'Retained');
        await tester.ensureVisible(find.byTooltip('Switch to dark mode'));
        await tester.tap(find.byTooltip('Switch to dark mode'));
        await tester.pumpAndSettle();
        expect(panelColor(), AuthFormStyle.darkSurface);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).style!.color,
          Colors.white,
        );
        expect(find.text('CampusHub', findRichText: true), findsNothing);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getBool('campushub_light_theme'), isFalse);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Retained',
        );

        if (!signup) {
          final signUpLink = find.widgetWithText(TextButton, 'Sign Up');
          await tester.ensureVisible(signUpLink);
          await tester.tap(signUpLink);
          await tester.pumpAndSettle();
          expect(
            (tester
                        .widget<Container>(
                          find.byKey(const Key('signup-form-surface')),
                        )
                        .decoration!
                    as BoxDecoration)
                .color,
            AuthFormStyle.darkSurface,
          );
          final loginLink = find.widgetWithText(TextButton, 'Log In');
          await tester.ensureVisible(loginLink);
          await tester.tap(loginLink);
          await tester.pumpAndSettle();
          expect(panelColor(), AuthFormStyle.darkSurface);
        }

        await tester.ensureVisible(find.byTooltip('Switch to light mode'));
        await tester.tap(find.byTooltip('Switch to light mode'));
        await tester.pumpAndSettle();
        expect(panelColor(), Colors.white);
        expect(
          tester.widget<TextField>(find.byType(TextField).first).style!.color,
          AuthFormStyle.navy,
        );
        expect(preferences.getBool('campushub_light_theme'), isTrue);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Retained',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
