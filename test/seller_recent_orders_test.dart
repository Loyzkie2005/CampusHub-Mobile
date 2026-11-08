import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/screens/seller_dashboard_page.dart';
import 'package:campushub/module_app/services/seller_application_service.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:campushub/module_app/widgets/seller/seller_recent_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seller_home_layout_test.dart' show show, reviewFonts;
import 'seller_test_fixtures.dart';
import 'seller_sales_overview_test.dart' show seller;

Map<String, dynamic> order({int id = 1}) => {
  'id': id,
  'code': 'ORDER-$id',
  'buyer_full_name': 'Actual Customer Name',
  'buyer_name': 'buyer-handle',
  'status': 'Pending',
  'status_key': 'pending',
  'payment_status': 'Unpaid',
  'fulfillment_method': 'seller_delivery',
  'fulfillment_label': 'Seller Delivery',
  'fulfillment_progress': 'Pending',
  'payment_method_label': 'Cash on Delivery',
  'delivery_destination': 'Recorded campus destination',
  'created_at': '2026-10-30T12:00:00+08:00',
  'total': '125.50',
  'product_preview': {
    'product_name': 'First Purchased Product',
    'quantity': 1,
    'thumbnail_url': '',
    'additional_items': 1,
  },
  'items': [
    {
      'product_name': 'First Purchased Product',
      'quantity': 1,
      'subtotal': '20.00',
      'variant': 'Blue',
      'thumbnail_url': '',
    },
    {
      'product_name': 'Second Purchased Product',
      'quantity': 2,
      'subtotal': '105.50',
      'variant': 'Large',
      'thumbnail_url': '',
    },
  ],
};

class RevokedOrderService extends SellerApplicationService {
  bool approved = true;
  final int denial;
  RevokedOrderService(this.denial);
  @override
  Future<Map<String, dynamic>> status([String? ignoredLegacyId]) async => {
    'is_approved_seller': approved,
  };
  @override
  Future<Map<String, dynamic>> workspace({
    String period = '30',
    int ordersPage = 1,
  }) async {
    final data = sellerWorkspaceFixture();
    data['orders'] = [order()];
    (data['analytics'] as Map)['period'] = period;
    return data;
  }

  @override
  Future<void> orderProgress(int id, String action) async {
    approved = false;
    throw SellerApplicationException(
      'Seller access denied',
      statusCode: denial,
    );
  }
}

