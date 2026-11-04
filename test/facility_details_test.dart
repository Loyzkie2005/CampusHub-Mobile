import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/models/facility_detail_information.dart';
import 'package:campushub/module_app/models/facility_item.dart';
import 'package:campushub/module_app/screens/facility_details_screen.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/facility_booking_fixture.dart';

// Isolated configured examples; never imported by the application.
Map<String, dynamic> detailFixture() => {
  'id': 'DETAIL-FIXTURE',
  'name': 'Fixture Covered Court',
  'facility_type': 'covered_court',
  'facility_type_label': 'Sports Facility',
  'status': 'available',
  'capacity': 500,
  'rate': '3000.00',
  'price_type': 'base_hour',
  'booking_mode': 'slot',
  'location': 'Fixture Sports Complex',
  'description': List.filled(
    5,
    'A recorded facility description for isolated layout verification.',
  ).join(' '),
  'amenities': ['Chairs', 'Lighting', 'Parking', 'Restrooms'],
  'terms_conditions': List.filled(
    5,
    'Follow the approved schedule and keep the facility clean.',
  ).join('\n'),
  'workflow_config': {
    'capacity_min': 300,
    'pricing': {
      'base_duration': '4',
      'additional_hour_rate': '500',
      'hourly_rate': '700',
    },
    'operating_hours': {
      'monday': {'open': '08:00', 'close': '17:00'},
      'tuesday': null,
    },
    'minimum_booking_duration': '2',
    'advance_payment_days': 3,
    'damage_deposit_applicable': true,
    'damage_deposit': {'type': 'percentage', 'value': '10'},
    'additional_fees': [
      {
        'name': 'Chair rental',
        'amount': '10.50',
        'unit': 'item',
        'active': true,
      },
      {
        'name': 'Inactive fee',
        'amount': '900',
        'unit': 'booking',
        'active': false,
      },
    ],
    'discount_rules': [
      {
        'eligible_client_type': 'student',
        'discount_type': 'percentage',
        'discount_value': '5',
        'applies_to': 'base_rate',
        'active': true,
      },
    ],
  },
};

class _ScheduleService extends TestBookingService {
  int reads = 0;
  Completer<List<Map<String, dynamic>>>? pending;
  @override
  Future<List<Map<String, dynamic>>> slots(String facilityId, DateTime date) {
    reads++;
    if (pending != null) return pending!.future;
    return super.slots(facilityId, date);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder iconButton(String tooltip) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  );

