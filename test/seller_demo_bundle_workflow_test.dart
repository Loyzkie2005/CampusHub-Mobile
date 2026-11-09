import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/services/demo_bundle_store.dart';
import 'package:campushub/module_app/screens/seller_demo_bundle_page.dart';
import 'package:campushub/module_app/theme/marketplace_colors.dart';
import 'package:campushub/module_app/widgets/seller/product_inventory_fields.dart';
import 'package:lottie/lottie.dart';
import 'seller_home_layout_test.dart' as layout;

Map<String, dynamic> demoPair() => {
  'id': 'S01:P01|S01:P02',
  'source': 'synthetic',
  'revision': 'dataset-hash:thresholds',
  'synthetic_seller_id': 'S01',
  'can_create': false,
  'products': [
    {'id': 'S01:P01', 'source_id': 'S01:P01', 'name': 'Demo Noodles'},
    {'id': 'S01:P02', 'source_id': 'S01:P02', 'name': 'Demo Egg'},
  ],
};

class FailingStore extends DemoBundleStore {
  const FailingStore() : super(1);
  @override
  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> pair,
    required String name,
    required List<int> quantities,
    required String price,
    bool editing = false,
  }) async => throw StateError('disk unavailable');
}

class DelayedStore extends DemoBundleStore {
  DelayedStore() : super(1);
  final gate = Completer<void>();
  int saves = 0;
  @override
  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> pair,
    required String name,
    required List<int> quantities,
    required String price,
    bool editing = false,
  }) async {
    saves++;
    await gate.future;
    return super.save(
      pair: pair,
      name: name,
      quantities: quantities,
      price: price,
      editing: editing,
    );
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  final base = find.text(text);
  if (base.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      base,
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  final finder = base.last;
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester, {
  DemoBundleStore store = const DemoBundleStore(1),
  Map<String, dynamic>? saved,
  double width = 390,
  double scale = 1,
  bool reducedMotion = false,
}) async {
  await tester.runAsync(
    () => AssetLottie(
      'assets/animations/check.lottie',
      decoder: decodeBundleCheck,
    ).load(),
  );
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerDemoBundlePage(
                  pair: demoPair(),
                  store: store,
                  saved: saved,
                ),
              ),
            ),
            child: const Text('Suggestions'),
          ),
        ),
      ),
    ),
  );
  await tap(tester, 'Suggestions');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'local create is idempotent, seller scoped, durable and retains provenance',
    () async {
      const store = DemoBundleStore(1);
      final pair = demoPair();
      final saved = await Future.wait(
        List.generate(
          3,
          (_) => store.save(
            pair: pair,
            name: 'Lunch',
            quantities: [2, 1],
            price: '50',
          ),
        ),
      );
      expect(saved.map((r) => r['id']).toSet(), hasLength(1));
      expect(await const DemoBundleStore(1).list(), hasLength(1));
      expect(await const DemoBundleStore(2).list(), isEmpty);
      final record = (await store.list()).single;
      expect(record['recommendation'], pair);
      expect(record['demo_only'], true);
      pair['source'] = 'live';
      expect(record['recommendation']['source'], 'synthetic');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {store.storageKey});
      await store.delete(record['id']);
      expect(await store.list(), isEmpty);
    },
  );

  test(
    'storage rejects live, malformed, zero/nonfinite price and invalid quantities',
    () async {
      const store = DemoBundleStore(1);
      for (final price in ['', '0', '-1', 'NaN', 'Infinity', '1.001']) {
        await expectLater(
          store.save(
            pair: demoPair(),
            name: 'Lunch',
            quantities: [1, 1],
            price: price,
          ),
          throwsFormatException,
        );
      }
      for (final pair in [
        {...demoPair(), 'source': 'live'},
        {...demoPair(), 'revision': ''},
        {...demoPair(), 'products': []},
      ]) {
        await expectLater(
          store.save(
            pair: pair,
            name: 'Lunch',
            quantities: [1, 1],
            price: '10',
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        store.save(
          pair: demoPair(),
          name: ' ',
          quantities: [1, 1],
          price: '10',
        ),
        throwsFormatException,
      );
      await expectLater(
        store.save(
          pair: demoPair(),
          name: 'Lunch',
          quantities: [0, 1],
          price: '10',
        ),
        throwsFormatException,
      );
      expect(await store.list(), isEmpty);
    },
  );

  testWidgets(
    'prefill, fixed quantities, direct save, edit and confirmed delete',
    (tester) async {
      const store = DemoBundleStore(1);
      await open(tester);
      expect(find.text('Demo Noodles + Demo Egg'), findsOneWidget);
      expect(find.text('Demo Noodles'), findsOneWidget);
      expect(find.text('Demo Egg'), findsOneWidget);
      expect(find.text('×1'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('demo-minus-0')), findsNothing);
      expect(find.byKey(const ValueKey('demo-plus-0')), findsNothing);
      expect(find.text('Preview'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Price (₱)'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      final saveRect = tester.getRect(find.byType(FilledButton));
      expect(saveRect.bottom, closeTo(834, 1));
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('demo-name')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.labelText, isNull);
      expect(field.decoration!.hintText, 'Enter bundle name');
      expect(field.decoration!.fillColor, Colors.white);
      expect(
        (field.decoration!.enabledBorder as OutlineInputBorder)
            .borderSide
            .color,
        ProductFormStyle.border,
      );
      expect(
        tester.getRect(find.text('Bundle Name')).bottom,
        lessThan(tester.getRect(find.byKey(const ValueKey('demo-name'))).top),
      );
      final buttonStyle = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(
        buttonStyle.backgroundColor!.resolve({}),
        ProductDetailsColors.gold,
      );
      expect(
        buttonStyle.foregroundColor!.resolve({}),
        ProductDetailsColors.navy,
      );
      expect(buttonStyle.shape!.resolve({}), isA<StadiumBorder>());
      await tester.enterText(
        find.byKey(const ValueKey('demo-name')),
        'Test Lunch',
      );
      await tester.enterText(
        find.byKey(const ValueKey('demo-price')),
        '1234.50',
      );
      expect(await store.list(), isEmpty);
      await tap(tester, 'Save Demo Bundle');
      expect(find.text('Bundle Created!'), findsOneWidget);
      expect(find.byType(LottieBuilder), findsOneWidget);
      expect(
        tester.widget<LottieBuilder>(find.byType(LottieBuilder)).repeat,
        false,
      );
      expect(find.text('View Demo Bundle'), findsNothing);
      expect(find.text('Back to Suggestions'), findsNothing);
      expect(find.text('OK'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), saveRect.size);
      final top = tester
          .getRect(find.byKey(const ValueKey('demo-created-check')))
          .top;
      expect(
        tester.getSize(find.byKey(const ValueKey('demo-created-check'))),
        const Size(144, 144),
      );
      expect(top, closeTo(tester.getRect(find.byType(AppBar)).bottom + 40, 1));
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('₱1,234.50'), findsOneWidget);
      expect((await store.list()).single['quantities'], [1, 1]);
      expect((await store.list()).single['price'], '1234.50');
      await tap(tester, 'OK');
      expect(find.text('Suggestions'), findsOneWidget);
      await open(tester, saved: (await store.list()).single);
      await tap(tester, 'Edit');
      await tester.enterText(
        find.byKey(const ValueKey('demo-name')),
        'Updated Lunch',
      );
      await tester.enterText(find.byKey(const ValueKey('demo-price')), '60');
      expect(find.text('×1'), findsNWidgets(2));
      await tap(tester, 'Save Demo Bundle');
      expect(find.text('Demo Bundle'), findsOneWidget);
      final record = (await store.list()).single;
      expect(record['name'], 'Updated Lunch');
      expect(record['price'], '60.00');
      expect(record['quantities'], [1, 1]);
      await tap(tester, 'Delete Demo Bundle');
      await tap(tester, 'Cancel');
      expect(await store.list(), hasLength(1));
      await tap(tester, 'Delete Demo Bundle');
      await tap(tester, 'Delete Demo Bundle');
      expect(await store.list(), isEmpty);
      expect(find.text('Suggestions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending save disables repeat submissions until storage succeeds',
    (tester) async {
      final store = DelayedStore();
      await open(tester, store: store);
      await tester.enterText(find.byKey(const ValueKey('demo-price')), '25');
      await tester.ensureVisible(find.text('Save Demo Bundle'));
      await tester.tap(find.text('Save Demo Bundle'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Bundle Created!'), findsNothing);
      expect(find.byKey(const ValueKey('demo-created-check')), findsNothing);
      expect(await store.list(), isEmpty);
      expect(store.saves, 1);
      store.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bundle Created!'), findsOneWidget);
      expect((await store.list()).single['quantities'], [1, 1]);
    },
  );

  testWidgets(
    'supplied dotLottie decodes and reduced motion holds its final frame',
    (tester) async {
      final composition = await tester.runAsync(
        () => AssetLottie(
          'assets/animations/check.lottie',
          decoder: decodeBundleCheck,
        ).load(),
      );
      expect(composition!.duration, const Duration(seconds: 2));
      expect(composition.bounds.width, 1300);
      expect(composition.bounds.height, 1300);
      await open(tester, reducedMotion: true);
      await tester.enterText(
        find.byKey(const ValueKey('demo-price')),
        '1234567.89',
      );
      await tap(tester, 'Save Demo Bundle');
      final animation = tester.widget<LottieBuilder>(
        find.byType(LottieBuilder),
      );
      expect(animation.animate, false);
      expect(animation.repeat, false);
      expect(animation.controller!.value, 1);
      expect(find.text('₱1,234,567.89'), findsOneWidget);
      expect(find.text('View Demo Bundle'), findsNothing);
      expect(find.text('Back to Suggestions'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid inputs and storage failure never show success', (
    tester,
  ) async {
    await open(tester, store: const FailingStore());
    await tester.enterText(find.byKey(const ValueKey('demo-name')), ' ');
    await tap(tester, 'Save Demo Bundle');
    expect(find.text('Enter a bundle name.'), findsOneWidget);
    expect(find.textContaining('Enter a price greater'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('demo-name')),
      'Demo Lunch',
    );
    for (final price in ['0', '-1', 'NaN', 'Infinity', '1.001']) {
      await tester.enterText(find.byKey(const ValueKey('demo-price')), price);
      await tap(tester, 'Save Demo Bundle');
      expect(find.textContaining('Enter a price greater'), findsOneWidget);
      expect(find.text('Bundle Created!'), findsNothing);
    }
    await tester.enterText(find.byKey(const ValueKey('demo-price')), '20');
    await tap(tester, 'Save Demo Bundle');
    expect(find.textContaining('Unable to save this demo.'), findsOneWidget);
    expect(find.text('Bundle Created!'), findsNothing);
    expect(find.byKey(const ValueKey('demo-created-check')), findsNothing);
    expect(find.text('Create Demo Bundle'), findsOneWidget);
  });

  testWidgets(
    'saved list reopens persisted demo independently of suggestions',
    (tester) async {
      const store = DemoBundleStore(1);
      await store.save(
        pair: demoPair(),
        name: 'Persisted Lunch',
        quantities: [1, 2],
        price: '70',
      );
      await tester.pumpWidget(
        const MaterialApp(home: SellerDemoBundleList(store: store)),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Persisted Lunch');
      expect(find.text('Demo Bundle'), findsOneWidget);
      expect(find.text('₱70.00'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      await tap(tester, 'Back to Suggestions');
      expect(find.text('Saved Demo Bundles'), findsOneWidget);
    },
  );

  testWidgets(
    'back navigation preserves legacy data until an explicit edit save',
    (tester) async {
      const store = DemoBundleStore(1);
      final saved = await store.save(
        pair: demoPair(),
        name: 'Legacy Lunch',
        quantities: [3, 2],
        price: '90',
      );
      await open(tester, saved: saved);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      await tap(tester, 'Edit');
      expect(find.text('×1'), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const ValueKey('demo-name')),
        'Unsaved change',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Legacy Lunch'), findsOneWidget);
      expect((await store.list()).single, saved);
      await tap(tester, 'Edit');
      await tester.enterText(
        find.byKey(const ValueKey('demo-name')),
        'Updated legacy',
      );
      await tester.enterText(find.byKey(const ValueKey('demo-price')), '45');
      await tap(tester, 'Save Demo Bundle');
      final updated = (await store.list()).single;
      expect(updated['quantities'], [1, 1]);
      expect(updated['name'], 'Updated legacy');
      expect(updated['price'], '45.00');
      expect(updated['id'], saved['id']);
      expect(updated['created_at'], saved['created_at']);
      expect(updated['recommendation'], saved['recommendation']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Suggestions'), findsOneWidget);
      await tap(tester, 'Suggestions');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Suggestions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [280.0, 390.0]) {
    testWidgets(
      'compact direct-save form renders at $width with enlarged text',
      (tester) async {
        await layout.reviewFonts(tester);
        await open(tester, width: width, scale: 2);
        await tester.enterText(find.byKey(const ValueKey('demo-price')), '50');
        expect(find.text('×1'), findsNWidgets(2));
        expect(find.text('Preview'), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(FilledButton)).bottom,
          lessThanOrEqualTo(850 - 280),
        );
        await tap(tester, 'Save Demo Bundle');
        expect(find.text('Bundle Created!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['DEMO_BUNDLE_RENDER_DIR'];
        if (output != null && width == 390) {
          tester.view.resetViewInsets();
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              home: RepaintBoundary(
                key: boundaryKey,
                child: SellerDemoBundlePage(
                  pair: {...demoPair(), 'revision': 'render-success-thousands'},
                  store: const DemoBundleStore(1),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$output/demo-form.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.enterText(
            find.byKey(const ValueKey('demo-price')),
            '1234.50',
          );
          await tap(tester, 'Save Demo Bundle');
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$output/demo-success.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }

  test(
    'corrupt local storage fails without overwriting existing contents',
    () async {
      const store = DemoBundleStore(1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(store.storageKey, '{broken');
      await expectLater(
        store.save(
          pair: demoPair(),
          name: 'Lunch',
          quantities: [1, 1],
          price: '20',
        ),
        throwsFormatException,
      );
      expect(prefs.getString(store.storageKey), '{broken');
      expect(jsonEncode(demoPair()), contains('dataset-hash:thresholds'));
    },
  );
}
