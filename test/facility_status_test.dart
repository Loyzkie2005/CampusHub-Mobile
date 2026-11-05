import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/models/facility_item.dart';
import 'package:campushub/module_app/screens/facility_details_screen.dart';
import 'package:campushub/module_app/screens/facility_screen.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_screen.dart';
import 'package:campushub/module_app/services/facility_service.dart';
import 'package:campushub/module_app/widgets/facilities/booking_widgets.dart';
import 'package:campushub/module_app/widgets/facilities/facility_status_badge.dart';
import 'package:campushub/module_app/widgets/home/home_preview_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/facility_booking_fixture.dart';

const statuses = {
  'available': 'Open for Booking',
  'unavailable': 'Temporarily Unavailable',
  'maintenance': 'Under Maintenance',
  'inactive': 'Inactive',
};

Map<String, dynamic> record(String status) => {
  'id': 'fixture-status-court',
  'name': 'Fixture Status Court',
  'status': status,
  'facility_type': 'covered_court',
  'booking_mode': 'slot',
  'capacity': 50,
  'rate': '500',
  'price_type': 'hour',
  'slots': '08:00-12:00;13:00-17:00',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> refresh(WidgetTester tester) async {
    final done = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await done;
  }

  FilledButton requestButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
        find.byKey(const ValueKey('facility-request-booking-button')),
      );

  test(
    'Django status codes map correctly and unknown values never open booking',
    () {
      for (final entry in statuses.entries) {
        final item = FacilityItem.fromJson(record(entry.key));
        expect(item.status, entry.value);
        expect(item.isOpenForBooking, entry.key == 'available');
      }
      for (final legacy in ['reserved', 'occupied']) {
        expect(
          FacilityItem.fromJson(record(legacy)).status,
          'Temporarily Unavailable',
        );
      }
      for (final missing in [null, '', 'unexpected']) {
        final item = FacilityItem.fromJson({
          ...record('available'),
          'status': missing,
        });
        expect(item.status, 'Status unavailable');
        expect(item.isOpenForBooking, isFalse);
      }
    },
  );

  for (final entry in statuses.entries) {
    testWidgets(
      '${entry.key}: card details navigation, matching badge and booking eligibility',
      (tester) async {
        final facility = FacilityItem.fromJson(record(entry.key));
        await show(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: IntrinsicHeight(
                child: FacilityPreviewCard(facility: facility),
              ),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(FacilityStatusBadge), findsOneWidget);
        final button = find.widgetWithText(TextButton, 'View Details');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(FacilityDetailsScreen), findsOneWidget);
        expect(
          tester
              .widget<FacilityStatusBadge>(find.byType(FacilityStatusBadge))
              .status,
          entry.value,
        );
        expect(
          requestButton(tester).onPressed,
          entry.key == 'available' ? isNotNull : isNull,
        );
        if (entry.key != 'available') {
          expect(find.text(facility.bookingStatusExplanation), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('all badges wrap at large text sizes on a narrow phone', (
    tester,
  ) async {
    for (final status in statuses.keys) {
      await show(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: FacilityPreviewCard(
                facility: FacilityItem.fromJson(record(status)),
              ),
            ),
          ),
        ),
        scale: 2,
      );
      expect(find.text(statuses[status]!), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'refreshed admin statuses reach listing, details and request eligibility',
    (tester) async {
      var status = 'available';
      Future<FacilityServiceResult> load() async =>
          FacilityServiceResult(success: true, facilities: [record(status)]);
      await show(tester, Scaffold(body: FacilitiesPage(loadFacilities: load)));
      for (final entry in statuses.entries) {
        status = entry.key;
        await refresh(tester);
        expect(find.text(entry.value), findsOneWidget);
        await tester.ensureVisible(find.text('View Details'));
        await tester.tap(find.text('View Details'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FacilityStatusBadge>(find.byType(FacilityStatusBadge))
              .status,
          entry.value,
        );
        expect(
          requestButton(tester).onPressed,
          status == 'available' ? isNotNull : isNull,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'already-open details refresh status and block booking on failed or missing refresh',
    (tester) async {
      var result = FacilityServiceResult(
        success: true,
        facilities: [record('maintenance')],
      );
      await show(
        tester,
        FacilityDetailsScreen(
          facility: FacilityItem.fromJson(record('available')),
          loadFacilities: () async => result,
        ),
      );
      expect(requestButton(tester).onPressed, isNotNull);
      for (final entry in statuses.entries) {
        result = FacilityServiceResult(
          success: true,
          facilities: [record(entry.key)],
        );
        await refresh(tester);
        expect(
          tester
              .widget<FacilityStatusBadge>(find.byType(FacilityStatusBadge))
              .status,
          entry.value,
        );
        expect(
          requestButton(tester).onPressed,
          entry.key == 'available' ? isNotNull : isNull,
        );
      }
      result = const FacilityServiceResult(success: true);
      await refresh(tester);
      expect(requestButton(tester).onPressed, isNull);
      expect(find.textContaining('no longer listed'), findsOneWidget);
      result = const FacilityServiceResult(
        success: false,
        message: 'Fixture refresh failed',
      );
      await refresh(tester);
      expect(requestButton(tester).onPressed, isNull);
      expect(find.text('Fixture refresh failed'), findsOneWidget);
      result = FacilityServiceResult(
        success: true,
        facilities: [record('available')],
      );
      await refresh(tester);
      expect(requestButton(tester).onPressed, isNotNull);
      expect(find.text('Fixture refresh failed'), findsNothing);
    },
  );

  testWidgets(
    'closed facilities cannot advance a directly opened booking screen',
    (tester) async {
      for (final code in ['unavailable', 'maintenance', 'inactive']) {
        final facility = FacilityItem.fromJson(record(code));
        final service = TestBookingService();
        await show(
          tester,
          FacilityBookingScreen(facility: facility, service: service),
        );
        await tester.scrollUntilVisible(
          find.text('1:00 PM - 5:00 PM'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1:00 PM - 5:00 PM'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BookingButton>(
                find.widgetWithText(BookingButton, 'Next: Booking Details'),
              )
              .onPressed,
          isNull,
        );
        expect(service.submissions, 0);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('optional real-font status card captures', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_FACILITY_STATUSES')) return;
    await tester.runAsync(() async {
      for (final (family, path) in [
        ('Poppins', 'assets/fonts/poppins/Poppins-Regular.ttf'),
        ('Inter', 'assets/fonts/inter/InterVariable.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(path))).load();
      }
    });
    for (final status in statuses.keys) {
      final key = GlobalKey();
      await show(
        tester,
        Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: FacilityPreviewCard(
                  facility: FacilityItem.fromJson(record(status)),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final folder = Directory('../scratch/facility-status')
          ..createSync(recursive: true);
        File(
          '${folder.path}/$status.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
