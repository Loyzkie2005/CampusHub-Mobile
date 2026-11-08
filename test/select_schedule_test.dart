import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_screen.dart';
import 'package:campushub/module_app/models/facility_item.dart';
import 'package:campushub/module_app/services/facility_booking_service.dart';
import 'package:campushub/module_app/widgets/facilities/booking_schedule_calendar.dart';
import 'package:campushub/module_app/widgets/facilities/booking_widgets.dart';
import 'package:campushub/module_app/widgets/facilities/booking_time_dialog.dart';
import 'fixtures/facility_booking_fixture.dart';

// Disposable UI responses only. Production uses Django's availability API.
List<Map<String, dynamic>> slotRows(String status) => [
  {
    'start': '09:00',
    'end': '12:00',
    'label': '9:00 AM - 12:00 PM',
    'status': status,
  },
];

class CalendarService extends TestBookingService {
  bool fail = false, staleDay = false, empty = false;
  final requests = <DateTime>[];
  Completer<List<Map<String, dynamic>>>? delayed;
  DateTime? delayedDate;
  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async {
    requests.add(date);
    if (fail) throw const BookingException('Availability connection failed.');
    if (empty) return [];
    if (delayedDate == date && delayed != null) return delayed!.future;
    if (staleDay) return slotRows('reserved');
    return switch (date.day) {
      2 => slotRows('blocked'),
      3 => slotRows('reserved'),
      4 => slotRows('maintenance'),
      5 => slotRows('class'),
      6 => [
        ...slotRows('class'),
        ...slotRows('available')
          ..first['start'] = '13:00'
          ..first['end'] = '16:00'
          ..first['label'] = '1:00 PM - 4:00 PM',
      ],
      7 => [
        {...slotRows('available').first, 'end': '08:00'},
      ],
      8 => slotRows('unavailable'),
      _ => slotRows('available'),
    };
  }
}

class CustomCalendarService extends CalendarService {
  CustomCalendarService({this.minimumMinutes = 0});
  final int minimumMinutes;
  Map<String, dynamic>? quoted;
  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async => [
    {
      'start': '08:00',
      'end': '10:00',
      'label': '8:00 AM - 10:00 AM',
      'status': 'available',
      'time_selection': 'custom',
      'minimum_duration_minutes': minimumMinutes,
    },
    {
      'start': '10:00',
      'end': '12:00',
      'label': '10:00 AM - 12:00 PM',
      'status': 'class',
      'time_selection': 'custom',
      'minimum_duration_minutes': minimumMinutes,
    },
    {
      'start': '13:00',
      'end': '17:00',
      'label': '1:00 PM - 5:00 PM',
      'status': 'available',
      'time_selection': 'custom',
      'minimum_duration_minutes': minimumMinutes,
    },
  ];

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) {
    if (path.endsWith('quote/')) quoted = Map<String, dynamic>.from(body!);
    return super.request(path, body: body);
  }
}

class ClientDaysCalendarService extends CalendarService {
  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async => [
    {
      'start': '08:00', 'end': '17:00', 'label': '8:00 AM - 5:00 PM',
      // Django can return campus hours without making them client-bookable.
      'status': 'available',
      'time_selection': 'custom', 'minimum_duration_minutes': 240,
    },
  ];
}

class ChangingClassCalendarService extends CalendarService {
  bool classActive = false;

  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async {
    Map<String, dynamic> row(String start, String end, String status) => {
      'start': start,
      'end': end,
      'label': '${bookingTime(start)} - ${bookingTime(end)}',
      'status': status,
      'time_selection': 'custom',
      'minimum_duration_minutes': 240,
    };
    return classActive
        ? [
            row('08:00', '10:00', 'unavailable'),
            row('10:00', '13:00', 'class'),
            row('13:00', '17:00', 'available'),
          ]
        : [row('08:00', '17:00', 'available')];
  }
}

class ChangingOperatingCalendarService extends CalendarService {
  bool weekends = false;
  @override
  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async => (date.weekday >= DateTime.saturday) == weekends
      ? [
          {
            'start': weekends ? '13:00' : '08:00',
            'end': '17:00',
            'label': weekends ? '1:00 PM - 5:00 PM' : '8:00 AM - 5:00 PM',
            'status': 'available',
            'time_selection': 'custom',
            'minimum_duration_minutes': 240,
          },
        ]
      : [];
}

