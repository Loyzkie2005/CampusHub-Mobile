import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:campushub/module_app/widgets/seller/synthetic_demo_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _egg = 'assets/demo/synthetic/egg.png';

ImageProvider originalProvider(Image image) => image.image is ResizeImage
    ? (image.image as ResizeImage).imageProvider
    : image.image;

Future<void> showImage(
  WidgetTester tester, {
  String url = '',
  String? asset = _egg,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: ProductImage(
            imageUrl: url,
            fallbackAsset: asset,
            fallbackIcon: Icons.inventory_2_outlined,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'demo images require exact composite source identity and demo source',
    () {
      const row = {'source': 'synthetic'};
      expect(
        syntheticDemoImage(row, {'id': 123, 'source_id': 'S04:P02'}),
        _egg,
      );
      expect(syntheticDemoImage(row, {'id': 'S03:P02'}), _egg);
      for (final identity in [2, '2', 'P02', 'S99:P02', 'S04:P99', null]) {
        expect(syntheticDemoImage(row, {'id': identity}), isNull);
      }
      expect(
        syntheticDemoImage({'source': 'live'}, {'source_id': 'S04:P02'}),
        isNull,
      );
    },
  );

  test(
    'all registered illustrations and their license are actually bundled',
    () async {
      final assets = syntheticDemoImageAssets.values.toSet();
      expect(assets.length, 6);
      for (final asset in assets) {
        final bytes = await rootBundle.load(asset);
        expect(bytes.buffer.asUint8List().take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
      }
      expect(
        await rootBundle.loadString('assets/demo/synthetic/LICENSE.txt'),
        contains('Attribution-ShareAlike 4.0'),
      );
    },
  );

  testWidgets('verified catalog image takes precedence over the demo asset', (
    tester,
  ) async {
    await showImage(
      tester,
      url:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2X8AAAAASUVORK5CYII=',
    );
    expect(
      originalProvider(tester.widget<Image>(find.byType(Image))),
      isA<MemoryImage>(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('absent catalog photo loads the offline demo illustration', (
    tester,
  ) async {
    await showImage(tester);
    final provider =
        originalProvider(tester.widget<Image>(find.byType(Image)))
            as AssetImage;
    expect(provider.assetName, _egg);
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(_egg),
        tester.element(find.byType(ProductImage)),
      );
    });
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('broken catalog photo falls back to its bundled demo image', (
    tester,
  ) async {
    await showImage(tester, url: 'data:image/png;base64,not-valid!');
    final provider =
        originalProvider(tester.widget<Image>(find.byType(Image)))
            as AssetImage;
    expect(provider.assetName, _egg);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unknown identities and missing asset files preserve the placeholder',
    (tester) async {
      await showImage(tester, asset: null);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      await showImage(
        tester,
        asset: 'assets/demo/synthetic/missing-test-only.png',
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
