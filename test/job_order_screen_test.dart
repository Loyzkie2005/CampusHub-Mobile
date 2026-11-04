import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/screens/facilities/job_order_screen.dart';

void main() {
  test(
    'Job Order navigation denies unrelated origins, bookings, and schemes',
    () {
      final base = Uri.parse('https://campushub.example');
      const prefix = '/api/mobile/bookings/BOOKING/job-order/';
      expect(
        jobOrderNavigationAllowed('${base.origin}${prefix}view/', base, prefix),
        isTrue,
      );
      expect(
        jobOrderNavigationAllowed(
          'blob:${base.origin}/local-pdf',
          base,
          prefix,
        ),
        isTrue,
      );
      for (final target in [
        'https://unrelated.example${prefix}view/',
        '${base.origin}/admin-dashboard/',
        '${base.origin}$prefix../other/',
        'about:blank',
        'javascript:alert(1)',
        'data:text/html,untrusted',
        'blob:https://unrelated.example/file',
      ]) {
        expect(
          jobOrderNavigationAllowed(target, base, prefix),
          isFalse,
          reason: target,
        );
      }
    },
  );
  testWidgets(
    'unsupported platforms show an honest signing message',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: JobOrderScreen(bookingId: 'ISOLATED-TEST')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Open Job Order signing in the Android or iOS app.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'missing mobile authentication does not open a signing WebView',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: JobOrderScreen(bookingId: 'ISOLATED-TEST')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
