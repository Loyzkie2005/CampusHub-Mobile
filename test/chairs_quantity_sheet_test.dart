import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/widgets/facilities/chairs_quantity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capture = GlobalKey();
  final directory = Platform.environment['CHAIRS_REVIEW_DIR'];
  late int confirmed;
  late List<int?> results;

  Future<void> open(
    WidgetTester tester, {
    int initial = 0,
    int cents = 1235,
    int max = chairQuantityLimit,
    double width = 390,
    double scale = 1,
    double keyboard = 0,
  }) async {
    confirmed = initial;
    results = [];
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    if (directory != null) {
      await tester.runAsync(() async {
        for (final font in {
          'Montserrat': 'assets/fonts/Montserrat-VariableFont_wght.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(
            font.key,
          )..addFont(rootBundle.load(font.value))).load();
        }
      });
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    final value = await showChairsQuantitySheet(
                      context: context,
                      currentQuantity: confirmed,
                      unitCentavos: cents,
                      maxQuantity: max,
                    );
                    results.add(value);
                    if (value != null) confirmed = value;
                  },
                  child: const Text('Open quantity'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open quantity'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, String name) async {
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 2);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  final input = find.byKey(const ValueKey('chairs-quantity-input'));
  Finder button(Type type, String text) => find.widgetWithText(type, text);
  int? draft(WidgetTester tester) =>
      int.tryParse(tester.widget<TextField>(input).controller!.text);

  test(
    'rate parsing rejects unknown prices and uses exact integer-centavo totals',
    () {
      expect(chairUnitCentavos('12.35'), 1235);
      expect(chairUnitCentavos('1E+2'), 10000);
      expect(chairUnitCentavos('0.00'), 0);
      for (final value in [
        null,
        '',
        'NaN',
        'Infinity',
        '-1',
        '12.345',
        '0.00000001',
        '100000000',
      ]) {
        expect(chairUnitCentavos(value), isNull);
      }
      expect(chairMoney(1235 * 20), '\u20b1247.00');
      expect(
        chairMoney(9999999999 * chairQuantityLimit),
        '\u20b19999999999000.00',
      );
    },
  );

  testWidgets(
    'compact quantity sheet starts at one and Confirm returns the edited value',
    (tester) async {
      await open(tester, max: 3);
      expect(draft(tester), 1);
      expect(find.text('Remove Chairs'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Estimated chair charge'), findsOneWidget);
      for (final action in [
        button(OutlinedButton, 'Cancel'),
        button(FilledButton, 'Confirm'),
      ]) {
        expect(tester.getSize(action).height, 52);
      }
      final confirmStyle = tester
          .widget<FilledButton>(button(FilledButton, 'Confirm'))
          .style!;
      expect(confirmStyle.shape!.resolve({}), isA<StadiumBorder>());
      expect(
        confirmStyle.backgroundColor!.resolve({}),
        const Color(0xFFFCB316),
      );
      await save(tester, 'chairs-compact-default');
      await tester.enterText(input, '2');
      await tester.pump();
      expect(draft(tester), 2);
      expect(find.text('\u20b124.70'), findsOneWidget);
      await tester.enterText(input, '3');
      await tester.pump();
      expect(draft(tester), 3);
      await tester.enterText(input, '2');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(confirmed, 2);
      expect(results, [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid, zero, negative, fractional and overflowing input cannot confirm',
    (tester) async {
      await open(tester);
      for (final value in [
        '',
        '0',
        '-1',
        '1.5',
        'abc',
        '100001',
        '99999999999999999999',
      ]) {
        await tester.enterText(input, value);
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(button(FilledButton, 'Confirm'))
              .onPressed,
          isNull,
        );
        expect(
          find.text('Enter a whole number from 1 to 100000.'),
          findsOneWidget,
        );
      }
      await tester.enterText(input, '100000');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(button(FilledButton, 'Confirm')).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(confirmed, 100000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancel, Android Back and barrier dismissal preserve the committed quantity; Remove resets it',
    (tester) async {
      await open(tester, initial: 20);
      expect(draft(tester), 20);
      await tester.enterText(input, '99');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(confirmed, 20);
      expect(results.last, isNull);
      await tester.tap(find.text('Open quantity'));
      await tester.pumpAndSettle();
      expect(draft(tester), 20);
      await tester.enterText(input, '8');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(confirmed, 20);
      expect(results.last, isNull);
      await tester.tap(find.text('Open quantity'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 40));
      await tester.pumpAndSettle();
      expect(confirmed, 20);
      expect(results.last, isNull);
      await tester.tap(find.text('Open quantity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove Chairs'));
      await tester.pumpAndSettle();
      expect(confirmed, 0);
      expect(results.last, 0);
      await tester.tap(find.text('Open quantity'));
      await tester.pumpAndSettle();
      expect(draft(tester), 1);
      expect(find.text('Remove Chairs'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale, keyboard) in [
    (390.0, 1.0, 0.0),
    (280.0, 2.0, 300.0),
  ]) {
    testWidgets(
      'quantity sheet scrolls above navigation and keyboard at $width/$scale',
      (tester) async {
        await open(
          tester,
          initial: 20,
          width: width,
          scale: scale,
          keyboard: keyboard,
        );
        final scroll = find.descendant(
          of: find.byKey(const ValueKey('chairs-quantity-scroll')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        final confirm = button(FilledButton, 'Confirm');
        await tester.ensureVisible(input);
        await tester.enterText(input, '8');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(confirm, 160, scrollable: scroll);
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(confirm).bottom,
          lessThanOrEqualTo(844 - keyboard),
        );
        expect(tester.takeException(), isNull);
        await save(tester, 'chairs-$width-$scale');
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(confirmed, 8);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
