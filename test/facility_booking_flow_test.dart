import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/screens/facility_details_screen.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_screen.dart';
import 'package:campushub/module_app/models/facility_item.dart';
import 'fixtures/facility_booking_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<TestBookingService> open(
    WidgetTester tester, {
    double scale = 1,
    FacilityItem? facility,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final service = TestBookingService();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: FacilityBookingScreen(
          facility: facility ?? testFacility,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> select(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('1:00 PM - 5:00 PM'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('1:00 PM - 5:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:00 PM - 5:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Booking Details'));
    await tester.pumpAndSettle();
  }

  testWidgets('live conflict prevents advancing; blocked slot is omitted', (
    tester,
  ) async {
    final service = await open(tester);
    expect(find.text('8:00 AM - 12:00 PM'), findsNothing);
    service.conflict = true;
    await select(tester);
    expect(find.text('Select Schedule'), findsOneWidget);
    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(service.submissions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'request form validates, retains values, reviews and submits once',
    (tester) async {
      final service = await open(tester);
      await select(tester);
      expect(find.text('Job Order Request'), findsOneWidget);
      expect(find.text('Facility Rental'), findsOneWidget);
      expect(
        find.textContaining('After approval, CampusHub prepares'),
        findsOneWidget,
      );
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(service.submissions, 0);
      final values = {
        'Full Name': 'Test Requestor',
        'Organization / Office': 'Test Office',
        'Contact Number': '09171234567',
        'Email Address': 'test@example.edu',
        'Event / Activity Name': 'Practice',
        'Purpose': 'Sports practice',
        'Expected Number of Attendees': '20',
      };
      for (final entry in values.entries) {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(find.text('Review Booking'), findsOneWidget);
      expect(find.text('Job Order Request'), findsOneWidget);
      expect(find.text('Facility Rental'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Test Requestor'), findsOneWidget);
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(find.text('Booking Request Submitted!'), findsOneWidget);
      expect(service.submissions, 1);
      expect(service.submitted!['purpose'], 'Sports practice');
      expect(service.submitted!['request_key'], isNotEmpty);
      expect(service.submitted!.containsKey('job_order'), isFalse);
      expect(service.submitted!.containsKey('job_order_service'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('schedule and form fit a phone with enlarged text', (
    tester,
  ) async {
    await open(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    await select(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing server mapping does not guess from a facility name', (
    tester,
  ) async {
    final resource = FacilityItem.fromJson({
      'id': 'TEST-OTHER',
      'name': 'Covered Court name without a mapping',
      'facility_type': 'other',
      'booking_mode': 'slot',
      'capacity': 50,
    });
    await open(tester, facility: resource);
    await select(tester);
    expect(
      find.text('Service to be confirmed by Facilities Admin'),
      findsOneWidget,
    );
    expect(find.text('Facility Rental'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FacilityDetailsScreen renders image-first sections and keeps real booking actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detailedFacility = FacilityItem.fromJson({
        'id': 'COVERED-COURT-TEST',
        'name': 'Covered Court',
        'facility_type': 'covered_court',
        'facility_type_label': 'Covered Court',
        'status': 'available',
        'capacity': 500,
        'rate': '500.00',
        'price_type': 'hour',
        'booking_mode': 'slot',
        'location': 'Sports Complex / Multi-purpose Facility',
        'description':
            'A spacious multi-purpose covered court ideal for sports events, practices, student programs, school activities, and community gatherings.',
        'amenities': [
          'Basketball Court',
          'Bleachers',
          'Sound System',
          'Lighting',
          'Restrooms',
          'Parking Area',
        ],
        'terms_conditions':
            'Proper attire must be observed.\nKeep the facility clean.\nFollow schedule and booking guidelines.',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FacilityDetailsScreen(
            facility: detailedFacility,
            service: TestBookingService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Facility Details'), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-main-info-card')),
        findsOneWidget,
      );
      expect(find.text('USTP Oroquieta Campus'), findsNothing);
      expect(
        find.text('Sports Complex / Multi-purpose Facility'),
        findsOneWidget,
      );
      expect(find.text('500 persons'), findsOneWidget);
      expect(find.text('Request Booking'), findsOneWidget);
      expect(find.byKey(const ValueKey('facility-rules-card')), findsOneWidget);
      expect(
        find.textContaining('Proper attire must be observed.'),
        findsOneWidget,
      );

      // The heart keeps the existing local saved-favorite preference.
      await tester.tap(find.byKey(const ValueKey('facility-favorite-button')));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'facility_favorite_COVERED-COURT-TEST',
        ),
        isTrue,
      );

      // Saved sections share the same scroll, with no tab or availability action.
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-amenities-card')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('facility-rules-card')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('facility-availability-card')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Operating days are not configured.'), findsOneWidget);
      expect(find.text('Check Availability'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('facility-request-booking-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Select Schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
