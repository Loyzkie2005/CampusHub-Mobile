import 'dart:async';
import 'dart:convert';

import 'package:campushub/module_app/screens/seller_dashboard_page.dart';
import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/services/seller_application_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seller_test_fixtures.dart';
import 'seller_sales_overview_test.dart' show seller, choosePeriod;

Map<String, dynamic> response(
  String period, {
  String? revenue,
  int orders = 1,
}) {
  final data =
      jsonDecode(jsonEncode(sellerWorkspaceFixture())) as Map<String, dynamic>;
  data['analytics'] = <String, dynamic>{
    ...data['analytics'] as Map,
    'period': period,
    'label': {
      'day': 'Today',
      '7': 'Last 7 Days',
      'month': 'This Month',
    }[period],
    'revenue':
        revenue ?? {'day': '10.00', '7': '70.00', 'month': '700.00'}[period],
  };
  data['order_count'] = orders;
  return data;
}

class SalesService extends SellerApplicationService {
  final pending = <Completer<Map<String, dynamic>>>[];
  bool defer = false;
  int statusReads = 0, orderCount = 1;
  Completer<Map<String, dynamic>>? statusGate;
  @override
  Future<Map<String, dynamic>> status([String? ignoredLegacyId]) async {
    statusReads++;
    return statusGate?.future ?? Future.value({'is_approved_seller': true});
  }

  @override
  Future<Map<String, dynamic>> workspace({
    String period = '30',
    int ordersPage = 1,
  }) {
    if (!defer) return Future.value(response(period, orders: orderCount));
    final gate = Completer<Map<String, dynamic>>();
    pending.add(gate);
    return gate.future;
  }
}

Widget host(SalesService service, {int revision = 0}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SellerDashboardPage(
        user: seller,
        service: service,
        homeSection: true,
        refreshRevision: revision,
      ),
    ),
  ),
);

void main() {
  final banner = find.byKey(const ValueKey('seller-total-sales-banner'));
  String caption(String label) => '$label · Completed and paid orders';

  testWidgets(
    'period refresh preserves mounted Home, scroll and non-sales data; latest selection wins',
    (tester) async {
      final service = SalesService();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      final contentState = tester.state(find.byType(SellerWorkspaceContent));
      final original = tester
          .widget<SellerWorkspaceContent>(find.byType(SellerWorkspaceContent))
          .data;
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(20);
      await tester.pumpAndSettle();
      service.defer = true;
      await choosePeriod(tester, 'Daily');
      expect(banner, findsOneWidget);
      expect(find.text(caption('Last 7 Days')), findsOneWidget);
      expect(find.text('₱70.00'), findsOneWidget);
      expect(
        find.descendant(
          of: banner,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.state(find.byType(SellerWorkspaceContent)),
        same(contentState),
      );
      expect(position.pixels, 20);
      for (final section in [
        'Suggested Product Bundles',
        'Recent Orders',
        'Inventory Alerts',
        'Sales Trend',
      ]) {
        expect(find.text(section), findsOneWidget);
      }
      await choosePeriod(tester, 'Monthly');
      await choosePeriod(tester, 'Weekly');
      expect(service.pending.length, 3);
      service.pending[1].complete(response('month', orders: 999));
      await tester.pump();
      expect(find.text('₱700.00'), findsNothing);
      service.pending[2].complete(response('7', revenue: '77.00', orders: 999));
      await tester.pumpAndSettle();
      service.pending[0].complete(response('day', orders: 999));
      await tester.pumpAndSettle();
      expect(find.text('₱77.00'), findsOneWidget);
      expect(find.text(caption('Last 7 Days')), findsOneWidget);
      final updated = tester
          .widget<SellerWorkspaceContent>(find.byType(SellerWorkspaceContent))
          .data;
      for (final key in original.keys.where((key) => key != 'analytics')) {
        expect(
          updated[key],
          same(original[key]),
          reason: '$key must be retained',
        );
      }
      expect(position.pixels, 20);
      expect(service.statusReads, 1);
      expect(
        tester.state(find.byType(SellerWorkspaceContent)),
        same(contentState),
      );

      await choosePeriod(tester, 'Daily');
      service.pending.last.completeError(
        const SellerApplicationException('Sales connection failed'),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Sales connection failed'),
        ),
        findsOneWidget,
      );
      expect(find.text('₱77.00'), findsOneWidget);
      expect(find.text(caption('Last 7 Days')), findsOneWidget);
      expect(position.pixels, 20);
      await tester.tap(find.byKey(const ValueKey('seller-sales-retry')));
      await tester.pump();
      service.pending.last.complete(response('day'));
      await tester.pumpAndSettle();
      expect(find.text('₱10.00'), findsOneWidget);
      expect(find.text(caption('Today')), findsOneWidget);
      expect(find.text('Sales connection failed'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'normal full Home refresh supersedes sales requests and replaces full data',
    (tester) async {
      final service = SalesService();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      service.defer = true;
      await choosePeriod(tester, 'Daily');
      final oldSales = service.pending.single;
      service.defer = false;
      service.orderCount = 99;
      service.statusGate = Completer<Map<String, dynamic>>();
      // Home pull-to-refresh increments this revision after its catalog refresh.
      await tester.pumpWidget(host(service, revision: 1));
      await tester.pump();
      expect(banner, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.statusGate!.complete({'is_approved_seller': true});
      await tester.pumpAndSettle();
      oldSales.complete(response('day', revenue: '999.00'));
      await tester.pumpAndSettle();
      expect(find.text('₱999.00'), findsNothing);
      expect(find.text('₱10.00'), findsOneWidget);
      expect(
        tester
            .widget<SellerWorkspaceContent>(find.byType(SellerWorkspaceContent))
            .data['order_count'],
        99,
      );
      expect(service.statusReads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in [401, 403]) {
    testWidgets(
      'authorization $status clears seller data even from an older period request',
      (tester) async {
        final service = SalesService();
        await tester.pumpWidget(host(service));
        await tester.pumpAndSettle();
        service.defer = true;
        await choosePeriod(tester, 'Daily');
        await choosePeriod(tester, 'Monthly');
        service.pending.first.completeError(
          SellerApplicationException(
            'Seller authorization denied',
            statusCode: status,
          ),
        );
        await tester.pumpAndSettle();
        expect(banner, findsNothing);
        expect(find.byType(SellerWorkspaceContent), findsNothing);
        service.pending.last.complete(response('month'));
        await tester.pumpAndSettle();
        expect(find.text('₱700.00'), findsNothing);
        expect(find.text('Seller authorization denied'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
