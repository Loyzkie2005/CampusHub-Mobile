import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:campushub/module_app/models/facility_item.dart';
import 'package:campushub/module_app/models/service_item.dart';
import 'package:campushub/module_app/screens/facility_details_screen.dart';
import 'package:campushub/module_app/screens/facility_screen.dart';
import 'package:campushub/module_app/services/facility_service.dart';
import 'package:campushub/module_app/services/service_catalog.dart';
import 'package:campushub/module_app/widgets/facilities/resource_catalog_card.dart';
import 'package:campushub/module_app/widgets/home/home_preview_cards.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> fixture({String name = 'Fixture Court'}) => {
  'id': 'fixture-court',
  'name': name,
  'facility_type': 'covered_court',
  'facility_type_label': 'Sports Facility',
  'status': 'maintenance',
  'capacity': 300,
  'capacity_label': '300–500 pax',
  'location': 'Recorded campus location',
  'rate': '700.00',
  'price_type': 'hour',
  'price_label': '₱700.00 per hour',
  'rating': 4.8,
  'reviews': 12,
};

ServiceItem laboratory(List<Map<String, String>> fees) => ServiceItem.fromJson({
  'id': 'fixture-lab',
  'name': 'Fixture Laboratory',
  'facility_type': 'food_analysis',
  'category_label': 'Laboratory Service',
  'description': 'Recorded service information',
  'location': 'Recorded laboratory location',
  'status': 'active',
  'information': [
    {'label': 'Pricing', 'value': '${fees.length} active analysis rates'},
    ...fees,
  ],
});

const pricingExamples = [
  ('hour', '700.00', '₱700 / hour'),
  ('base_hour', '3000.00', '₱3,000 / first 4 hrs'),
  ('day', '1500.00', '₱1,500 / day'),
  ('person', '125.50', '₱125.50 / person'),
  ('person_night', '800.00', '₱800 / person / night'),
  ('night', '1200.00', '₱1,200 / night'),
  ('session', '2500.00', '₱2,500 / booking'),
  ('custom', '0', 'Price varies / See Rates'),
  ('month', '1500.00', '₱1,500 / month'),
  ('monthly', '1500.00', '₱1,500 / month'),
];

