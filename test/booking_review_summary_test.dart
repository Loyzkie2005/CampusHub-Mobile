import 'package:campushub/module_app/widgets/facilities/booking_review_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Isolated display fixture: all amounts are supplied as a Django-shaped quote.
const quote = <String, dynamic>{
  'hours': '5',
  'base_rental_amount': '3000.00',
  'additional_hour_amount': '500.00',
  'discount_amount': '1750.00',
  'discount_label': 'Internal client discount',
  'deposit_amount': '500.00',
  'total_amount': '2450.00',
  'fees': [
    {'name': 'Chairs', 'quantity': '20', 'amount': '200.00'},
  ],
};

void main() {
  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool optionalDetails = true,
    Map<String, dynamic> pricing = quote,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: BookingReviewSummary(
                  date: DateTime(2026, 11, 20),
                  start: '08:00',
                  end: '13:00',
                  quote: pricing,
                  details: {
                    'full_name':
                        'A requestor with a long name that must wrap without clipping',
                    'organization':
                        'A university organization with a long official name',
                    'contact_number': '09171234567',
                    'email':
                        'averylongunbrokenemailaddressforlayoutverification@example.university.edu',
                    'event_name':
                        'An extended event title for a university activity',
                    'purpose':
                        'A detailed purpose that remains visible in the review card.',
                    'attendees': '300',
                    'additional_requirements': optionalDetails
                        ? ['Chairs', 'Extension Cords']
                        : [],
                    'notes': optionalDetails
                        ? 'Please prepare the room before the event.'
                        : '',
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets(
      'review cards wrap long details and keep costs visible at $width/$scale',
      (tester) async {
        await open(tester, width: width, scale: scale);
        expect(find.text('Nov 20, 2026'), findsOneWidget);
        expect(find.text('Friday'), findsOneWidget);
        expect(find.text('5 hours'), findsOneWidget);
        expect(find.text('8:00 AM – 1:00 PM'), findsOneWidget);
        expect(find.text('Chairs × 20'), findsOneWidget);
        expect(find.text('Subject to final verification'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        final requirements = find.byKey(
          const ValueKey('review-requirements-notes'),
        );
        expect(
          find.descendant(of: requirements, matching: find.text('Chairs')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: requirements,
            matching: find.textContaining('20'),
          ),
          findsNothing,
        );
        for (final label in ['Email Address', 'Estimated Total']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('\u20b12450.00'), findsOneWidget);
        for (final key in [
          'review-schedule',
          'review-requestor',
          'review-event',
          'review-cost',
        ]) {
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
        }
      },
    );
  }

  testWidgets(
    'empty optional details do not create empty requirements and notes cards',
    (tester) async {
      await open(tester, optionalDetails: false);
      expect(
        find.byKey(const ValueKey('review-requirements-notes')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('review-cost')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'undiscounted quote hides discount rows and empty notes with a compact total',
    (tester) async {
      await open(
        tester,
        pricing: {
          ...quote,
          'discount_amount': '0.00',
          'discount_label': 'Internal client discount',
          'discount_note': '   ',
          'total_amount': '4200.00',
        },
      );
      expect(find.text('Internal client discount'), findsNothing);
      expect(find.text('   '), findsNothing);
      expect(
        tester.widget<Text>(find.text('Estimated Total')).style!.fontSize,
        12,
      );
      expect(
        tester.widget<Text>(find.text('\u20b14200.00')).style!.fontSize,
        15,
      );
      await tester.ensureVisible(find.text('Estimated Total'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server discount label and relevant recorded note remain unchanged',
    (tester) async {
      await open(
        tester,
        pricing: {
          ...quote,
          'discount_label':
              'Verified institutional discount for the configured rental scope',
          'discount_note':
              'Eligibility recorded by staff for this reservation.',
        },
        width: 280,
        scale: 2,
      );
      expect(
        find.text(
          'Verified institutional discount for the configured rental scope',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Eligibility recorded by staff for this reservation.'),
        findsOneWidget,
      );
      expect(find.text('-\u20b11750.00'), findsOneWidget);
      await tester.ensureVisible(find.text('Estimated Total'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
