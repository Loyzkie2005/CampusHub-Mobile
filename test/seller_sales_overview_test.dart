import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campushub/module_app/screens/seller_dashboard_page.dart';
import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'seller_test_fixtures.dart';

// Optional files are actual workspace responses exported from isolated Django
// PostgreSQL tests, never data written to the working CampusHub database.
Map<String, dynamic> salesResponse(String period) {
  final directory = Platform.environment['SELLER_SALES_REVIEW_DIR'];
  if (directory != null) {
    return jsonDecode(File('$directory/sales-$period.json').readAsStringSync())
        as Map<String, dynamic>;
  }
  final data = sellerWorkspaceFixture();
  data['analytics'] = <String, dynamic>{
    ...data['analytics'] as Map,
    'period': period,
    'label': {
      'day': 'Today',
      '7': 'Last 7 Days',
      'month': 'This Month',
    }[period],
    'revenue': '20.25',
    'completed_orders': 4,
  };
  return data;
}

final seller = AuthUser.fromJson({
  'id': 1,
  'username': 'isolated-sales-seller',
  'full_name': 'Test Seller',
  'first_name': 'Test',
  'user_type': 'student',
  'role': 'User',
  'profile_completed': true,
});

Future<void> mount(
  WidgetTester tester, {
  ValueChanged<SellerDestination>? onNavigate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SellerDashboardPage(
            user: seller,
            homeSection: true,
            onOpenDestination: onNavigate,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choosePeriod(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Filter sales period'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'campushub_chat_token': 'isolated-sales-test-token',
    }),
  );

  testWidgets(
    'real seller transport renders Django totals, filters, loading, retry and revocation',
    (tester) async {
      final periods = <String>[];
      SellerDestination? destination;
      Completer<http.Response>? gate;
      var failure = 0;
      var empty = false;
      await http.runWithClient(
        () async {
          await mount(tester, onNavigate: (value) => destination = value);
          final banner = find.byKey(
            const ValueKey('seller-total-sales-banner'),
          );
          expect(
            find.descendant(of: banner, matching: find.text('₱20.25')),
            findsOneWidget,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .join(' | '),
          );
          expect(
            find.text('Last 7 Days · Completed and paid orders'),
            findsOneWidget,
          );
          expect(periods, ['7']);
          await tester.tap(find.text('Total Sales'));
          expect(destination, SellerDestination.analytics);
          await tester.tap(find.text('Total Orders'));
          expect(destination, SellerDestination.orders);
          await tester.tap(find.text('Completed Orders'));
          expect(destination, SellerDestination.orders);
          await tester.tap(find.text('Pending Orders'));
          expect(destination, SellerDestination.orders);

          gate = Completer<http.Response>();
          await choosePeriod(tester, 'Daily');
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(
            banner,
            findsOneWidget,
          ); // Keep the last successful figures and matching label visible.
          expect(
            find.descendant(
              of: banner,
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
          expect(
            find.text('Last 7 Days · Completed and paid orders'),
            findsOneWidget,
          );
          gate!.complete(
            http.Response(
              jsonEncode(salesResponse('day')),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
          gate = null;
          await tester.pumpAndSettle();
          expect(
            find.text('Today · Completed and paid orders'),
            findsOneWidget,
          );
          await choosePeriod(tester, 'Monthly');
          await tester.pumpAndSettle();
          expect(
            find.text('This Month · Completed and paid orders'),
            findsOneWidget,
          );
          expect(periods, ['7', 'day', 'month']);

          failure = 503;
          await choosePeriod(tester, 'Weekly');
          await tester.pumpAndSettle();
          expect(find.text('Sales temporarily unavailable'), findsOneWidget);
          expect(banner, findsOneWidget);
          expect(
            find.text('This Month · Completed and paid orders'),
            findsOneWidget,
          );
          failure = 0;
          empty = true;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: banner, matching: find.text('₱0.00')),
            findsOneWidget,
          );
          expect(
            find.text('No completed paid sales in this period.'),
            findsWidgets,
          );

          failure = 403;
          await choosePeriod(tester, 'Daily');
          await tester.pumpAndSettle();
          expect(find.text('Seller access suspended'), findsOneWidget);
          expect(banner, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          expect(
            request.headers['authorization'],
            'Bearer isolated-sales-test-token',
          );
          expect(request.method, 'GET');
          if (request.url.path == '/api/seller/access-status/') {
            return http.Response('{"is_approved_seller":true}', 200);
          }
          expect(request.url.path, '/api/mobile/seller/workspace/');
          expect(request.url.queryParameters['orders_page'], '1');
          final period = request.url.queryParameters['period']!;
          periods.add(period);
          if (gate != null) return gate!.future;
          if (failure != 0) {
            return http.Response(
              jsonEncode({
                'error': failure == 403
                    ? 'Seller access suspended'
                    : 'Sales temporarily unavailable',
              }),
              failure,
            );
          }
          final data = salesResponse(period);
          if (empty) {
            data['analytics'] = <String, dynamic>{
              ...data['analytics'] as Map,
              'revenue': '0.00',
              'completed_orders': 0,
            };
            data['order_count'] = 0;
            data['overview'] = {'completed_orders': 0, 'pending_orders': 0};
            data['orders'] = [];
            data['recent_orders'] = [];
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  testWidgets(
    'unreadable sales never become fabricated zero totals and retry recovers',
    (tester) async {
      var invalid = <String, dynamic>{};
      await http.runWithClient(
        () async {
          await mount(tester);
          for (final change in [
            <String, dynamic>{},
            {'revenue': 'NaN'},
            {'revenue': '-1.00'},
            {'revenue': 'not-money'},
            {'completed_orders': 1.5},
            {'label': ''},
            {'period': 'unexpected'},
          ]) {
            invalid = Map<String, dynamic>.from(
              salesResponse('7')['analytics'] as Map,
            );
            if (change.isEmpty) {
              invalid.remove('revenue');
            } else {
              invalid.addAll(change);
            }
            await tester.tap(find.text('Retry'));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('unreadable response'),
              findsOneWidget,
              reason: tester
                  .widgetList<Text>(find.byType(Text))
                  .map((text) => text.data)
                  .join(' | '),
            );
            expect(
              find.byKey(const ValueKey('seller-total-sales-banner')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          }
          invalid = salesResponse('7')['analytics'] as Map<String, dynamic>;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('seller-total-sales-banner')),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/seller/access-status/') {
            return http.Response('{"is_approved_seller":true}', 200);
          }
          final data = salesResponse('7');
          data['analytics'] = invalid;
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );
}
