import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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

Future<void> openSchedule(
  WidgetTester tester,
  FacilityBookingService service, {
  double width = 390,
  double scale = 1,
  GlobalKey? capture,
  bool dark = false,
  FacilityItem? facility,
}) async {
  tester.view.physicalSize = Size(width, 844);
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
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Full Name',
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

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets(
      'web-style custom times preserve free bounds and quote exact choice $width/$scale',
      (tester) async {
        final service = CustomCalendarService(), capture = GlobalKey();
        await openSchedule(
          tester,
          service,
          width: width,
          scale: scale,
          capture: capture,
        );
        expect(find.text('10:00 AM - 12:00 PM'), findsNothing);
        final period = find.text('1:00 PM - 5:00 PM');
        await reach(tester, period);
        await tester.tap(period);
        await tester.pumpAndSettle();

        Future<void> chooseHour(String key, String hour) async {
          final button = find.byKey(ValueKey(key));
          await reach(tester, button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final inputs = find.byType(TextField);
          expect(inputs, findsNWidgets(2));
          expect(
            tester.getRect(find.text('OK')).right,
            lessThanOrEqualTo(width - 16),
          );
          expect(
            tester.getRect(inputs.last).right,
            lessThanOrEqualTo(width - 16),
          );
          if (hour == '12') {
            await screenshot(tester, capture, 'time-picker-$width-$scale');
          }
          await tester.enterText(inputs.first, hour);
          await tester.tap(find.text('OK'));
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
        await chooseHour('booking-start-time', '14');
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
        expect(service.quoted?['start'], '14:00');
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
    await tester.enterText(find.byType(TextField).first, '15');
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
            find.text('Weekend bookings only. Choose an available date.'),
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
      expect(find.byType(BackButton), findsOneWidget);
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
      final legend = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('schedule-legend')),
      );
      expect(legend.scrollDirection, Axis.horizontal);
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
      final slot = find.text('9:00 AM - 12:00 PM');
      await reach(tester, slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      final row = tester.widget<OutlinedButton>(
        find.ancestor(of: slot, matching: find.byType(OutlinedButton)),
      );
      expect(row.style!.side!.resolve({})!.color, bookingNavy);
      expect(find.byKey(const ValueKey('booking-start-time')), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
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
}