Future<void> openSchedule(
  WidgetTester tester,
  FacilityBookingService service, {
  double width = 390,
  double height = 844,
  double scale = 1,
  GlobalKey? capture,
  bool dark = false,
  FacilityItem? facility,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  await tester.runAsync(() async {
    await (FontLoader('Montserrat')..addFont(
          rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
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
    ),
  );
  await tester.pumpAndSettle();
}

Finder nextButton() =>
    find.widgetWithText(ElevatedButton, 'Next: Booking Details');
Finder selectedSlotDot() =>
    find.byKey(const ValueKey('available-hours-inner-dot'));
DateTime nextMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1);
}

Finder day(DateTime date) => find.byKey(
  ValueKey('schedule-day-${FacilityBookingService.dateKey(date)}'),
);
Future<void> reach(
  WidgetTester tester,
  Finder target, {
  double delta = 220,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> screenshot(
  WidgetTester tester,
  GlobalKey capture,
  String name,
) async {
  final dir = Platform.environment['SELECT_SCHEDULE_REVIEW_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'changing dates never selects the sole available hours automatically',
    (tester) async {
      final service = ChangingClassCalendarService();
      final capture = GlobalKey();
      await openSchedule(tester, service, capture: capture);
      expect(selectedSlotDot(), findsNothing);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final month = nextMonth();
      await tester.tap(day(month));
      await tester.pumpAndSettle();
      final period = find.text('8:00 AM - 5:00 PM');
      await reach(tester, period);
      expect(selectedSlotDot(), findsNothing);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      await tester.tap(period);
      await tester.pumpAndSettle();
      expect(selectedSlotDot(), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-start-time')), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      final end = find.byKey(const ValueKey('booking-end-time'));
      await reach(tester, end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);
      await reach(tester, day(month.add(const Duration(days: 1))), delta: 220);
      await tester.tap(day(month.add(const Duration(days: 1))));
      await tester.pumpAndSettle();
      await reach(tester, find.text('8:00 AM - 5:00 PM'));
      expect(selectedSlotDot(), findsNothing);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      expect(find.byKey(const ValueKey('booking-end-time')), findsNothing);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(service.submissions, 0);
      await screenshot(tester, capture, 'hours-after-date-change');
    },
  );

  for (final category in [
    'covered_court',
    'function_hall',
    'hostel',
    'other',
  ]) {
    testWidgets(
      '$category reloads operating days and hours despite old client-day flags',
      (tester) async {
        final service = ChangingOperatingCalendarService();
        final facility = FacilityItem.fromJson({
          'id': 'OPERATING-$category',
          'name': category,
          'facility_type': category,
          'booking_mode': 'slot',
          'status': 'available',
          'workflow_config': {'weekend_only': true, 'allowed_booking_days': []},
        });
        final capture = GlobalKey();
        await openSchedule(
          tester,
          service,
          facility: facility,
          width: 320,
          capture: capture,
        );
        expect(
          find.text('Weekend bookings only. Choose an available date.'),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
        await tester.pumpAndSettle();
        final month = nextMonth();
        final monday = month.add(
          Duration(days: (DateTime.monday - month.weekday + 7) % 7),
        );
        final saturday = month.add(
          Duration(days: (DateTime.saturday - month.weekday + 7) % 7),
        );
        expect(tester.widget<InkResponse>(day(monday)).onTap, isNotNull);
        expect(tester.widget<InkResponse>(day(saturday)).onTap, isNull);
        await tester.tap(day(monday));
        await tester.pumpAndSettle();
        service.weekends = true;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(tester.widget<InkResponse>(day(monday)).onTap, isNull);
        expect(tester.widget<InkResponse>(day(saturday)).onTap, isNotNull);
        expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
        await tester.tap(day(saturday));
        await tester.pumpAndSettle();
        final period = find.text('1:00 PM - 5:00 PM');
        await reach(tester, period);
        expect(selectedSlotDot(), findsNothing);
        expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
        await tester.tap(period);
        await tester.pumpAndSettle();
        final start = find.byKey(const ValueKey('booking-start-time'));
        await reach(tester, start);
        expect(
          find.descendant(of: start, matching: find.text('1:00 PM')),
          findsOneWidget,
        );
        expect(service.submissions, 0);
        expect(tester.takeException(), isNull);
        if (category == 'covered_court') {
          await screenshot(tester, capture, 'operating-days-refresh-320');
        }
      },
    );
  }

  testWidgets(
    'refresh replaces changed hours without automatically choosing a window',
    (tester) async {
      final service = ChangingClassCalendarService();
      await openSchedule(tester, service);
      final period = find.text('8:00 AM - 5:00 PM');
      await reach(tester, period);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      await tester.tap(period);
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('booking-start-time'));
      await reach(tester, start);
      Finder startText(String value) =>
          find.descendant(of: start, matching: find.text(value));
      expect(startText('8:00 AM'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      service.classActive = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      final revised = find.text('1:00 PM - 5:00 PM');
      await reach(tester, revised);
      expect(selectedSlotDot(), findsNothing);
      expect(start, findsNothing);
      await tester.tap(revised);
      await tester.pumpAndSettle();
      await reach(tester, start);
      expect(startText('1:00 PM'), findsOneWidget);
      expect(find.text('Minimum booking duration: 4 hours.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      service.classActive = false;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await reach(tester, period);
      expect(selectedSlotDot(), findsNothing);
      expect(start, findsNothing);
      expect(service.submissions, 0);
    },
  );

  testWidgets(
    'refresh preserves unfinished time entry when the server window is unchanged',
    (tester) async {
      final service = ChangingClassCalendarService();
      await openSchedule(tester, service);
      final period = find.text('8:00 AM - 5:00 PM');
      await reach(tester, period);
      await tester.tap(period);
      await tester.pumpAndSettle();
      final end = find.byKey(const ValueKey('booking-end-time'));
      await reach(tester, end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AM'));
      tester
          .widget<CupertinoPicker>(
            find.byKey(const ValueKey('booking-time-hour-wheel')),
          )
          .scrollController!
          .jumpToItem(9); // 10 AM: shorter than the four-hour minimum.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: end, matching: find.text('10:00 AM')),
        findsOneWidget,
      );
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await reach(tester, end);
      expect(
        find.descendant(of: end, matching: find.text('10:00 AM')),
        findsOneWidget,
      );
      await reach(
        tester,
        find.text('Minimum booking duration is 4 hours.'),
        delta: -220,
      );
      expect(find.text('Minimum booking duration is 4 hours.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(service.submissions, 0);
    },
  );

  testWidgets(
    'stale client-day flags do not hide dates made available by Django',
    (tester) async {
      final facility = FacilityItem.fromJson({
        'id': 'CAMPUS-CLIENT-DAYS',
        'name': 'Covered Court',
        'facility_type': 'covered_court',
        'booking_mode': 'slot',
        'status': 'available',
        'workflow_config': {
          'weekend_only': true,
          'allowed_booking_days': ['sunday'],
          'operating_hours': {
            for (final day in [
              'monday',
              'tuesday',
              'wednesday',
              'thursday',
              'friday',
              'saturday',
              'sunday',
            ])
              day: {'open': '08:00', 'close': '17:00'},
          },
        },
      });
      await openSchedule(
        tester,
        ClientDaysCalendarService(),
        facility: facility,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final month = nextMonth();
      for (final weekday in [
        DateTime.monday,
        DateTime.saturday,
        DateTime.sunday,
      ]) {
        final date = month.add(
          Duration(days: (weekday - month.weekday + 7) % 7),
        );
        final cell = tester.widget<InkResponse>(day(date));
        expect(cell.onTap, isNotNull);
      }
      final sunday = month.add(
        Duration(days: (DateTime.sunday - month.weekday + 7) % 7),
      );
      await tester.tap(day(sunday));
      await tester.pumpAndSettle();
      await reach(tester, find.text('Available Hours'));
      expect(find.text('8:00 AM - 5:00 PM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hour in [0, 12, 1, 13]) {
    testWidgets('AM/PM wheel preserves and converts hour $hour', (
      tester,
    ) async {
      TimeOfDay? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showModalBottomSheet<TimeOfDay>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BookingTimeDialog(
                    title: 'Start Time',
                    initialTime: TimeOfDay(hour: hour, minute: 7),
                  ),
                );
              },
              child: const Text('Open time'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open time'));
      await tester.pumpAndSettle();
      final hourWheel = tester.widget<CupertinoPicker>(
        find.byKey(const ValueKey('booking-time-hour-wheel')),
      );
      expect(hourWheel.scrollController!.selectedItem, (hour + 11) % 12);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.textContaining(RegExp(r'(12|24).?hour')), findsNothing);
      final periodWheel = tester.widget<CupertinoPicker>(
        find.byKey(const ValueKey('booking-time-period')),
      );
      expect(periodWheel.scrollController!.selectedItem, hour < 12 ? 0 : 1);
      await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
      await tester.pumpAndSettle();
      expect(picked, TimeOfDay(hour: hour, minute: 7));

      await tester.tap(find.text('Open time'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey(hour < 12 ? 'booking-time-pm' : 'booking-time-am')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
      await tester.pumpAndSettle();
      expect(picked, TimeOfDay(hour: (hour + 12) % 24, minute: 7));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('Manila calendar date is independent of the phone timezone', () {
    final beforeMidnight = FacilityBookingService.manilaNow(
      DateTime.parse('2026-11-06T15:59:00Z'),
    );
    final afterMidnight = FacilityBookingService.manilaNow(
      DateTime.parse('2026-11-06T16:01:00Z'),
    );
    expect(FacilityBookingService.dateKey(beforeMidnight), '2026-11-06');
    expect(FacilityBookingService.dateKey(afterMidnight), '2026-11-07');
    expect(FacilityBookingService.dayStatus([]), 'not_bookable');
    expect(
      FacilityBookingService.dayStatus(slotRows('unavailable')),
      'not_bookable',
    );
    expect(FacilityBookingService.dayStatus(slotRows('blocked')), 'blocked');
    expect(
      FacilityBookingService.dayStatus([
        ...slotRows('blocked'),
        ...slotRows('available'),
      ]),
      'available',
    );
  });

  test('missing or inconsistent month response is an API error', () async {
    SharedPreferences.setMockInitialValues({
      'campushub_chat_token': 'isolated-test-token',
    });
    final month = nextMonth();
    for (final response in [
      {
        'month': FacilityBookingService.dateKey(month).substring(0, 7),
        'days': [],
      },
      {'date': FacilityBookingService.dateKey(month), 'slots': []},
    ]) {
      await http.runWithClient(
        () async {
          await expectLater(
            const FacilityBookingService().monthSlots('TEST', month),
            throwsA(isA<BookingException>()),
          );
        },
        () => MockClient((_) async => http.Response(jsonEncode(response), 200)),
      );
    }
  });

  testWidgets(
    'foreground poll invalidates a selected interval after an admin change',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final service = CalendarService();
      await openSchedule(tester, service);
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final month = nextMonth();
      await tester.tap(day(month));
      await tester.pumpAndSettle();
      final open = find.text('9:00 AM - 12:00 PM');
      await reach(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);
      service.staleDay = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(find.textContaining('Availability changed'), findsOneWidget);
      expect(
        tester
            .widget<BookingScheduleCalendar>(
              find.byType(BookingScheduleCalendar),
            )
            .month,
        month,
      );
      expect(tester.widget<InkResponse>(day(month)).onTap, isNull);
      expect(service.submissions, 0);
    },
  );

  testWidgets(
    'refresh preserves requestor fields when a schedule becomes blocked',
    (tester) async {
      final service = CalendarService();
      await openSchedule(tester, service);
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      await tester.tap(day(nextMonth()));
      await tester.pumpAndSettle();
      final chosenDate = tester
          .widget<BookingScheduleCalendar>(find.byType(BookingScheduleCalendar))
          .selected!;
      Future<void> advance() async {
        final row = find.text('9:00 AM - 12:00 PM');
        await reach(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(nextButton());
        await tester.pumpAndSettle();
      }

      await advance();
      final name = find.descendant(
        of: find.byKey(const ValueKey('booking-field-full_name')),
        matching: find.byType(TextField),
      );
      await reach(tester, name);
      await tester.enterText(name, 'Retained requestor');
      service.staleDay = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Select Schedule'), findsOneWidget);
      service.staleDay = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await reach(tester, day(chosenDate), delta: -220);
      await tester.tap(day(chosenDate));
      await tester.pumpAndSettle();
      await advance();
      await reach(tester, name);
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Retained requestor',
      );
      expect(service.submissions, 0);
    },
  );

  testWidgets(
    'returning to the route refreshes edits and cancellations without restart',
    (tester) async {
      final service = CalendarService();
      await openSchedule(tester, service);
      final screen = tester.element(find.byType(FacilityBookingScreen));
      final navigator = Navigator.of(screen);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Temporary route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      service.staleDay = true;
      navigator.pop();
      await tester.pumpAndSettle();
      var calendar = tester.widget<BookingScheduleCalendar>(
        find.byType(BookingScheduleCalendar),
      );
      expect(
        calendar.days.values.every(
          (rows) => FacilityBookingService.dayStatus(rows) == 'reserved',
        ),
        isTrue,
      );
      service.staleDay = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      calendar = tester.widget<BookingScheduleCalendar>(
        find.byType(BookingScheduleCalendar),
      );
      expect(
        calendar.days.values.any(
          (rows) => FacilityBookingService.dayStatus(rows) == 'available',
        ),
        isTrue,
      );
      service.fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      calendar = tester.widget<BookingScheduleCalendar>(
        find.byType(BookingScheduleCalendar),
      );
      expect(calendar.days, isEmpty);
      await reach(tester, find.text('Retry Schedule'));
      expect(find.text('Retry Schedule'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text('Retry Schedule'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingScheduleCalendar>(
              find.byType(BookingScheduleCalendar),
            )
            .days,
        isNotEmpty,
      );
    },
  );

  for (final (width, scale, height) in [
    (390.0, 1.0, 844.0),
    (280.0, 2.0, 844.0),
    (320.0, 1.0, 568.0),
  ]) {
    testWidgets(
      'centered swipe time dialog preserves bounds and exact minutes $width/$scale',
      (tester) async {
        final service = CustomCalendarService(), capture = GlobalKey();
        await openSchedule(
          tester,
          service,
          width: width,
          height: height,
          scale: scale,
          capture: capture,
        );
        expect(find.text('10:00 AM - 12:00 PM'), findsNothing);
        final period = find.text('1:00 PM - 5:00 PM');
        await reach(tester, period);
        await tester.tap(period);
        await tester.pumpAndSettle();

        Future<void> chooseHour(
          String key,
          String hour, {
          int minute = 0,
        }) async {
          final button = find.byKey(ValueKey(key));
          await reach(tester, button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(
            find.byKey(const ValueKey('booking-time-drag-handle')),
            findsOneWidget,
          );
          expect(find.text('Confirm'), findsNothing);
          expect(find.text('Remove'), findsNothing);
          final sheet = tester.getRect(
            find.byKey(const ValueKey('booking-time-dialog')),
          );
          expect(sheet.left, greaterThanOrEqualTo(0));
          expect(sheet.right, lessThanOrEqualTo(width));
          expect(sheet.top, greaterThanOrEqualTo(0));
          expect(sheet.bottom, closeTo(height, 1.0));
          final titleRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-title')),
          );
          expect(titleRect.center.dx, closeTo(sheet.center.dx, 1.0));
          final hourWheelRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-hour-wheel')),
          );
          final minuteWheelRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-minute-wheel')),
          );
          final periodRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-period')),
          );
          expect(hourWheelRect.top, closeTo(minuteWheelRect.top, 0.5));
          expect(minuteWheelRect.top, closeTo(periodRect.top, 0.5));
          expect(hourWheelRect.right, lessThanOrEqualTo(minuteWheelRect.left));
          expect(minuteWheelRect.right, lessThanOrEqualTo(periodRect.left));
          for (final selectionKey in [
            'booking-time-hour-selection',
            'booking-time-minute-selection',
            'booking-time-period-selection',
          ]) {
            final selectionFinder = find.byKey(ValueKey(selectionKey));
            expect(selectionFinder, findsOneWidget);
            expect(
              tester.getCenter(selectionFinder).dy,
              closeTo(hourWheelRect.center.dy, 0.5),
            );
          }
          final amFinder = find.byKey(const ValueKey('booking-time-am'));
          final pmFinder = find.byKey(const ValueKey('booking-time-pm'));
          expect(amFinder, findsOneWidget);
          expect(pmFinder, findsOneWidget);
          final amStyle = tester.widget<Text>(amFinder).style!;
          final pmStyle = tester.widget<Text>(pmFinder).style!;
          expect(
            {amStyle.fontWeight, pmStyle.fontWeight},
            {FontWeight.w600, FontWeight.w500},
          );
          final cancelRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-cancel')),
          );
          final okRect = tester.getRect(
            find.byKey(const ValueKey('booking-time-ok')),
          );
          expect(cancelRect.top, closeTo(okRect.top, 0.5));
          expect(cancelRect.right, lessThan(okRect.left));
          tester
              .widget<CupertinoPicker>(
                find.byKey(const ValueKey('booking-time-hour-wheel')),
              )
              .scrollController!
              .jumpToItem((int.parse(hour) + 11) % 12);
          await tester.tap(
            find.byKey(
              ValueKey(
                int.parse(hour) < 12 ? 'booking-time-am' : 'booking-time-pm',
              ),
            ),
          );
          tester
              .widget<CupertinoPicker>(
                find.byKey(const ValueKey('booking-time-minute-wheel')),
              )
              .scrollController!
              .jumpToItem(minute);
          await tester.pumpAndSettle();
          if (hour == '12') {
            await screenshot(tester, capture, 'time-wheel-$width-$scale');
          }
          await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
          await tester.pumpAndSettle();
        }

        // Noon is outside the selected 1-5 PM free period and must not be applied.
        await chooseHour('booking-end-time', '12');
        await reach(
          tester,
          find.textContaining('Choose a start before the end'),
          delta: -220,
        );
        expect(
          find.textContaining('Choose a start before the end'),
          findsOneWidget,
        );
        expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
        await chooseHour('booking-end-time', '15');
        await chooseHour('booking-start-time', '14', minute: 7);
        expect(
          find.textContaining('Choose a start before the end'),
          findsNothing,
        );
        expect(
          tester.widget<ElevatedButton>(nextButton()).onPressed,
          isNotNull,
        );
        await screenshot(tester, capture, 'custom-time-$width-$scale');
        await tester.tap(nextButton());
        await tester.pumpAndSettle();
        expect(service.quoted?['start'], '14:07');
        expect(service.quoted?['end'], '15:00');
        expect(service.quoted?['availability_only'], isTrue);
        expect(service.submissions, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('saved custom minimum duration blocks a shorter choice', (
    tester,
  ) async {
    final service = CustomCalendarService(minimumMinutes: 240);
    await openSchedule(tester, service);
    final period = find.text('1:00 PM - 5:00 PM');
    await reach(tester, period);
    await tester.tap(period);
    await tester.pumpAndSettle();
    await reach(tester, find.text('Minimum booking duration: 4 hours.'));
    final end = find.byKey(const ValueKey('booking-end-time'));
    await reach(tester, end);
    await tester.tap(end);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoPicker>(
          find.byKey(const ValueKey('booking-time-hour-wheel')),
        )
        .scrollController!
        .jumpToItem(2); // 3 PM; the existing end time seeds PM.
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await reach(
      tester,
      find.text('Minimum booking duration is 4 hours.'),
      delta: -220,
    );
    expect(find.text('Minimum booking duration is 4 hours.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
    expect(service.quoted, isNull);
    expect(service.submissions, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'initial date skips closed, reserved, past and malformed server periods',
    () {
      final today = DateTime(2026, 11, 4);
      final saturday = DateTime(2026, 11, 7);
      final days = {
        DateTime(2026, 11, 8): slotRows('available'),
        DateTime(2026, 11, 3): slotRows('available'),
        today: <Map<String, dynamic>>[],
        DateTime(2026, 11, 5): slotRows('reserved'),
        DateTime(2026, 11, 6): [
          {...slotRows('available').first, 'end': '08:00'},
        ],
        saturday: slotRows('available'),
      };
      expect(
        FacilityBookingService.firstAvailableDate(days, onOrAfter: today),
        saturday,
      );
      expect(
        FacilityBookingService.firstAvailableDate({
          today: <Map<String, dynamic>>[],
        }, onOrAfter: today),
        isNull,
      );
    },
  );

  testWidgets(
    'closed today initially shows the next server date and actual period',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'campushub_chat_token': 'calendar-session',
      });
      final today = DateUtils.dateOnly(DateTime.now());
      var next = today.add(const Duration(days: 1));
      while (next.weekday < DateTime.saturday) {
        next = next.add(const Duration(days: 1));
      }
      final sameMonth = next.month == today.month && next.year == today.year;
      final fixture = FacilityItem.fromJson({
        'id': 'WEEKEND-COURT',
        'name': 'Isolated weekend court',
        'facility_type': 'covered_court',
        'booking_mode': 'slot',
        'status': 'available',
        'workflow_config': {'weekend_only': true},
      });
      var posts = 0;
      final capture = GlobalKey();
      await http.runWithClient(
        () async {
          await openSchedule(
            tester,
            const FacilityBookingService(),
            facility: fixture,
            capture: capture,
          );
          expect(
            find.text('Choose an available date for your booking.'),
            findsOneWidget,
          );
          final calendar = tester.widget<BookingScheduleCalendar>(
            find.byType(BookingScheduleCalendar),
          );
          expect(calendar.selected, sameMonth ? next : null);
          expect(
            find.text('08:00 AM - 05:00 PM'),
            sameMonth ? findsOneWidget : findsNothing,
          );
          if (sameMonth) {
            expect(find.text('Choose an available date.'), findsNothing);
            await screenshot(tester, capture, 'initial-saved-weekend-schedule');
          }
          // Choosing a real date must not silently choose a period or submit.
          expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
          expect(posts, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method != 'GET') posts++;
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer calendar-session');
          expect(
            request.url.path,
            '/api/mobile/facilities/WEEKEND-COURT/availability/',
          );
          final month = DateTime.parse(
            '${request.url.queryParameters['month']}-01',
          );
          return http.Response(
            jsonEncode({
              'month': request.url.queryParameters['month'],
              'days': [
                for (
                  var n = 1;
                  n <= DateTime(month.year, month.month + 1, 0).day;
                  n++
                )
                  for (final date in [DateTime(month.year, month.month, n)])
                    {
                      'date': FacilityBookingService.dateKey(date),
                      'status':
                          date.isAfter(today) &&
                              date.weekday >= DateTime.saturday
                          ? 'available'
                          : 'not_bookable',
                      'slots':
                          date.isAfter(today) &&
                              date.weekday >= DateTime.saturday
                          ? [
                              {
                                'start': '08:00',
                                'end': '17:00',
                                'label': '08:00 AM - 05:00 PM',
                                'status': 'available',
                              },
                            ]
                          : [],
                    },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'month loader uses one existing route request with bearer and all dates',
    () async {
      SharedPreferences.setMockInitialValues({
        'campushub_chat_token': 'isolated-test-token',
      });
      final month = nextMonth();
      final requested = <String>[];
      var active = 0, peak = 0;
      await http.runWithClient(
        () async {
          final result = await const FacilityBookingService().monthSlots(
            'TEST-COURT',
            month,
          );
          expect(result.length, DateTime(month.year, month.month + 1, 0).day);
          expect(requested, [
            FacilityBookingService.dateKey(month).substring(0, 7),
          ]);
          expect(
            result.keys.every(
              (date) => date.month == month.month && date.year == month.year,
            ),
            isTrue,
          );
          expect(peak, 1);
          expect(
            result.values.every(
              (rows) => FacilityBookingService.dayStatus(rows) == 'reserved',
            ),
            isTrue,
          );
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            endsWith('/api/mobile/facilities/TEST-COURT/availability/'),
          );
          expect(
            request.headers['Authorization'],
            'Bearer isolated-test-token',
          );
          requested.add(request.url.queryParameters['month']!);
          active++;
          if (active > peak) peak = active;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          active--;
          return http.Response(
            jsonEncode({
              'month': requested.last,
              'days': [
                for (
                  var n = 1;
                  n <= DateTime(month.year, month.month + 1, 0).day;
                  n++
                )
                  {
                    'date': FacilityBookingService.dateKey(
                      DateTime(month.year, month.month, n),
                    ),
                    'status': 'reserved',
                    'slots': slotRows('reserved'),
                  },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'month failure never becomes availability and cancellation stops new reads',
    () async {
      final failing = CalendarService()..fail = true;
      await expectLater(
        failing.monthSlots('TEST', nextMonth()),
        throwsA(isA<BookingException>()),
      );
      expect(failing.requests.length, lessThanOrEqualTo(4));
      final paused = CalendarService()
        ..delayedDate = nextMonth()
        ..delayed = Completer<List<Map<String, dynamic>>>();
      var current = true;
      final result = paused.monthSlots(
        'TEST',
        nextMonth(),
        isCurrent: () => current,
      );
      current = false;
      paused.delayed!.complete(slotRows('available'));
      await result;
      expect(paused.requests.length, lessThanOrEqualTo(4));
    },
  );

  for (final (width, scale, dark) in [
    (280.0, 2.0, false),
    (320.0, 1.0, false),
    (390.0, 1.0, false),
    (768.0, 1.0, true),
  ]) {
    testWidgets('schedule layout, live statuses and selection at $width/$scale', (
      tester,
    ) async {
      final service = CalendarService(), capture = GlobalKey();
      await openSchedule(
        tester,
        service,
        width: width,
        scale: scale,
        dark: dark,
        capture: capture,
      );
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('Selected Date'), findsNothing);
      expect(find.text('Facility Status'), findsNothing);
      expect(find.text(testFacility.name), findsNothing);
      expect(
        tester.widget<BookingSteps>(find.byType(BookingSteps)).connected,
        isFalse,
      );
      expect(
        (tester.widget<AppBar>(find.byType(AppBar)).shape! as Border).bottom,
        BorderSide.none,
      );
      final legend = find.byKey(const ValueKey('schedule-legend'));
      expect(tester.widget<Row>(legend).mainAxisSize, MainAxisSize.min);
      expect(tester.getRect(legend).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(legend).right, lessThanOrEqualTo(width));
      expect(tester.getCenter(legend).dx, closeTo(width / 2, 1.0));
      final availableDy = tester
          .getCenter(
            find.descendant(of: legend, matching: find.text('Available')),
          )
          .dy;
      for (final text in ['Available', 'Closed', 'Unavailable', 'Reserved']) {
        final itemFinder = find.descendant(
          of: legend,
          matching: find.text(text),
        );
        expect(itemFinder, findsOneWidget);
        expect(tester.getCenter(itemFinder).dy, closeTo(availableDy, 0.5));
      }
      expect(
        tester
            .widget<BookingScaffold>(find.byType(BookingScaffold))
            .schedulePresentation,
        isTrue,
      );
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('schedule-previous-month')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final month = nextMonth();
      final title = find.byKey(const ValueKey('schedule-month-title'));
      expect(tester.widget<Text>(title).style!.fontFamily, scheduleFont);
      expect(tester.getCenter(title).dx, closeTo(width / 2, .1));
      expect(tester.widget<InkResponse>(day(month)).onTap, isNotNull);
      for (final n in [2, 3, 4, 5, 7, 8]) {
        expect(
          tester
              .widget<InkResponse>(day(DateTime(month.year, month.month, n)))
              .onTap,
          isNull,
        );
      }
      final prohibited = find.byKey(
        ValueKey(
          'schedule-prohibited-${FacilityBookingService.dateKey(DateTime(month.year, month.month, 2))}',
        ),
      );
      expect(
        tester.widget<CustomPaint>(prohibited).foregroundPainter,
        isA<ScheduleProhibitionPainter>(),
      );
      expect(
        find.descendant(of: prohibited, matching: find.text('2')),
        findsOneWidget,
      );
      final unavailableNumber = find.byKey(
        ValueKey(
          'schedule-number-${FacilityBookingService.dateKey(DateTime(month.year, month.month, 2))}',
        ),
      );
      expect(tester.getRect(prohibited), tester.getRect(unavailableNumber));
      final restrictedKey = FacilityBookingService.dateKey(
        DateTime(month.year, month.month, 8),
      );
      expect(
        find.byKey(ValueKey('schedule-prohibited-$restrictedKey')),
        findsNothing,
      );
      final restrictedNumber = find.descendant(
        of: find.byKey(ValueKey('schedule-number-$restrictedKey')),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(restrictedNumber).style!.color, bookingMuted);
      for (final (n, color) in [
        (1, bookingGreen),
        (3, bookingBlueDot),
        (4, scheduleMaintenance),
        (5, bookingGoldText),
      ]) {
        expect(
          find.descendant(
            of: day(DateTime(month.year, month.month, n)),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == color,
            ),
          ),
          findsOneWidget,
        );
      }
      final calendar = find.byKey(const ValueKey('booking-schedule-calendar'));
      expect(tester.getRect(calendar).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(calendar).right, lessThanOrEqualTo(width));
      await screenshot(tester, capture, 'calendar-$width-$scale');
      final chosen = DateTime(month.year, month.month, 28);
      await reach(tester, day(chosen));
      await tester.tap(day(chosen));
      await tester.pumpAndSettle();
      final selectedNumber = tester.widget<Text>(
        find.descendant(of: day(chosen), matching: find.text('28')),
      );
      expect(selectedNumber.style!.color, Colors.white);
      expect(
        find.descendant(
          of: day(chosen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == scheduleGold,
          ),
        ),
        findsNothing,
      );
      expect(selectedNumber.style!.fontVariations, const [
        FontVariation('wght', 700),
      ]);
      final numberBounds = tester.getRect(
        find.byKey(
          ValueKey('schedule-number-${FacilityBookingService.dateKey(chosen)}'),
        ),
      );
      final textBounds = tester.getRect(
        find.descendant(of: day(chosen), matching: find.text('28')),
      );
      expect(textBounds.left, greaterThanOrEqualTo(numberBounds.left));
      expect(textBounds.right, lessThanOrEqualTo(numberBounds.right));
      await screenshot(tester, capture, 'selected-date-$width-$scale');
      final slot = find.text('9:00 AM - 12:00 PM');
      await reach(tester, slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      final row = tester.widget<OutlinedButton>(
        find.ancestor(of: slot, matching: find.byType(OutlinedButton)),
      );
      expect(row.style!.side!.resolve({})!.color, bookingNavy);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      expect(selectedSlotDot(), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);
      await screenshot(tester, capture, 'selected-slot-$width-$scale');
      // Month navigation clears both selections, including on return.
      await reach(
        tester,
        find.byKey(const ValueKey('schedule-next-month')),
        delta: -220,
      );
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(find.text('9:00 AM - 12:00 PM'), findsNothing);
      expect(
        tester
            .widget<BookingScheduleCalendar>(
              find.byType(BookingScheduleCalendar),
            )
            .selected,
        isNull,
      );
      await reach(tester, find.text('Choose an available date.'));
      expect(find.text('Choose an available date.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
    'past dates are not fetched and malformed open slots are not bookable',
    () async {
      final now = DateUtils.dateOnly(DateTime.now());
      final service = CalendarService();
      final days = await service.monthSlots(
        'TEST',
        DateTime(now.year, now.month),
      );
      expect(days.keys.every((date) => !date.isBefore(now)), isTrue);
      expect(
        FacilityBookingService.isAvailableSlot({
          ...slotRows('available').first,
          'end': '08:00',
        }),
        isFalse,
      );
      expect(
        FacilityBookingService.isAvailableSlot({
          ...slotRows('available').first,
          'start': 'not-a-time',
        }),
        isFalse,
      );
      expect(FacilityBookingService.dayStatus(null), 'unknown');
    },
  );

  testWidgets('empty month stays disabled without invented availability', (
    tester,
  ) async {
    await openSchedule(tester, CalendarService()..empty = true);
    expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
    await reach(
      tester,
      find.text('No available dates in this month. Try another month.'),
    );
    expect(
      find.text('No available dates in this month. Try another month.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<BookingScheduleCalendar>(find.byType(BookingScheduleCalendar))
          .selected,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a partially occupied date offers only its actual open time slot',
    (tester) async {
      final service = CalendarService();
      await openSchedule(tester, service);
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final month = nextMonth();
      final date = DateTime(month.year, month.month, 6);
      expect(tester.widget<InkResponse>(day(date)).onTap, isNotNull);
      await tester.tap(day(date));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, '9:00 AM - 12:00 PM'),
        findsNothing,
      );
      final open = find.text('1:00 PM - 4:00 PM');
      await reach(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed month is retryable and does not expose selectable dates',
    (tester) async {
      final service = CalendarService()..fail = true;
      await openSchedule(tester, service);
      expect(find.text('Availability connection failed.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      final calendar = find.byType(BookingScheduleCalendar);
      expect(tester.widget<BookingScheduleCalendar>(calendar).days, isEmpty);
      service.fail = false;
      await reach(tester, find.text('Retry Schedule'));
      await tester.tap(find.text('Retry Schedule'));
      await tester.pumpAndSettle();
      expect(tester.widget<BookingScheduleCalendar>(calendar).days, isNotEmpty);
      expect(find.text('Availability connection failed.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a day that becomes reserved is disabled after live revalidation',
    (tester) async {
      final service = CalendarService();
      await openSchedule(tester, service);
      await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
      await tester.pumpAndSettle();
      final date = nextMonth();
      service.staleDay = true;
      await tester.tap(day(date));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('date is no longer available'),
        findsOneWidget,
      );
      expect(tester.widget<InkResponse>(day(date)).onTap, isNull);
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(service.submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stale day response cannot refill slots after changing month', (
    tester,
  ) async {
    final service = CalendarService();
    await openSchedule(tester, service);
    await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
    await tester.pumpAndSettle();
    final date = nextMonth();
    service.delayedDate = date;
    service.delayed = Completer<List<Map<String, dynamic>>>();
    await tester.tap(day(date));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-next-month')));
    await tester.pumpAndSettle();
    service.delayed!.complete(slotRows('available'));
    await tester.pumpAndSettle();
    expect(find.text('9:00 AM - 12:00 PM'), findsNothing);
    expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Covered Court flexible window requires explicit selection, validates 4h minimum and shows summary without overlap',
    (tester) async {
      final courtFacility = FacilityItem.fromJson({
        'id': 'COVERED-COURT-SCHEDULE',
        'name': 'Covered Court',
        'facility_type': 'covered_court',
        'booking_mode': 'slot',
        'status': 'available',
        'workflow_config': {
          'weekend_only': true,
          'operating_hours': {'start': '08:00', 'end': '17:00'},
          'minimum_booking_duration': 240,
        },
      });
      final service = CustomCalendarService(minimumMinutes: 240);
      final capture = GlobalKey();
      await openSchedule(
        tester,
        service,
        width: 320,
        facility: courtFacility,
        capture: capture,
      );
      // Verify 4-step progress indicator is fully visible below AppBar without clipping.
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      final stepsRect = tester.getRect(find.byType(BookingSteps));
      expect(stepsRect.top, greaterThanOrEqualTo(appBarBottom));
      for (final stepLabel in ['Schedule', 'Details', 'Review', 'Submit']) {
        final labelRect = tester.getRect(find.text(stepLabel));
        expect(labelRect.left, greaterThanOrEqualTo(0));
        expect(labelRect.right, lessThanOrEqualTo(320));
      }

      // Partially occupied date shows remaining available hours indicator.
      await reach(tester, find.text('Available Hours'));
      expect(find.text('Available Hours'), findsOneWidget);
      await reach(
        tester,
        find.text('Remaining available hours for this date.'),
      );
      expect(
        find.text('Remaining available hours for this date.'),
        findsOneWidget,
      );
      final period = find.text('1:00 PM - 5:00 PM');
      await reach(tester, period);
      await tester.tap(period);
      await tester.pumpAndSettle();

      // Selecting the available window alone does not silently assume full-day booking.
      expect(find.text('Select Booking Time'), findsOneWidget);
      expect(find.text('Minimum booking duration: 4 hours.'), findsOneWidget);
      expect(find.text('Selected Duration'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Confirm my selected booking time'), findsNothing);
      final startRect = tester.getRect(
        find.byKey(const ValueKey('booking-start-time')),
      );
      final endRect = tester.getRect(
        find.byKey(const ValueKey('booking-end-time')),
      );
      expect(startRect.top, endRect.top);
      expect(startRect.right, lessThan(endRect.left));
      expect(startRect.height, greaterThanOrEqualTo(48));
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('schedule-selection-summary')),
        findsNothing,
      );

      final startBtn = find.byKey(const ValueKey('booking-start-time'));
      await reach(tester, startBtn);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();
      // Swiping the minute wheel changes only the pending dialog value.
      final minuteWheel = find.byKey(
        const ValueKey('booking-time-minute-wheel'),
      );
      await tester.drag(minuteWheel, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoPicker>(minuteWheel)
            .scrollController!
            .selectedItem,
        greaterThan(0),
      );
      await tester.tap(find.byKey(const ValueKey('booking-time-cancel')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNull);

      // Valid 4-hour interval (1:00 PM - 5:00 PM) enables Next and shows compact summary.
      final endBtn = find.byKey(const ValueKey('booking-end-time'));
      await reach(tester, endBtn);
      await tester.tap(endBtn);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester
            .widget<CupertinoPicker>(
              find.byKey(const ValueKey('booking-time-minute-wheel')),
            )
            .scrollController!
            .selectedItem,
        0,
      );
      await screenshot(tester, capture, 'court-time-wheel-320');
      await tester.tap(find.byKey(const ValueKey('booking-time-ok')));
      await tester.pumpAndSettle();

      final summary = find.byKey(const ValueKey('schedule-selection-summary'));
      await reach(tester, summary);
      expect(summary, findsOneWidget);
      expect(
        find.descendant(of: summary, matching: find.text('Selected Date')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('Total Duration')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('4 hours')),
        findsOneWidget,
      );
      expect(tester.widget<ElevatedButton>(nextButton()).onPressed, isNotNull);
      await screenshot(tester, capture, 'court-times-no-confirm-320');

      // Verify bottom Next button does not overlap summary when scrolled to bottom.
      expect(
        tester.getRect(summary).bottom,
        lessThanOrEqualTo(tester.getRect(nextButton()).top),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(nextButton());
      await tester.pumpAndSettle();
      expect(service.quoted?['start'], '13:00');
      expect(service.quoted?['end'], '17:00');
      expect(service.quoted?['availability_only'], isTrue);
      expect(service.submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
