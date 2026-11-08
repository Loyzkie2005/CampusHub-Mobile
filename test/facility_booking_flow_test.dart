import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/screens/facility_details_screen.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_screen.dart';
import 'package:campushub/module_app/models/facility_item.dart';
import 'fixtures/facility_booking_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final capture = GlobalKey();
  final reviewDirectory = Platform.environment['BOOKING_FORM_REVIEW_DIR'];
  final selectableRequirements = testFacilityWithRequirements([
    'Chairs',
    'Tables',
    'Sound System',
    'Projector',
    'Others',
    'Extension Cords',
  ]);

  Future<void> saveForm(WidgetTester tester, String name) async {
    if (reviewDirectory == null) return;
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 2);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$reviewDirectory/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  Future<TestBookingService> open(
    WidgetTester tester, {
    double scale = 1,
    double width = 390,
    FacilityItem? facility,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final service = TestBookingService();
    if (reviewDirectory != null) {
      await tester.runAsync(() async {
        for (final font in {
          'Inter': 'assets/fonts/inter/InterVariable.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          'packages/lucide_icons/Lucide':
              'packages/lucide_icons/assets/lucide.ttf',
        }.entries) {
          await (FontLoader(
            font.key,
          )..addFont(rootBundle.load(font.value))).load();
        }
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: capture,
          child: FacilityBookingScreen(
            facility: facility ?? testFacility,
            service: service,
          ),
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
      final service = await open(tester, facility: selectableRequirements);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      await select(tester);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      final notice = find.byKey(const ValueKey('booking-job-order-notice'));
      expect(notice, findsNothing);
      expect(find.text('Job Order Request'), findsNothing);
      for (final key in [
        'full_name',
        'organization',
        'contact_number',
        'email',
        'event_name',
        'purpose',
        'attendees',
      ]) {
        final textField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey('booking-field-$key')),
            matching: find.byType(TextField),
          ),
        );
        expect(textField.decoration!.labelText, isNull);
        expect(textField.decoration!.fillColor, Colors.white);
      }
      await tester.ensureVisible(find.text('Requestor Information'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'requestor-normal');
      await tester.ensureVisible(find.text('Event Information'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'event-information');
      final notes = find.descendant(
        of: find.byKey(const ValueKey('booking-field-notes')),
        matching: find.byType(TextField),
      );
      expect(find.text('Notes'), findsNothing);
      expect(
        tester.widget<TextField>(notes).decoration!.hintText,
        'Add any details or instructions for your booking.',
      );
      await tester.ensureVisible(notes);
      await tester.pumpAndSettle();
      await saveForm(tester, 'additional-notes');
      expect(find.text('Facility Rental'), findsNothing);
      expect(
        find.textContaining('After approval, CampusHub prepares'),
        findsNothing,
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
          (w) =>
              w is TextField &&
              (w.decoration?.labelText == entry.key ||
                  w.decoration?.hintText == 'Enter ${entry.key.toLowerCase()}'),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.ensureVisible(notes);
      await tester.enterText(
        notes,
        'Please arrange the chairs before the event.',
      );
      await tester.ensureVisible(find.text('Additional Requirements'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'requirements-unselected');
      final tables = find.byKey(const ValueKey('booking-requirement-Tables'));
      final others = find.byKey(const ValueKey('booking-requirement-Others'));
      final custom = find.byKey(
        const ValueKey('booking-requirement-Extension Cords'),
      );
      await tester.ensureVisible(tables);
      await tester.tap(tables);
      await tester.ensureVisible(others);
      await tester.tap(others);
      await tester.ensureVisible(custom);
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(tables).properties.checked, isTrue);
      final specifics = find.byKey(
        const ValueKey('booking-field-other_requirements'),
      );
      await tester.ensureVisible(specifics);
      await tester.enterText(specifics, 'Two wireless microphones');
      await tester.ensureVisible(find.text('Additional Requirements'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'requirements-selected');
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      expect(find.text('Review Booking'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).leading,
        isA<IconButton>(),
      );
      await saveForm(tester, 'review-booking');
      for (final key in [
        'review-schedule',
        'review-requestor',
        'review-event',
        'review-requirements-notes',
        'review-cost',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(find.text('Subject to final verification'), findsNothing);
      expect(find.text('1 pc'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('review-cost')));
      await tester.pumpAndSettle();
      await saveForm(tester, 'review-cost');
      expect(notice, findsNothing);
      expect(
        find.textContaining('After approval, CampusHub prepares'),
        findsNothing,
      );
      expect(find.text('Job Order Request'), findsNothing);
      expect(find.text('Facility Rental'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Test Requestor'), findsOneWidget);
      expect(tester.widget<Semantics>(tables).properties.checked, isTrue);
      expect(find.text('Two wireless microphones'), findsOneWidget);
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Please arrange the chairs before the event.',
      );
      await tester.tap(find.text('Next: Review Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Booking Request'));
      await tester.pumpAndSettle();
      expect(find.text('Booking Request Submitted!'), findsOneWidget);
      expect(service.submissions, 1);
      expect(service.submitted!['purpose'], 'Sports practice');
      expect(
        service.submitted!['notes'],
        'Please arrange the chairs before the event.',
      );
      expect(service.submitted!['additional_requirements'], [
        'Tables',
        'Others',
        'Extension Cords',
      ]);
      expect(
        service.submitted!['other_requirements'],
        'Two wireless microphones',
      );
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
    await tester.ensureVisible(find.text('Requestor Information'));
    await tester.pumpAndSettle();
    await saveForm(tester, 'requestor-large-text');
  });

  testWidgets(
    'booking choices use only the selected admin labels, including custom items',
    (tester) async {
      await open(
        tester,
        facility: testFacilityWithRequirements([
          'Microphone',
          'Stage',
          'Extension Cords',
          ' Stage ',
        ]),
      );
      await select(tester);
      for (final label in ['Microphone', 'Stage', 'Extension Cords']) {
        final card = find.byKey(ValueKey('booking-requirement-$label'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(card).properties.checked, isTrue);
      }
      for (final label in [
        'Chairs',
        'Tables',
        'Projector',
        'Sound System',
        'Others',
      ]) {
        expect(
          find.byKey(ValueKey('booking-requirement-$label')),
          findsNothing,
        );
      }
      expect(
        find.byKey(const ValueKey('booking-field-other_requirements')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no admin selections shows an honest empty state without default items',
    (tester) async {
      await open(tester, facility: testFacilityWithRequirements([]));
      await select(tester);
      await tester.ensureVisible(find.text('Additional Requirements'));
      expect(
        find.text(
          'No additional requirements are configured for this facility.',
        ),
        findsOneWidget,
      );
      for (final label in [
        'Chairs',
        'Tables',
        'Sound System',
        'Projector',
        'Others',
      ]) {
        expect(
          find.byKey(ValueKey('booking-requirement-$label')),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale) in [(320.0, 2.0), (390.0, 1.0)]) {
    testWidgets('requirement cards wrap and toggle at $width / $scale', (
      tester,
    ) async {
      await open(
        tester,
        width: width,
        scale: scale,
        facility: selectableRequirements,
      );
      await select(tester);
      await tester.ensureVisible(find.text('Additional Requirements'));
      await tester.pumpAndSettle();
      for (final label in [
        'Chairs',
        'Tables',
        'Sound System',
        'Projector',
        'Others',
      ]) {
        final card = find.byKey(ValueKey('booking-requirement-$label'));
        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(card).properties.checked, isTrue);
        expect(
          tester
              .widget<Material>(
                find.descendant(of: card, matching: find.byType(Material)),
              )
              .color,
          Colors.white,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(card).properties.checked, isFalse);
      }
      await tester.ensureVisible(find.text('Additional Requirements'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'requirements-$width-$scale');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing server mapping does not guess from a facility name', (
    tester,
  ) async {
    final resource = FacilityItem.fromJson({
      'id': 'TEST-OTHER',
      'name': 'Covered Court name without a mapping',
      'status': 'available',
      'facility_type': 'other',
      'booking_mode': 'slot',
      'capacity': 50,
    });
    await open(tester, facility: resource);
    await select(tester);
    expect(resource.jobOrderService, isEmpty);
    expect(
      find.text('Service to be confirmed by Facilities Admin'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('booking-job-order-notice')),
      findsNothing,
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

      // The gallery bookmark keeps the existing local saved-favorite preference.
      await tester.tap(find.byKey(const ValueKey('facility-bookmark-button')));
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