FacilityItem pricingFixture(String method, String rate) =>
    FacilityItem.fromJson({
      ...fixture(),
      'price_type': method,
      'rate': rate,
      // Conflicting admin text proves cards use the raw saved method and rate.
      'price_compact_label': 'Admin summary remains available',
      'workflow_config': {
        'pricing': {'base_duration': '4', 'additional_hour_rate': '500'},
      },
    });

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    List<Widget> cards, {
    double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: capture,
            child: ColoredBox(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [ResourceCardGrid(children: cards)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (320.0, 2.0),
    (600.0, 1.0),
    (844.0, 1.0),
  ]) {
    testWidgets(
      'wider vertical cards keep image, location and actions aligned $width/$scale',
      (tester) async {
        var opened = false;
        final record = FacilityItem.fromJson(fixture());
        final longer = FacilityItem.fromJson({
          ...fixture(),
          'name': 'A facility with a longer descriptive recorded name',
          'location': 'A longer recorded campus building and room location',
          'rating': '',
          'reviews': '',
        });
        await show(
          tester,
          [
            FacilityPreviewCard(
              facility: record,
              onDetails: () => opened = true,
            ),
            FacilityPreviewCard(facility: longer),
          ],
          width: width,
          scale: scale,
          brightness: Brightness.dark,
        );
        final cards = find.byType(ResourceCatalogCard);
        final a = tester.getRect(cards.first);
        final b = tester.getRect(cards.last);
        if (width >= 844) {
          expect(a.top, b.top);
          expect(a.height, closeTo(b.height, .01));
        } else {
          expect(a.width, closeTo(width - 32, .01));
          expect(b.top, greaterThan(a.bottom));
        }
        expect(b.right, lessThanOrEqualTo(width - 16));
        final image = tester.getRect(find.byType(ProductImage).first);
        expect(image.left, closeTo(a.left, .01));
        expect(image.width / image.height, closeTo(4 / 3, .001));
        expect(image.width, closeTo(a.width, .01));
        expect(
          tester.getTopLeft(find.text(record.name)).dy,
          greaterThan(image.bottom),
        );
        final badge = tester.getRect(find.byType(ResourceReviewBadge).first);
        expect(badge.left, closeTo(image.left + 8, .01));
        expect(badge.top, closeTo(image.top + 8, .01));
        expect(badge.right, lessThanOrEqualTo(image.right - 8 + .01));
        final location = tester.getRect(
          find.byType(ResourceLocationLabel).first,
        );
        expect(location.left, closeTo(image.left + 8, .01));
        expect(location.bottom, closeTo(image.bottom - 8, .01));
        expect(location.top, greaterThan(badge.bottom));
        expect(find.text(record.location), findsOneWidget);
        expect(find.text('4.8 (12)'), findsOneWidget);
        expect(find.text('No reviews yet'), findsOneWidget);
        expect(find.text('Under Maintenance'), findsNWidgets(2));
        expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
        final buttons = find.widgetWithText(TextButton, 'View Details');
        if (width >= 844) {
          expect(
            tester.getBottomLeft(buttons.first).dy,
            closeTo(tester.getBottomLeft(buttons.last).dy, .01),
          );
        }
        expect(tester.getSize(buttons.first).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(buttons.first);
        await tester.pumpAndSettle();
        await tester.tap(buttons.first);
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing locations stay absent; long locations retain full tooltip',
    (tester) async {
      for (final location in ['', '   ']) {
        await show(tester, [
          FacilityPreviewCard(
            facility: FacilityItem.fromJson({
              ...fixture(),
              'location': location,
            }),
          ),
        ]);
        expect(find.byType(ResourceLocationLabel), findsNothing);
      }
      final fullLocation = List.filled(
        8,
        'Recorded campus building and room',
      ).join(' ');
      await show(
        tester,
        [
          FacilityPreviewCard(
            facility: FacilityItem.fromJson({
              ...fixture(),
              'location': fullLocation,
              'rating': '',
              'reviews': '',
            }),
          ),
        ],
        width: 320,
        scale: 2,
      );
      expect(find.byTooltip(fullLocation), findsOneWidget);
      final location = tester.getRect(find.byType(ResourceLocationLabel));
      final image = tester.getRect(find.byType(ProductImage));
      final rating = tester.getRect(find.byType(ResourceReviewBadge));
      expect(location.bottom, closeTo(image.bottom - 8, .01));
      expect(location.top, greaterThan(rating.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review badge rejects missing counts, booking counts and invalid scores',
    (tester) async {
      for (final data in [
        {...fixture(), 'reviews': '', 'booking_count': 99},
        {...fixture(), 'reviews': 0},
        {...fixture(), 'rating': 0},
        {...fixture(), 'rating': 'NaN'},
        {...fixture(), 'rating': 6},
        {...fixture(), 'rating': '', 'reviews': ''},
      ]) {
        await show(tester, [
          FacilityPreviewCard(facility: FacilityItem.fromJson(data)),
        ]);
        expect(find.text('No reviews yet'), findsOneWidget);
        expect(find.text('4.8 (99)'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      final handle = tester.ensureSemantics();
      await show(tester, [
        FacilityPreviewCard(facility: FacilityItem.fromJson(fixture())),
      ]);
      expect(
        tester.getSemantics(find.byType(ResourceReviewBadge)).label,
        contains('4.8 out of 5 stars from 12 reviews'),
      );
      handle.dispose();
    },
  );

  test(
    'configured billing labels survive parsing without changing stored rates',
    () {
      for (final label in [
        '₱6000.00 first 4 hours',
        '₱800.00 per person / night',
      ]) {
        final record = FacilityItem.fromJson({
          ...fixture(),
          'price_compact_label': '',
          'price_label': label,
        });
        expect(record.priceLabel, label);
        expect(record.rate, '700.00');
      }
      final record = FacilityItem.fromJson({
        ...fixture(),
        'price_compact_label': 'Configured compact basis',
      });
      expect(record.priceLabel, 'Configured compact basis');
    },
  );

  test(
    'mobile pricing follows saved methods without altering server labels',
    () {
      for (final (method, rate, expected) in pricingExamples) {
        final record = pricingFixture(method, rate);
        expect(record.cardPriceLabel, expected, reason: method);
        expect(record.rate, rate);
        expect(record.priceType, method);
        expect(record.catalogPriceLabel, 'Admin summary remains available');
        expect(record.priceLabel, 'Admin summary remains available');
      }
    },
  );

  test('card pricing keeps decimals and rejects incomplete configuration', () {
    for (final (hours, expected) in [
      ('1', '₱3,000 / first 1 hr'),
      ('2.5', '₱3,000 / first 2.5 hrs'),
      ('4.00', '₱3,000 / first 4 hrs'),
      ('24', '₱3,000 / first 24 hrs'),
    ]) {
      final record = FacilityItem.fromJson({
        ...fixture(),
        'price_type': 'base_hour',
        'rate': '3000',
        'workflow_config': {
          'pricing': {'base_duration': hours},
        },
      });
      expect(record.cardPriceLabel, expected);
    }
    for (final workflow in [
      null,
      'invalid',
      {'pricing': 'invalid'},
      {'pricing': <String, dynamic>{}},
      for (final hours in ['0', '-1', '25', 'NaN', 'Infinity', 'unknown'])
        {
          'pricing': {'base_duration': hours},
        },
    ]) {
      expect(
        FacilityItem.fromJson({
          ...fixture(),
          'price_type': 'base_hour',
          'workflow_config': workflow,
        }).cardPriceLabel,
        'Pricing needs review',
      );
    }
    for (final rate in ['', '0', '-1', 'NaN', 'Infinity', 'unknown']) {
      expect(pricingFixture('hour', rate).cardPriceLabel, 'Contact Admin');
    }
    expect(
      pricingFixture('hour', '12345.67').cardPriceLabel,
      '₱12,345.67 / hour',
    );
    expect(
      pricingFixture('future_method', '700').cardPriceLabel,
      'Admin summary remains available',
    );
    expect(
      FacilityItem.fromJson({
        ...fixture(),
        'price_type': 'future_method',
        'price_label': '',
      }).cardPriceLabel,
      'Contact Admin',
    );
  });

  for (final (width, scale, brightness) in [
    (390.0, 1.0, Brightness.light),
    (320.0, 2.0, Brightness.dark),
  ]) {
    testWidgets('card renders every pricing method $width/$scale/$brightness', (
      tester,
    ) async {
      for (final (method, rate, label) in pricingExamples) {
        await show(
          tester,
          [FacilityPreviewCard(facility: pricingFixture(method, rate))],
          width: width,
          scale: scale,
          brightness: brightness,
        );
        expect(find.text(label), findsOneWidget, reason: method);
        expect(find.text('Admin summary remains available'), findsNothing);
        expect(tester.takeException(), isNull, reason: method);
      }
    });
  }

  test('lowest active service price compares compatible units only', () {
    final fees = [
      {'label': 'Analysis A', 'value': '₱806.40 per analysis'},
      {'label': 'Analysis B', 'value': '₱604.80 per analysis'},
    ];
    expect(serviceCardPrice(laboratory(fees)), 'From ₱604.80 per analysis');
    expect(serviceCardPrice(laboratory([fees.first])), '₱806.40 per analysis');
    expect(
      serviceCardPrice(
        laboratory([
          fees.first,
          {'label': 'Other', 'value': '₱99.00 per sample'},
        ]),
      ),
      '2 active analysis rates',
    );
    expect(
      serviceCardPrice(
        laboratory([
          {'label': 'Bad', 'value': '₱-5 per analysis'},
        ]),
      ),
      '1 active analysis rates',
    );
    final assessment = ServiceItem.fromJson({
      'facility_type': 'training_kitchen',
      'price_label': '₱1700.00 / candidate',
    });
    expect(serviceCardPrice(assessment), '₱1700.00 / candidate');
  });

  testWidgets('service uses the same rating overlay and configured price', (
    tester,
  ) async {
    final row = ServiceItem.fromJson({
      'id': 'fixture-assessment',
      'name': 'Fixture Assessment',
      'facility_type': 'training_kitchen',
      'category_label': 'Skills Assessment',
      'description': 'Recorded competency assessment',
      'location': 'Recorded center',
      'rating': 4.2,
      'reviews': 3,
      'price_label': '₱1700.00 / candidate',
    });
    await show(tester, [
      ServicePreviewCard(service: row, catalog: const ServiceCatalog()),
    ]);
    expect(find.text('4.2 (3)'), findsOneWidget);
    expect(find.text('₱1700.00 / candidate'), findsOneWidget);
    expect(find.text('Recorded center'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Skills Assessment')).dy,
      greaterThan(tester.getBottomLeft(find.byType(ProductImage)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('facility listing retains selected details and My Bookings', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: FacilitiesPage(
            loadFacilities: () async => FacilityServiceResult(
              success: true,
              facilities: [
                fixture(),
                {...fixture(name: 'Fixture Hostel'), 'id': 'hostel'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.byType(ResourceCatalogCard), findsNWidgets(2));
    await tester.tap(find.text('Fixture Court'));
    final route = observer.pushed! as MaterialPageRoute<void>;
    final destination =
        route.builder(tester.element(find.byType(FacilitiesPage)))
            as FacilityDetailsScreen;
    expect(destination.facility.id, 'fixture-court');
    // Inspect the real route before mounting its authenticated booking loader.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('image fallback preserves overlay and real image aspect', (
    tester,
  ) async {
    await show(tester, [
      FacilityPreviewCard(
        facility: FacilityItem.fromJson({
          ...fixture(),
          'image_url': 'data:image/png;base64,invalid',
        }),
      ),
    ]);
    expect(find.byIcon(Icons.sports_basketball_outlined), findsOneWidget);
    expect(find.text('4.8 (12)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'existing image loader decodes an actual image and retains overlay',
    (tester) async {
      final data = await tester.runAsync(
        () => rootBundle.load('assets/img/ustp_oroquieta_entrance.png'),
      );
      final image =
          'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
      await show(tester, [
        FacilityPreviewCard(
          facility: FacilityItem.fromJson({...fixture(), 'image_url': image}),
        ),
      ]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('4.8 (12)'), findsOneWidget);
      expect(find.byIcon(Icons.sports_basketball_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('optional actual widget renders for review', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_RESOURCE_CARDS');
    if (!capture) return;
    await tester.runAsync(() async {
      await (FontLoader('Inter')
            ..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (final (width, scale) in [(320.0, 1.0), (414.0, 1.0), (320.0, 2.0)]) {
      final key = GlobalKey();
      final service = laboratory([
        {'label': 'Analysis A', 'value': '₱806.40 per analysis'},
        {'label': 'Analysis B', 'value': '₱604.80 per analysis'},
      ]);
      await show(
        tester,
        [
          FacilityPreviewCard(facility: FacilityItem.fromJson(fixture())),
          FacilityPreviewCard(
            facility: FacilityItem.fromJson({
              ...fixture(name: 'Fixture Hostel'),
              'rate': '800.00',
              'price_type': 'person_night',
              'rating': '',
              'reviews': '',
            }),
          ),
          ServicePreviewCard(service: service, catalog: const ServiceCatalog()),
          ServicePreviewCard(
            service: ServiceItem.fromJson({
              'name': 'Fixture Assessment',
              'facility_type': 'training_kitchen',
              'category_label': 'Skills Assessment',
              'price_label': '₱1700.00 / candidate',
            }),
            catalog: const ServiceCatalog(),
          ),
        ],
        width: width,
        scale: scale,
        capture: key,
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('../scratch/facility-service-cards-20261029')
          ..createSync(recursive: true);
        File(
          '${folder.path}/cards-$width-$scale.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
