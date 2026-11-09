import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/config/api_config.dart';
import 'package:campushub/module_app/services/seller_application_service.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'seller_home_layout_test.dart' as layout;

class _RealNetwork extends HttpOverrides {}

void main() {
  testWidgets('synthetic API states retain the existing icon and honest copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    for (final entry in {
      'not_generated': 'No demo bundles available',
      'no_qualifying_pairs': 'No demo bundles available',
      'error': 'Unable to load this section.',
    }.entries) {
      final data = layout.layoutData(orders: 0);
      data['recommendations'] = {
        'source': 'synthetic',
        'status': entry.key,
        'rows': [],
        'error': entry.key == 'error',
      };
      await layout.show(tester, layout.content(data));
      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.text('Sample product combination — Not for Sale'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('seller-bundle-synthetic-empty')),
          matching: find.byIcon(LucideIcons.packageSearch),
        ),
        entry.key == 'error' ? findsNothing : findsOneWidget,
      );
      expect(find.text('Create Bundle'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  final base = Platform.environment['SELLER_DEMO_API_URL'];
  final token = Platform.environment['SELLER_DEMO_TOKEN'];
  testWidgets(
    'actual authenticated Django CSV response parses, renders and swipes',
    (tester) async {
      final uri = Uri.parse(base!);
      expect(['127.0.0.1', 'localhost'], contains(uri.host));
      SharedPreferences.setMockInitialValues({'campushub_chat_token': token!});
      ApiConfig.recordWorkingBaseUrl(base);
      late Map<String, dynamic> demo;
      await tester.runAsync(() async {
        await HttpOverrides.runZoned(
          () async {
            const service = SellerApplicationService();
            demo = await service.recommendations('synthetic');
            expect(demo['status'], 'ready');
            expect(demo['source'], 'synthetic');
            expect((demo['rows'] as List).length, greaterThan(1));
            final live = await service.recommendations('live');
            expect(live['source'], 'live');
            expect(
              (live['rows'] as List).any((row) => row['source'] == 'synthetic'),
              isFalse,
            );
            final first = Map<String, dynamic>.from(
              (demo['rows'] as List).first,
            );
            if (first['can_create'] == false) {
              await expectLater(
                service.recommendationAction(first, 'validate'),
                throwsA(
                  isA<SellerApplicationException>().having(
                    (error) => error.statusCode,
                    'unmapped demo remains blocked',
                    409,
                  ),
                ),
              );
            }
          },
          createHttpClient: (context) =>
              _RealNetwork().createHttpClient(context),
        );
      });
      final data = layout.layoutData(orders: 0);
      data['recommendations'] = demo;
      final capture = GlobalKey();
      await layout.reviewFonts(tester);
      await layout.show(tester, layout.content(data), capture: capture);
      final carousel = find.byKey(const ValueKey('seller-bundles-synthetic'));
      await layout.reach(tester, carousel);
      final rows = demo['rows'] as List;
      expect(find.text('1 of ${rows.length}'), findsNothing);
      final pair = (rows.first as Map)['products'] as List;
      expect(find.text(pair.first['name']).hitTestable(), findsOneWidget);
      expect(find.text(pair.last['name']).hitTestable(), findsOneWidget);
      final thumbnails = tester.widgetList<ProductImage>(
        find.descendant(of: carousel, matching: find.byType(ProductImage)),
      );
      expect(thumbnails, isNotEmpty);
      expect(thumbnails.every((image) => image.fallbackAsset != null), isTrue);
      expect(
        find.byKey(const ValueKey('seller-bundle-synthetic-empty')),
        findsNothing,
      );
      expect(
        find.text('Sample product combination — Not for Sale'),
        findsNWidgets(2),
      );
      expect(find.text('Recent Orders'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('seller-bundle-carousel')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of ${rows.length}'), findsNothing);
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('bundle-indicator-1')))
            .constraints!
            .maxWidth,
        18,
      );
      // Asset decoding runs outside the fake widget-test clock. Wait for the
      // actual visible providers before capturing or claiming image rendering.
      final images = tester
          .widgetList<Image>(
            find.descendant(of: carousel, matching: find.byType(Image)),
          )
          .toList();
      expect(images, isNotEmpty);
      await tester.runAsync(() async {
        for (final image in images) {
          Object? failure;
          await precacheImage(
            image.image,
            tester.element(carousel),
            onError: (error, _) => failure = error,
          );
          expect(failure, isNull);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final output = Platform.environment['SELLER_DEMO_CAPTURE'];
      if (output != null) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(output).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
    skip: base == null || token == null,
  );
}