void main() {
  for (final status in [401, 403]) {
    testWidgets(
      'order progress $status closes stale details and rechecks seller access',
      (tester) async {
        final service = RevokedOrderService(status);
        await show(
          tester,
          SellerDashboardPage(
            user: seller,
            service: service,
            homeSection: true,
          ),
        );
        final open = find.byKey(const ValueKey('recent-order-details-1'));
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        final process = find.text('Start Processing');
        await tester.scrollUntilVisible(
          process,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(process);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(find.byType(SellerWorkspaceContent), findsNothing);
        expect(find.text('Order ORDER-1'), findsNothing);
        expect(
          find.text('Approved active seller access is required.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final (width, scale) in [
    (280.0, 1.0),
    (320.0, 2.0),
    (390.0, 1.0),
    (600.0, 1.3),
  ]) {
    testWidgets(
      'product summary and labelled multi-item total fit $width/$scale with working carousel',
      (tester) async {
        await reviewFonts(tester);
        final row = order();
        Map<String, dynamic>? selected;
        await show(
          tester,
          SellerRecentOrders(
            orders: [
              row,
              {
                ...order(id: 2),
                'status': 'Completed',
                'payment_status': 'Paid',
              },
            ],
            onDetails: (value) => selected = value,
            money: (value) => '$value',
            date: (_) => 'Oct 30, 2026',
          ),
          width: width,
          scale: scale,
        );
        final first = find.byKey(const ValueKey('recent-order-1'));
        for (final text in [
          'Actual Customer Name',
          'Order #ORDER-1',
          'First Purchased Product',
          'Quantity: 1',
          'Seller Delivery',
          '+1 more item',
          'Order Total',
          '125.50',
          'Payment Status',
          'Unpaid',
          'Order Date',
          'Oct 30, 2026',
          'View Order Details',
        ]) {
          expect(
            find.descendant(of: first, matching: find.text(text)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: first, matching: find.text('20.00')),
          findsNothing,
        );
        expect(
          tester
              .widget<ProductImage>(
                find.byKey(const ValueKey('recent-order-image-1')),
              )
              .imageUrl,
          '',
        );
        expect(
          find.descendant(
            of: first,
            matching: find.byIcon(Icons.inventory_2_outlined),
          ),
          findsOneWidget,
        );
        expect(find.text('Start Processing'), findsNothing);
        expect(find.text('Mark as Paid'), findsNothing);
        final secondDot = find.byTooltip('Order 2 of 2');
        await tester.ensureVisible(secondDot);
        await tester.tap(secondDot);
        await tester.pumpAndSettle();
        final details = find.byKey(const ValueKey('recent-order-details-2'));
        await tester.ensureVisible(details);
        await tester.tap(details);
        expect(selected?['id'], 2);
        expect(
          tester.widget<PageView>(find.byType(PageView)).controller!.page,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'existing details opens without reload and fulfillment refreshes the affected order without recording payment',
    (tester) async {
      final data = sellerWorkspaceFixture();
      var current = order();
      data['orders'] = [current];
      var reloads = 0;
      final actions = <String>[];
      late StateSetter updateHost;
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return SellerWorkspaceContent(
              destination: SellerDestination.overview,
              data: data,
              sellerFirstName: 'Seller',
              homeHighlightsOnly: true,
              onNavigate: (_) {},
              onAddProduct: () {},
              onCreateBundle: (_) {},
              onPeriod: (_) {},
              onOrdersPage: (_) {},
              onReload: () {
                reloads++;
                updateHost(() {
                  current = {
                    ...current,
                    'status': 'Processing',
                    'status_key': 'processing',
                    'fulfillment_progress': 'Processing',
                  };
                  data['orders'] = [current];
                });
              },
              onOrderProgress: (id, action) async {
                actions.add('$id:$action');
              },
            );
          },
        ),
      );
      final open = find.byKey(const ValueKey('recent-order-details-1'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(reloads, 0);
      expect(actions, isEmpty);
      for (final text in [
        'Order ORDER-1',
        'Actual Customer Name',
        'First Purchased Product',
        'Second Purchased Product',
        'Blue',
        'Large',
        'Cash on Delivery',
        'Recorded campus destination',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      final process = find.text('Start Processing');
      await tester.scrollUntilVisible(
        process,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(process);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(actions, ['1:start_processing']);
      expect(reloads, 1);
      expect(current['payment_status'], 'Unpaid');
      expect(find.text('Order ORDER-1'), findsNothing);
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Start Processing'), findsNothing);
      expect(find.text('Unpaid'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ready for Seller Delivery'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready for Seller Delivery'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(reloads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unknown receiving/payment fields stay honest and fulfillment errors keep details open',
    (tester) async {
      final data = sellerWorkspaceFixture();
      data['orders'] = [
        {
          ...order(),
          'fulfillment_method': '',
          'payment_method_label': 'Not recorded',
          'fulfillment_label': '',
          'payment_status': '',
        },
      ];
      var reloads = 0;
      await show(
        tester,
        SellerWorkspaceContent(
          destination: SellerDestination.overview,
          data: data,
          sellerFirstName: 'Seller',
          homeHighlightsOnly: true,
          onNavigate: (_) {},
          onAddProduct: () {},
          onCreateBundle: (_) {},
          onPeriod: (_) {},
          onOrdersPage: (_) {},
          onReload: () => reloads++,
          onOrderProgress: (_, _) async =>
              throw const SellerApplicationException(
                'Order changed. Refresh before retrying.',
              ),
        ),
      );
      expect(find.text('Receiving method not recorded'), findsOneWidget);
      final open = find.byKey(const ValueKey('recent-order-details-1'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final process = find.text('Start Processing');
      await tester.scrollUntilVisible(
        process,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(process);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Order ORDER-1'), findsOneWidget);
      expect(
        find.text('Order changed. Refresh before retrying.'),
        findsOneWidget,
      );
      expect(reloads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
