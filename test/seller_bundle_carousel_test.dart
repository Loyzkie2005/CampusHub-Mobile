import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/module_app/widgets/seller/seller_bundle_carousel.dart';
import 'seller_home_layout_test.dart' as layout;

List<Map<String, dynamic>> pairs(
  int count, {
  bool demo = false,
  bool eligible = true,
}) => List.generate(
  count,
  (i) => {
    'id': 'pair-$i',
    'source': demo ? 'synthetic' : 'live',
    'revision': demo ? 'revision-a' : '',
    'can_create': eligible,
    'creation_reason':
        'Demo only: both products need a verified mapping to your approved catalog before creating a bundle.',
    'products': [
      {
        'id': i * 2 + 1,
        'name': 'First catalog product $i with a long name',
        'image_url': '',
      },
      {
        'id': i * 2 + 2,
        'name': 'Second catalog product $i with a long name',
        'image_url': '',
      },
    ],
  },
);

Future<void> pump(
  WidgetTester tester,
  List<Map<String, dynamic>> rows, {
  double width = 390,
  double scale = 1,
  Future<void> Function(Map<String, dynamic>)? dismiss,
  Future<void> Function(Map<String, dynamic>)? create,
  GlobalKey? capture,
}) async {
  await layout.show(
    tester,
    SellerBundleCarousel(
      rows: rows,
      onCreate: create ?? (_) async {},
      onDismiss: dismiss ?? (_) async {},
      emptyState: const Text('No bundle suggestions yet'),
    ),
    width: width,
    scale: scale,
    capture: capture,
  );
}

void main() {
  testWidgets(
    'one card at a time, manual swipe, position and indicator update',
    (tester) async {
      await pump(tester, pairs(4));
      final carousel = find.byKey(const ValueKey('seller-bundle-carousel'));
      final height = tester.getSize(carousel).height;
      expect(find.text('1 of 4'), findsNothing);
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('bundle-indicator-0')))
            .constraints!
            .maxWidth,
        18,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('1 of 4'), findsNothing);
      await tester.drag(carousel, const Offset(-390, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 4'), findsNothing);
      expect(find.text('1 of 4').hitTestable(), findsNothing);
      expect(tester.getSize(carousel).height, height);
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('bundle-indicator-1')))
            .constraints!
            .maxWidth,
        18,
      );
      expect(find.text('View Suggestion'), findsNothing);
      expect(find.text('Support'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Dismiss hides only selected pair, clamps last position, then empty',
    (tester) async {
      final dismissed = <String>[];
      await pump(
        tester,
        pairs(2),
        dismiss: (row) async => dismissed.add('${row['id']}'),
      );
      final carousel = find.byKey(const ValueKey('seller-bundle-carousel'));
      await tester.drag(carousel, const Offset(-390, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Suggestion options').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(dismissed, ['pair-1']);
      expect(find.text('1 of 1'), findsNothing);
      expect(find.byKey(const ValueKey('bundle-indicator-0')), findsNothing);
      await tester.tap(find.byTooltip('Suggestion options').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(dismissed, ['pair-1', 'pair-0']);
      expect(find.text('No bundle suggestions yet'), findsOneWidget);
      expect(find.text('Create Bundle'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed Dismiss keeps its recommendation', (tester) async {
    await pump(
      tester,
      pairs(1),
      dismiss: (_) async => throw Exception('offline'),
    );
    await tester.tap(find.byTooltip('Suggestion options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(
      find.text('First catalog product 0 with a long name'),
      findsOneWidget,
    );
    expect(
      find.text('Unable to dismiss this suggestion. Retry from its menu.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing See All presentation includes every eligible card', (
    tester,
  ) async {
    await layout.show(
      tester,
      SellerBundleCarousel(
        rows: pairs(4),
        carousel: false,
        onCreate: (_) {},
        emptyState: const Text('No bundle suggestions yet'),
      ),
    );
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(FilledButton), findsNWidgets(4));
    expect(find.text('4 of 4'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creation uses selected pair and unmapped demo supports isolated creation',
    (tester) async {
      Map<String, dynamic>? chosen;
      await pump(tester, pairs(1), create: (row) async => chosen = row);
      await tester.tap(find.text('Create Bundle'));
      await tester.pumpAndSettle();
      expect(chosen?['id'], 'pair-0');
      await pump(tester, pairs(1, demo: true, eligible: false));
      expect(find.text('Testing Only'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Create Demo Bundle'), findsOneWidget);
      expect(find.textContaining('verified mapping'), findsNothing);
      expect(find.byKey(const ValueKey('bundle-indicator-0')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [280.0, 320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('demo card stays within viewport at $width / $scale', (
        tester,
      ) async {
        final capture = GlobalKey();
        await layout.reviewFonts(tester);
        await pump(
          tester,
          pairs(4, demo: true, eligible: false),
          width: width,
          scale: scale,
          capture: capture,
        );
        final carousel = find.byKey(const ValueKey('seller-bundle-carousel'));
        expect(tester.getRect(carousel).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(carousel).right, lessThanOrEqualTo(width));
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('Testing Only'))
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        final directory =
            Platform.environment['SELLER_BUNDLE_CAROUSEL_REVIEW_DIR'];
        if (directory != null && width == 390 && scale == 1) {
          for (final eligible in [false, true]) {
            if (eligible) {
              await pump(
                tester,
                pairs(4, demo: true),
                width: width,
                scale: scale,
                capture: capture,
              );
            }
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '$directory/demo-carousel${eligible ? '-eligible' : ''}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      });
    }
  }
}