  Future<void> show(
    WidgetTester tester, {
    Map<String, dynamic>? data,
    _ScheduleService? service,
    double width = 390,
    double height = 900,
    double scale = 1,
    bool reducedMotion = false,
    bool highContrast = false,
    Brightness brightness = Brightness.light,
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
              accessibleNavigation: reducedMotion,
              highContrast: highContrast,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: FacilityDetailsScreen(
            facility: FacilityItem.fromJson(data ?? detailFixture()),
            service: service ?? _ScheduleService(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  Finder rateSummary(String price) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == price,
  );

  Future<void> expandRates(WidgetTester tester) async {
    if (find
        .byKey(const ValueKey('facility-rate-details'))
        .evaluate()
        .isNotEmpty) {
      return;
    }
    final toggle = find.byKey(const ValueKey('facility-rates-toggle'));
    await scrollTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('one continuous page follows the brief and retains saved data', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(Tab), findsNothing);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.byTooltip('Chat with Facilities Admin'), findsOneWidget);
    expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
    expect(
      tester.getRect(find.text('Chat')).left,
      greaterThan(tester.getRect(find.byIcon(Icons.chat_outlined)).right),
    );
    expect(find.byType(Divider), findsNothing);
    final back = tester.widget<IconButton>(iconButton('Back'));
    expect((back.icon as Icon).icon, Icons.chevron_left_rounded);
    final headerReview = find.byKey(const ValueKey('facility-header-review'));
    expect(
      find.descendant(of: headerReview, matching: find.text('No reviews yet')),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(
            find.descendant(of: headerReview, matching: find.byType(Text)),
          )
          .bottom,
      greaterThan(tester.getRect(find.text('Fixture Covered Court')).bottom),
    );
    expect(find.text('Fixture Sports Complex'), findsOneWidget);
    expect(find.text('300–500 persons'), findsOneWidget);
    expect(find.byKey(const ValueKey('facility-facts-panel')), findsNothing);
    final sections = [
      'facility-main-info-card',
      'facility-rates-section',
      'facility-amenities-card',
      'facility-about-card',
      'facility-availability-card',
      'facility-guidelines-section',
      'facility-rules-card',
      'facility-reviews-section',
    ];
    double previous = -1;
    for (final key in sections) {
      final section = find.byKey(ValueKey(key));
      // All saved sections are mounted together; no tab interaction is needed.
      expect(section, findsOneWidget);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final top = tester.getTopLeft(section).dy + position.pixels;
      expect(top, greaterThan(previous));
      previous = top;
      await scrollTo(tester, section);
      expect(find.text('Request Booking').hitTestable(), findsOneWidget);
    }
    expect(find.text('Chairs'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('facility-reviews-section')),
        matching: find.text('No reviews yet'),
      ),
      findsOneWidget,
    );
    expect(find.text('Open for Booking'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('facility-availability-card')),
        matching: find.byKey(const ValueKey('facility-status-badge')),
      ),
      findsOneWidget,
    );
    for (final forbidden in [
      'Facility Status',
      'Check Availability',
      'Additional Fees & Discounts',
      'Chair rental',
    ]) {
      expect(find.text(forbidden), findsNothing);
    }
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reviews use supplied aggregate and missing optional content is omitted',
    (tester) async {
      await show(
        tester,
        data: {
          ...detailFixture(),
          'rating': '4.8',
          'reviews': 12,
          'amenities': ['', '  '],
          'description': '',
          'terms_conditions': '',
          'custom_facility_type': 'Saved custom facility type',
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('4.8 (12 reviews)'), findsNWidgets(2));
      final headerReview = find.byKey(const ValueKey('facility-header-review'));
      expect(
        find.descendant(
          of: headerReview,
          matching: find.text('4.8 (12 reviews)'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getRect(
              find.descendant(of: headerReview, matching: find.byType(Text)),
            )
            .bottom,
        greaterThan(tester.getRect(find.text('Fixture Covered Court')).bottom),
      );
      expect(find.text('No reviews yet'), findsNothing);
      expect(find.text('Customer feedback is not available.'), findsOneWidget);
      expect(find.text('Features & Amenities'), findsNothing);
      expect(find.text('About This Facility'), findsNothing);
      expect(find.text('Terms & Conditions'), findsNothing);
      expect(find.text('Saved custom facility type'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'gallery buttons scroll with the photo and Back closes its route',
    (tester) async {
      await show(tester);
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => FacilityDetailsScreen(
              facility: FacilityItem.fromJson(detailFixture()),
              service: _ScheduleService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isTrue);
      await tester.tap(iconButton('Back'));
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(320);
      await tester.pumpAndSettle();
      expect(iconButton('Back').hitTestable(), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-favorite-button')).hitTestable(),
        findsNothing,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      final favorite = find.byKey(const ValueKey('facility-favorite-button'));
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add to favorites'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('weekend-only card uses saved hours and honest day states', (
    tester,
  ) async {
    final data = detailFixture();
    (data['workflow_config'] as Map)['weekend_only'] = true;
    (data['workflow_config'] as Map)['operating_hours'] = {
      'saturday': {'open': '08:00', 'close': '17:00'},
      'sunday': {'open': '08:00', 'close': '17:00'},
    };
    final information = FacilityDetailInformation(FacilityItem.fromJson(data));
    expect(
      information.operatingDays
          .take(5)
          .every((day) => day.isOpen == false && day.value == 'Unavailable'),
      isTrue,
    );
    expect(
      information.operatingDays.skip(5).every((day) => day.isOpen == true),
      isTrue,
    );
    await show(tester, data: data);
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('facility-availability-card')),
    );
    expect(find.text('Weekend Only'), findsOneWidget);
    expect(find.text('Monday – Friday'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('8:00 AM – 5:00 PM'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  test('unconfigured and invalid operating days never become open days', () {
    final data = detailFixture();
    final hours = (data['workflow_config'] as Map)['operating_hours'] as Map;
    hours['thursday'] = {'open': '17:00', 'close': '08:00'};
    final days = FacilityDetailInformation(
      FacilityItem.fromJson(data),
    ).operatingDays;
    expect(days[0].isOpen, isTrue);
    expect(days[1].isOpen, isFalse);
    expect(days[2].value, 'Not configured');
    expect(days[2].isOpen, isNull);
    expect(days[3].value, 'Schedule needs review');
    expect(days[3].isOpen, isNull);
  });

  test('saved rates, fees, eligibility and schedules stay separate', () {
    final record = FacilityItem.fromJson(detailFixture());
    final info = FacilityDetailInformation(record);
    expect(info.primaryRate, '₱3,000 / first 4 hours');
    expect(info.capacity, '300–500 persons');
    expect(info.rateOptions, [
      (label: 'Additional hour', value: '₱500 / hour'),
      (label: 'Alternative hourly rate', value: '₱700 / hour'),
    ]);
    expect(
      info.schedule,
      contains((label: 'Monday', value: '8:00 AM – 5:00 PM')),
    );
    expect(info.schedule, contains((label: 'Tuesday', value: 'Closed')));
    expect(
      info.schedule,
      isNot(contains((label: 'Wednesday', value: 'Closed'))),
    );
    expect(
      info.charges,
      contains((label: 'Chair rental', value: '₱10.50 / item')),
    );
    expect(info.charges.any((row) => row.label == 'Inactive fee'), isFalse);
    expect(
      info.charges,
      contains((
        label: 'USTP student discount',
        value: '5% on base rate · eligibility verification required',
      )),
    );
    expect(
      info.charges,
      contains((
        label: 'Damage deposit',
        value: '10% of rental fee · refundable subject to inspection',
      )),
    );
    expect(record.rate, '3000.00');
    expect(record.workflowConfig['pricing']['hourly_rate'], '700');
  });

  test(
    'shared rooms retain occupancy conditions and invalid configuration stays empty',
    () {
      final shared = FacilityDetailInformation(
        FacilityItem.fromJson({
          ...detailFixture(),
          'price_type': 'person_night',
          'rate': '800',
          'workflow_config': {
            'pricing': {'partner_rate': '600', 'partner_occupancy_required': 2},
          },
        }),
      );
      expect(shared.rateOptions.single, (
        label: 'Shared room · 2 guests in one room',
        value: '₱600 / person / night',
      ));
      for (final config in [
        null,
        'invalid',
        {
          'pricing': [],
          'additional_fees': [
            null,
            'invalid',
            {'active': true, 'name': 'Bad', 'amount': 'NaN', 'unit': 'item'},
          ],
          'discount_rules': 'invalid',
          'operating_hours': [],
        },
      ]) {
        final info = FacilityDetailInformation(
          FacilityItem.fromJson({
            ...detailFixture(),
            'workflow_config': config,
          }),
        );
        expect(info.charges, isEmpty);
        expect(info.rateOptions, isEmpty);
        expect(
          info.schedule.map((row) => row.label),
          isNot(contains('Monday')),
        );
      }
      expect(
        FacilityDetailInformation(
          FacilityItem.fromJson({
            ...detailFixture(),
            'rating': '4.8',
            'reviews': 12,
          }),
        ).reviewSummary,
        '4.8 (12 reviews)',
      );
      for (final rating in ['NaN', '0', '5.1', 'invalid']) {
        expect(
          FacilityDetailInformation(
            FacilityItem.fromJson({
              ...detailFixture(),
              'rating': rating,
              'reviews': 12,
            }),
          ).reviewSummary,
          'No reviews yet',
        );
      }
    },
  );

  for (final (width, height, scale, brightness) in [
    (320.0, 900.0, 1.0, Brightness.light),
    (375.0, 900.0, 1.0, Brightness.light),
    (390.0, 900.0, 1.0, Brightness.light),
    (320.0, 900.0, 2.0, Brightness.dark),
    (844.0, 900.0, 1.0, Brightness.dark),
    (844.0, 900.0, 2.0, Brightness.dark),
    (844.0, 500.0, 1.0, Brightness.dark),
  ]) {
    testWidgets(
      'edge-to-edge clear photo and safe sticky action $width/$height/$scale/$brightness',
      (tester) async {
        await show(
          tester,
          width: width,
          height: height,
          scale: scale,
          brightness: brightness,
          reducedMotion: true,
        );
        await tester.pumpAndSettle();
        final hero = tester.getRect(
          find.byKey(const ValueKey('facility-hero-gallery')),
        );
        expect(hero.left, 0);
        expect(hero.right, width);
        expect(hero.top, 0);
        expect(hero.height, inInclusiveRange(324, 444));
        expect(
          find.byKey(const ValueKey('facility-gallery-backdrop')),
          findsNothing,
        );
        expect(find.text('Facility Details'), findsNothing);
        expect(find.textContaining('Preview Approved'), findsNothing);
        expect(find.byIcon(Icons.more_horiz), findsNothing);
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('Check Availability'), findsNothing);
        final heart = find.byKey(const ValueKey('facility-favorite-button'));
        final heartRect = tester.getRect(heart);
        expect(heartRect.top, greaterThanOrEqualTo(24));
        expect(heartRect.size.shortestSide, greaterThanOrEqualTo(48));
        final button = find.byKey(
          const ValueKey('facility-request-booking-button'),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(height - 24));
        await tester.tap(heart);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Remove from favorites'), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'facility_favorite_DETAIL-FIXTURE',
          ),
          isTrue,
        );
        await scrollTo(
          tester,
          find.byKey(const ValueKey('facility-rates-section')),
        );
        // Landscape can initially leave the information below the lazy viewport.
        // Compare document positions after the content has entered the scroll.
        final scrollOffset = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
        expect(
          tester
                  .getTopLeft(
                    find.byKey(const ValueKey('facility-main-info-card')),
                  )
                  .dy +
              scrollOffset,
          greaterThanOrEqualTo(hero.bottom),
        );
        expect(rateSummary('₱3,000 / first 4 hours'), findsOneWidget);
        await expandRates(tester);
        expect(find.text('Additional hour'), findsOneWidget);
        await scrollTo(
          tester,
          find.byKey(const ValueKey('facility-reviews-section')),
        );
        final list = find.byKey(const ValueKey('facility-details-scroll'));
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final reviews = tester.getRect(
          find.byKey(const ValueKey('facility-reviews-section')),
        );
        expect(reviews.bottom, lessThanOrEqualTo(tester.getRect(list).bottom));
        expect(
          tester.getRect(list).bottom,
          lessThan(tester.getRect(button).top),
        );
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(height - 24));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('description, terms and real request route work', (tester) async {
    final service = _ScheduleService();
    await show(tester, service: service);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Read More'));
    await tester.tap(find.text('Read More'));
    await tester.pumpAndSettle();
    expect(find.text('Read Less'), findsOneWidget);
    expect(find.text('Read Full Terms'), findsOneWidget);
    final disclosure = find.text('Read Full Terms');
    await scrollTo(tester, disclosure);
    expect(
      tester.getRect(find.text('Terms & Conditions')).top,
      greaterThan(tester.getRect(find.text('About This Facility')).top),
    );
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    final terms = tester.widget<Text>(
      find.text(detailFixture()['terms_conditions'] as String),
    );
    expect(terms.maxLines, isNull);
    final collapse = find.descendant(
      of: find.byKey(const ValueKey('facility-rules-card')),
      matching: find.text('Read Less'),
    );
    await scrollTo(tester, collapse);
    await tester.tap(collapse);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.text(detailFixture()['terms_conditions'] as String),
          )
          .maxLines,
      4,
    );
    await tester.tap(
      find.byKey(const ValueKey('facility-request-booking-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Schedule'), findsOneWidget);
    expect(service.submissions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slot requests start only in the existing booking workflow', (
    tester,
  ) async {
    final service = _ScheduleService()
      ..pending = Completer<List<Map<String, dynamic>>>();
    await show(tester, service: service);
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('facility-reviews-section')),
    );
    expect(service.reads, 0);
    await tester.tap(
      find.byKey(const ValueKey('facility-request-booking-button')),
    );
    await tester.pump();
    final now = DateTime.now();
    final remainingDays =
        DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final firstBatch = remainingDays.clamp(0, 4);
    expect(service.reads, firstBatch);
    await tester.pump(const Duration(milliseconds: 400));
    await scrollTo(tester, find.byType(CircularProgressIndicator));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pending!.completeError(StateError('Fixture connection failure'));
    await tester.pumpAndSettle();
    service.pending = null;
    await scrollTo(tester, find.text('Retry Schedule'));
    expect(find.text('Retry Schedule'), findsOneWidget);
    await tester.tap(find.text('Retry Schedule'));
    await tester.pumpAndSettle();
    expect(service.reads, firstBatch + remainingDays);
    expect(find.text('Select Schedule'), findsOneWidget);
    expect(find.text('1:00 PM - 5:00 PM'), findsOneWidget);
    expect(service.submissions, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'unavailable facilities block booking and non-slot requests keep contact flow',
    (tester) async {
      await show(tester, data: {...detailFixture(), 'status': 'maintenance'});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('facility-request-booking-button')),
            )
            .onPressed,
        isNull,
      );
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-availability-card')),
      );
      expect(find.text('Check Availability'), findsNothing);
      expect(
        find.byKey(const ValueKey('facility-view-schedule-button')),
        findsNothing,
      );
      final service = _ScheduleService();
      await show(
        tester,
        data: {
          ...detailFixture(),
          'facility_type': 'hostel',
          'booking_mode': 'room',
        },
        service: service,
      );
      await tester.pumpAndSettle();
      expect(find.text('Request Booking'), findsOneWidget);
      expect(service.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved billing methods retain their configured unit in the rate summary',
    (tester) async {
      for (final (method, expected) in [
        ('hour', '₱1,250 / hour'),
        ('day', '₱1,250 / day'),
        ('person', '₱1,250 / person'),
        ('person_night', '₱1,250 / person / night'),
        ('night', '₱1,250 / night'),
        ('session', '₱1,250 / booking'),
        ('month', '₱1,250 / month'),
        ('custom', 'Price varies / See Rates'),
      ]) {
        await show(
          tester,
          data: {
            ...detailFixture(),
            'price_type': method,
            'rate': '1250',
            'workflow_config': {
              'pricing': {'notes': 'Saved custom rate conditions.'},
            },
          },
        );
        await tester.pumpAndSettle();
        expect(rateSummary(expected), findsOneWidget);
        if (method == 'custom') await expandRates(tester);
        expect(find.text('Additional hour'), findsNothing);
        expect(
          find.text('Saved custom rate conditions.'),
          method == 'custom' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('saved requirements and client eligibility stay verbatim', (
    tester,
  ) async {
    final data = detailFixture();
    data['requirements'] = 'Present the recorded client authorization.';
    (data['workflow_config'] as Map)['eligible_clients'] = 'internal';
    await show(tester, data: data);
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('facility-guidelines-section')),
    );
    expect(find.text(data['requirements'] as String), findsOneWidget);
    expect(find.text('Internal clients only'), findsOneWidget);
    expect(find.text('3 days before use'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing photos have no invented image counter', (tester) async {
    await show(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facility-image-counter')), findsNothing);
    expect(find.bySemanticsLabel('No facility photo provided'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual uploaded-image path fills gallery and swipes', (
    tester,
  ) async {
    final asset = await rootBundle.load(
      'assets/img/ustp_oroquieta_entrance.png',
    );
    final url =
        'data:image/png;base64,${base64Encode(asset.buffer.asUint8List())}';
    await show(
      tester,
      data: {
        ...detailFixture(),
        'images': [url, 'data:image/png;base64,invalid'],
      },
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('facility-carousel-dot-0')))
          .width,
      24,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('facility-carousel-dot-1')))
          .width,
      12,
    );
    expect(
      tester.widget<ProductImage>(find.byType(ProductImage).first).fit,
      BoxFit.cover,
    );
    final image = find.byType(Image).first;
    final gallery = find.byKey(const ValueKey('facility-hero-gallery'));
    expect(
      find.ancestor(
        of: find.byType(PageView),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    // Photos retain their original colors: no gradient or image color filter.
    expect(tester.widget<Image>(image).color, isNull);
    expect(
      find.ancestor(of: image, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    expect(
      find.descendant(of: gallery, matching: find.byType(ColorFiltered)),
      findsNothing,
    );
    expect(
      find.descendant(of: gallery, matching: find.byType(ShaderMask)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: gallery,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient != null,
        ),
      ),
      findsNothing,
    );
    final activeDot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('facility-carousel-dot-0')),
    );
    expect(
      (activeDot.decoration! as BoxDecoration).color,
      const Color(0xFFFCB315),
    );
    final inactiveDot = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('facility-carousel-dot-1')),
    );
    expect(
      (inactiveDot.decoration! as BoxDecoration).color,
      Colors.white.withValues(alpha: .38),
    );
    expect(
      tester.getSize(image),
      tester.getSize(find.byKey(const ValueKey('facility-hero-gallery'))),
    );
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('facility-carousel-dot-1')))
          .width,
      24,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large galleries keep five dots and accessible scrolling controls',
    (tester) async {
      await show(
        tester,
        data: {
          ...detailFixture(),
          'images': List.filled(23, 'data:image/png;base64,invalid'),
        },
        width: 320,
        scale: 2,
        reducedMotion: true,
      );
      await tester.pumpAndSettle();
      final dots = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('facility-carousel-dot-');
      });
      expect(dots, findsNWidgets(5));
      expect(find.text('1 / 23'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(iconButton('Previous facility photo'))
            .onPressed,
        isNull,
      );
      for (final tooltip in [
        'Back',
        'Add to favorites',
        'Next facility photo',
      ]) {
        final control = tester.widget<IconButton>(iconButton(tooltip));
        expect(control.style!.backgroundColor!.resolve({}), Colors.transparent);
        expect(
          tester.getSize(iconButton(tooltip)).shortestSide,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(iconButton('Next facility photo'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 23'), findsOneWidget);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      controller.jumpToPage(11);
      await tester.pumpAndSettle();
      expect(find.text('12 / 23'), findsOneWidget);
      expect(dots, findsNWidgets(5));
      expect(
        find.byKey(const ValueKey('facility-carousel-dot-11')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('facility-carousel-dot-0')),
        findsNothing,
      );
      await tester.tap(iconButton('Previous facility photo'));
      await tester.pumpAndSettle();
      expect(find.text('11 / 23'), findsOneWidget);
      controller.jumpToPage(22);
      await tester.pumpAndSettle();
      expect(find.text('23 / 23'), findsOneWidget);
      expect(
        tester.widget<IconButton>(iconButton('Next facility photo')).onPressed,
        isNull,
      );
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(500);
      await tester.pumpAndSettle();
      for (final tooltip in [
        'Back',
        'Add to favorites',
        'Previous facility photo',
        'Next facility photo',
      ]) {
        expect(iconButton(tooltip).hitTestable(), findsNothing);
      }
      expect(find.text('Request Booking').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('white rate accordion and saved bookmark preserve real data', (
    tester,
  ) async {
    await show(tester, reducedMotion: true);
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.white);
    expect(find.byKey(const ValueKey('facility-rate-details')), findsNothing);
    expect(find.text('Additional hour'), findsNothing);
    expect(find.byKey(const ValueKey('facility-booking-price')), findsNothing);
    final bookmark = find.byKey(const ValueKey('facility-bookmark-button'));
    await tester.tap(bookmark);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(bookmark).isSelected, isTrue);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'facility_favorite_DETAIL-FIXTURE',
      ),
      isTrue,
    );
    await expandRates(tester);
    expect(find.text('₱3,000 / first 4 hours'), findsOneWidget);
    expect(find.text('₱500 / hour'), findsOneWidget);
    expect(find.text('₱700 / hour'), findsOneWidget);
    final size = find.descendant(
      of: find.byKey(const ValueKey('facility-rates-section')),
      matching: find.byType(AnimatedSize),
    );
    expect(size, findsNothing);
    await tester.tap(find.byKey(const ValueKey('facility-rates-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facility-rate-details')), findsNothing);
    await tester.tap(bookmark);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(bookmark).isSelected, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'facility_favorite_DETAIL-FIXTURE',
      ),
      isFalse,
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add to favorites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'white information and gray controls stay clear in high contrast',
    (tester) async {
      final data = {
        ...detailFixture(),
        'images': ['data:image/png;base64,invalid'],
      };
      await show(tester, data: data);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      final controlClip = find
          .ancestor(of: iconButton('Back'), matching: find.byType(ClipRRect))
          .first;
      expect(tester.getSize(controlClip), const Size(48, 48));
      expect(
        find.ancestor(
          of: find.byType(PageView),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      final back = tester.widget<IconButton>(iconButton('Back'));
      expect(back.style!.foregroundColor!.resolve({}), const Color(0xFF1A1851));
      final surface = find.byKey(
        const ValueKey('facility-information-surface'),
      );
      final gallery = find.byKey(const ValueKey('facility-hero-gallery'));
      expect(tester.getTopLeft(surface).dy, tester.getRect(gallery).bottom);
      expect(tester.widget<ColoredBox>(surface).color, Colors.white);
      for (final tooltip in ['Back', 'Add to favorites']) {
        final backing = find
            .ancestor(
              of: iconButton(tooltip),
              matching: find.byType(DecoratedBox),
            )
            .first;
        final decoration =
            tester.widget<DecoratedBox>(backing).decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFFF5F6FA));
        expect(decoration.border, isNull);
      }
      final request = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('facility-request-booking-button')),
      );
      expect(
        request.style!.backgroundColor!.resolve({}),
        const Color(0xFFFCB315),
      );

      await show(tester, data: data, highContrast: true);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.widget<ColoredBox>(surface).color, Colors.white);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('normal rate expansion keeps its short animation', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('facility-rates-toggle'));
    await scrollTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final animated = find.descendant(
      of: find.byKey(const ValueKey('facility-rates-section')),
      matching: find.byType(AnimatedSize),
    );
    expect(
      tester.widget<AnimatedSize>(animated).duration,
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Additional hour'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facility-rate-details')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more than four saved amenities scroll horizontally', (
    tester,
  ) async {
    await show(
      tester,
      data: {
        ...detailFixture(),
        'amenities': List.generate(7, (index) => 'Saved amenity $index'),
      },
    );
    await tester.pumpAndSettle();
    final strip = find.byKey(const ValueKey('facility-amenities-scroll'));
    await scrollTo(tester, strip);
    final last = find.text('Saved amenity 6');
    final before = tester.getRect(last).left;
    await tester.drag(strip, const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(last).left, lessThan(before));
    expect(find.text('Request Booking').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional actual facility-detail render evidence', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_FACILITY_DETAILS')) return;
    await tester.runAsync(() async {
      await (FontLoader('Montserrat')..addFont(
            rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final photo = await rootBundle.load(
      'assets/img/ustp_oroquieta_entrance.png',
    );
    final url =
        'data:image/png;base64,${base64Encode(photo.buffer.asUint8List())}';
    for (final (width, height, scale, brightness) in [
      (375.0, 900.0, 1.0, Brightness.light),
      (390.0, 900.0, 1.0, Brightness.light),
      (320.0, 900.0, 2.0, Brightness.dark),
      (844.0, 500.0, 1.0, Brightness.dark),
    ]) {
      final key = GlobalKey();
      await show(
        tester,
        data: {
          ...detailFixture(),
          'images': [url, url],
        },
        width: width,
        height: height,
        scale: scale,
        reducedMotion: true,
        brightness: brightness,
        capture: key,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String section) async {
        // Scrolling can recreate an offscreen memory-image fixture. Allow
        // real decoding and native tap feedback to finish before photographing it.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory(
            '../scratch/facility-details-plain-white-20261029',
          )..createSync(recursive: true);
          File(
            '${folder.path}/$section-$width-$scale.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('top');
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-rates-section')),
      );
      await expandRates(tester);
      await capture('rates-expanded');
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-availability-card')),
      );
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-operating-days')),
      );
      await capture('schedule');
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-amenities-card')),
      );
      await capture('amenities');
      await scrollTo(
        tester,
        find.byKey(const ValueKey('facility-reviews-section')),
      );
      await capture('reviews');
      expect(tester.takeException(), isNull);
    }
  });
}
