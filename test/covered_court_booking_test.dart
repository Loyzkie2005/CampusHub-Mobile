import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/models/facility_item.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_screen.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_history_screen.dart';
import 'package:campushub/module_app/services/facility_booking_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/facility_booking_fixture.dart';

// Isolated pricing contract: matches the Django five-hour package test,
// with an independently authorized fixed 500 deposit. Never production data.
class CoveredCourtService extends TestBookingService {
  int attempts = 0;
  bool uncertainOnce = false, rejectOnce = false, approved = false;
  Map<String, dynamic>? quoted, savedResponse;
  final bodies = <Map<String, dynamic>>[];
  String chairRate = '10';
  bool hasChairRental = true;
  List<String> requirementOptions = ['Chairs'];
  Map<String, dynamic> get estimate => {
    'base_rental_amount': '3000.00',
    'additional_hour_amount': '500.00',
    'base_amount': '3500.00',
    'discount_amount': '1750.00',
    'discount_label': 'Internal client discount',
    'rental_amount': '1750.00',
    'fee_amount': '200.00',
    'deposit_amount': '500.00',
    'total_amount': '2450.00',
    'hours': '5',
    'quote_token': 'isolated-reviewed-price',
    'fees': [
      {'name': 'Chairs', 'quantity': '20', 'amount': '200.00'},
    ],
    'pricing_options': {
      'requirement_options': requirementOptions,
      'item_fees': [
        if (hasChairRental)
          {'index': 0, 'name': 'Chairs', 'unit_amount': chairRate},
      ],
    },
  };
  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async => [
    {
      'start': '08:00',
      'end': '13:00',
      'label': '8:00 AM - 1:00 PM',
      'status': 'available',
    },
  ];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (path.endsWith('quote/')) {
      if (body?['availability_only'] == true) {
        return {
          'available': true,
          'pricing_options': estimate['pricing_options'],
        };
      }
      quoted = Map<String, dynamic>.from(body!);
      return estimate;
    }
    if (path == 'bookings/' && body != null) {
      attempts++;
      bodies.add(Map<String, dynamic>.from(body));
      if (rejectOnce) {
        rejectOnce = false;
        throw const BookingException(
          'The booking charges changed. Review the updated quote.',
          statusCode: 400,
        );
      }
      savedResponse ??= await super.request(path, body: body);
      if (uncertainOnce) {
        uncertainOnce = false;
        throw const BookingException(
          'Unable to confirm submission. Retry this request.',
          uncertain: true,
        );
      }
      return savedResponse!;
    }
    if (path == 'bookings/' && body == null) {
      return {
        'bookings': [
          {
            'id': 'ISOLATED-COURT-BOOKING',
            'status': approved ? 'approved' : 'pending',
            'date': '2026-11-07',
            'start': '08:00',
            'end': '13:00',
            'facility': {
              'id': 'TEST-COURT',
              'name': 'Test Covered Court',
              'facility_type': 'covered_court',
            },
            'total_amount': '2450.00',
            'created_at': '2026-11-04T00:00:00Z',
          },
        ],
      };
    }
    return super.request(path, body: body);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('packages/lucide_icons/Lucide')
          ..addFont(rootBundle.load('packages/lucide_icons/assets/lucide.ttf')))
        .load();
    await (FontLoader('Montserrat')..addFont(
          rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> review(
    WidgetTester tester,
    CoveredCourtService service, {
    double width = 390,
    int? chairs = 20,
    bool advanceToReview = true,
    String facilityType = 'covered_court',
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('covered-court-render'),
          child: FacilityBookingScreen(
            facility: FacilityItem.fromJson({
              'id': 'TEST-COURT',
              'name': 'Test Covered Court',
              'facility_type': facilityType,
              'status': 'available',
              'booking_mode': 'slot',
              'capacity': 500,
              'rate': '3000',
              'price_type': 'base_hour',
              'job_order_service': 'Facility Rental',
              'amenities': ['Chairs'],
            }),
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('8:00 AM - 1:00 PM'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('8:00 AM - 1:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Booking Details'));
    await tester.pumpAndSettle();
    for (final entry in {
      'Full Name': 'Test Requestor',
      'Contact Number': '09171234567',
      'Email Address': 'isolated@example.test',
      'Event / Activity Name': 'Practice',
      'Purpose': 'Sports practice',
      'Expected Number of Attendees': '300',
    }.entries) {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText == entry.key ||
                widget.decoration?.hintText ==
                    'Enter ${entry.key.toLowerCase()}'),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.pump();
    }
    if (chairs != null) {
      final chairCard = find.byKey(
        const ValueKey('booking-requirement-Chairs'),
      );
      await tester.ensureVisible(chairCard);
      await tester.tap(chairCard);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chairs-quantity-input')),
        '$chairs',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }
    if (!advanceToReview) return;
    await tester.tap(find.text('Next: Review Booking'));
    await tester.pumpAndSettle();
    expect(find.text('Review Booking'), findsOneWidget);
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Review displays the complete Django quote at $width and sends quantities/token',
      (tester) async {
        final service = CoveredCourtService();
        await review(tester, service, width: width);
        expect(service.quoted?['attendees'], '300');
        expect(service.quoted?['fee_quantities'], {'0': '20'});
        expect(service.quoted?['additional_requirements'], contains('Chairs'));
        for (final label in [
          'Additional Hours',
          'Internal client discount',
          'Chairs × 20',
          'Refundable damage deposit',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('₱2450.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['COURT_REVIEW_DIR'];
        if (directory != null) {
          await tester.ensureVisible(find.text('Estimated Total'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('covered-court-render')),
            );
            final rendered = await boundary.toImage(pixelRatio: 2);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$directory/quote-${width.toInt()}.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.tap(find.text('Submit Booking Request'));
        await tester.pumpAndSettle();
        expect(find.text('Booking Request Submitted!'), findsOneWidget);
        expect(service.submitted?['quoted_amount'], '2450.00');
        expect(service.submitted?['quote_token'], 'isolated-reviewed-price');
        expect(service.submitted?['fee_quantities'], {'0': '20'});
      },
    );
  }

  testWidgets(
    'uncertain submission retries the same frozen request without a second booking',
    (tester) async {
      final service = CoveredCourtService()..uncertainOnce = true;
      await review(tester, service);
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to confirm'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Review Booking'), findsOneWidget);
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(service.attempts, 2);
      expect(service.submissions, 1);
      expect(service.bodies[0], service.bodies[1]);
      expect(find.text('Booking Request Submitted!'), findsOneWidget);
    },
  );

  testWidgets(
    'definite quote rejection preserves fields and permits a new review',
    (tester) async {
      final service = CoveredCourtService()..rejectOnce = true;
      await review(tester, service);
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('booking charges changed'), findsOneWidget);
      expect(find.text('Next: Review Booking'), findsOneWidget);
      expect(find.text('Test Requestor'), findsOneWidget);
      expect(service.submissions, 0);
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(service.submissions, 1);
    },
  );

  testWidgets(
    'checked Chairs checkbox removes directly while unchecked checkbox opens quantity',
    (tester) async {
      final service = CoveredCourtService();
      await review(tester, service);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final chairs = find.byKey(const ValueKey('booking-requirement-Chairs'));
      await tester.ensureVisible(chairs);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(chairs).properties.checked, isTrue);
      final checkbox = find.byKey(
        const ValueKey('booking-requirement-toggle-Chairs'),
      );
      expect(tester.getSize(checkbox), const Size(48, 48));
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('Chairs Quantity'), findsNothing);
      expect(find.byKey(const ValueKey('booking-fee-0')), findsNothing);
      expect(tester.widget<Semantics>(chairs).properties.checked, isFalse);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('chairs-quantity-input'));
      expect(tester.widget<TextField>(input).controller!.text, '1');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(chairs).properties.checked, isFalse);
      await tester.tap(chairs);
      await tester.pumpAndSettle();
      await tester.enterText(input, '5');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final semantics = tester.widget<Semantics>(chairs).properties;
      expect(
        semantics.customSemanticsActions!.keys.single.label,
        'Edit chairs quantity',
      );
      semantics.onTap!();
      await tester.pumpAndSettle();
      expect(find.text('Chairs Quantity'), findsNothing);
      expect(tester.widget<Semantics>(chairs).properties.checked, isFalse);
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(service.quoted?['fee_quantities'], {'0': '0'});
      expect(
        service.quoted?['additional_requirements'],
        isNot(contains('Chairs')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chairs card alone edits quantity and sends the saved rate quantity to Django',
    (tester) async {
      final service = CoveredCourtService()..chairRate = '12.35';
      await review(tester, service, chairs: null, advanceToReview: false);
      final card = find.byKey(const ValueKey('booking-requirement-Chairs'));
      expect(find.byKey(const ValueKey('booking-fee-0')), findsNothing);
      expect(find.text('Chairs quantity'), findsNothing);
      expect(find.textContaining('tap to edit or remove Chairs'), findsNothing);
      expect(
        find.textContaining('Configured charges are included'),
        findsNothing,
      );
      expect(find.text('\u20b112.35 per chair'), findsOneWidget);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('chairs-quantity-input'));
      expect(tester.widget<TextField>(input).controller!.text, '1');
      await tester.enterText(input, '20');
      await tester.pump();
      expect(find.text('Estimated chair charge'), findsOneWidget);
      expect(find.text('\u20b1247.00'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(card).properties.checked, isFalse);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.enterText(input, '20');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(card).properties.checked, isTrue);
      expect(find.text('20 chairs \u00b7 \u20b1247.00'), findsOneWidget);
      final directory = Platform.environment['CHAIRS_REVIEW_DIR'];
      if (directory != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('covered-court-render')),
          );
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File('$directory/confirmed-chairs-card.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '20');
      await tester.enterText(input, '99');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('20 chairs \u00b7 \u20b1247.00'), findsOneWidget);
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(service.quoted?['fee_quantities'], {'0': '20'});
      expect(service.quoted?['attendees'], '300');
      // The fixture's issued quote is authoritative even when its estimate differs.
      expect(find.text('Chairs × 20'), findsOneWidget);
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(service.bodies.single['fee_quantities'], {'0': '20'});
      expect(service.bodies.single.containsKey('chair_subtotal'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Function Hall without a separate Chair fee retains ordinary selection',
    (tester) async {
      final service = CoveredCourtService()..hasChairRental = false;
      await review(
        tester,
        service,
        chairs: null,
        advanceToReview: false,
        facilityType: 'function_hall',
      );
      final card = find.byKey(const ValueKey('booking-requirement-Chairs'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Chairs Quantity'), findsNothing);
      expect(find.textContaining('per chair'), findsNothing);
      expect(tester.widget<Semantics>(card).properties.checked, isTrue);
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(service.quoted?['fee_quantities'], isEmpty);
      expect(service.quoted?['additional_requirements'], contains('Chairs'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh admin choices replace stale cards and clear a removed chair quantity',
    (tester) async {
      final service = CoveredCourtService();
      await review(tester, service, advanceToReview: false);
      expect(find.text('20 chairs \u00b7 \u20b1200.00'), findsOneWidget);
      service.requirementOptions = ['Microphone', 'Extension Cords'];
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: Booking Details'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('booking-requirement-Chairs')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('booking-fee-0')), findsNothing);
      expect(
        find.byKey(const ValueKey('booking-requirement-Microphone')),
        findsOneWidget,
      );
      final custom = find.byKey(
        const ValueKey('booking-requirement-Extension Cords'),
      );
      await tester.ensureVisible(custom);
      await tester.pumpAndSettle();
      await tester.tap(custom);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(service.quoted?['additional_requirements'], ['Extension Cords']);
      expect(service.quoted?['fee_quantities'], {'0': '0'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('booking history refreshes an approval when the phone resumes', (
    tester,
  ) async {
    final service = CoveredCourtService();
    await tester.pumpWidget(
      MaterialApp(home: FacilityBookingHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Pending'), findsOneWidget);
    service.approved = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Approved'), findsOneWidget);
    expect(find.textContaining('Pending'), findsNothing);
  });
}
