import 'dart:io';
import 'dart:ui' as ui;
import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/screens/home_page.dart';
import 'package:campushub/module_app/models/product_item.dart';
import 'package:campushub/module_app/widgets/seller/seller_recent_orders.dart';
import 'package:campushub/module_app/widgets/seller/seller_sales_trend.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:campushub/module_app/widgets/home/home_preview_cards.dart';
import 'package:campushub/module_app/widgets/profile/profile_widgets.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:campushub/module_app/widgets/seller/seller_inventory_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_test_fixtures.dart';
import 'seller_test_fixtures.dart';

Map<String, dynamic> layoutData({int orders = 7, bool long = false}) {
  final data = sellerWorkspaceFixture();
  if (long) (data['analytics'] as Map)['revenue'] = '1234567890123.45';
  final order = Map<String, dynamic>.from((data['orders'] as List).first);
  data['orders'] = List.generate(
    orders,
    (i) => {
      ...order,
      'id': 100 - i,
      'code': long
          ? 'CAMPUSHUB-VERY-LONG-ORDER-REFERENCE-1000000000000-$i'
          : 'ORDER-${100 - i}',
      'buyer_name': long
          ? 'A buyer with a very long recorded family name and given name'
          : 'Buyer $i',
      'created_at': '2026-10-${28 - i}T08:00:00+08:00',
      'total': '${40 + i}.00',
    },
  );
  data['inventory'] = List.generate(
    4,
    (i) => {
      'product_id': i + 1,
      'product_name': long
          ? 'A very long product name with a large quantity of descriptive words $i'
          : 'Stock item $i',
      'sku': 'STOCK-$i',
      'on_hand': 4,
      'reserved': 2,
      'available': 2,
      'threshold': 3,
      'status': 'low_stock',
      'status_label': 'Low Stock',
    },
  );
  return data;
}

Widget content(
  Map<String, dynamic> data, {
  ValueChanged<SellerDestination>? onNavigate,
}) => SellerWorkspaceContent(
  destination: SellerDestination.overview,
  data: data,
  sellerFirstName: 'Test',
  homeHighlightsOnly: true,
  onNavigate: onNavigate ?? (_) {},
  onAddProduct: () {},
  onCreateBundle: (_) {},
  onReload: () {},
  onPeriod: (_) {},
  onOrdersPage: (_) {},
);

Future<void> reviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final font in {
      'Montserrat': 'assets/fonts/Montserrat-VariableFont_wght.ttf',
      'Inter': 'assets/fonts/inter/InterVariable.ttf',
      'Poppins': 'assets/fonts/poppins/Poppins-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/iconsax_flutter/FlutterIconsax':
          'packages/iconsax_flutter/fonts/FlutterIconsax.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
}

Future<void> show(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 844,
  double scale = 1,
  GlobalKey? capture,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ProfileTheme(
        child: Scaffold(
          body: RepaintBoundary(
            key: capture,
            child: ColoredBox(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reach(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .1);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'recent summary shows purchased product and preserves the complete detail record',
    (tester) async {
      final row = <String, dynamic>{
        ...(layoutData(orders: 1)['orders'] as List).single as Map,
        'buyer_name': 'buyer-handle',
        'buyer_full_name': 'Alexandria Maria Dela Cruz',
        'product_preview': {
          'product_name': 'Full Purchased Product Name and Recorded Variant',
          'quantity': 3,
          'thumbnail_url': '/media/orders/actual-thumbnail.png',
          'additional_items': 2,
        },
      };
      Map<String, dynamic>? opened;
      await show(
        tester,
        SellerRecentOrders(
          orders: [row],
          onDetails: (value) => opened = value,
          money: (value) => '$value',
          date: (value) => '$value',
        ),
      );
      final buyer = find.text('Alexandria Maria Dela Cruz');
      final product = find.text(
        'Full Purchased Product Name and Recorded Variant',
      );
      expect(buyer, findsOneWidget);
      expect(find.text('buyer-handle'), findsNothing);
      expect(tester.widget<Text>(buyer).maxLines, 2);
      expect(product, findsOneWidget);
      expect(
        tester.getRect(find.text('Order #ORDER-100')).top,
        greaterThanOrEqualTo(tester.getRect(buyer).bottom),
      );
      expect(
        tester.widget<Text>(find.text('Order #ORDER-100')).style!.fontSize,
        lessThan(tester.widget<Text>(buyer).style!.fontSize!),
      );
      expect(find.byType(ProductImage), findsOneWidget);
      expect(find.text('Quantity: 3'), findsOneWidget);
      expect(find.text('+2 more items'), findsOneWidget);
      expect(find.text('Order Total'), findsOneWidget);
      expect(
        tester.getRect(find.text('Order #ORDER-100')).bottom,
        lessThan(tester.getRect(find.text('Order Total')).top),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('recent-order-100'))).height,
        lessThan(450),
      );
      await tester.tap(find.text('View Order Details'));
      expect(identical(opened, row), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy item records show first product without changing buyer fallback',
    (tester) async {
      final row = <String, dynamic>{
        ...(layoutData(orders: 1)['orders'] as List).single as Map,
        'buyer_full_name': '',
        'buyer_name': 'unverified-handle',
        'items': [
          {
            'product_name': 'First Recorded Product',
            'quantity': 4,
            'image_url': '',
          },
          {'product_name': 'Second Recorded Product', 'quantity': 2},
        ],
      };
      await show(
        tester,
        SellerRecentOrders(
          orders: [row],
          onDetails: (_) {},
          money: (value) => '$value',
          date: (value) => '$value',
        ),
      );
      expect(find.text('Buyer not recorded'), findsOneWidget);
      expect(find.text('unverified-handle'), findsNothing);
      expect(find.text('First Recorded Product'), findsOneWidget);
      expect(find.text('Quantity: 4'), findsOneWidget);
      expect(find.text('+1 more item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'carousel View Details retains full product, variant, quantity and recorded image',
    (tester) async {
      final data = layoutData(orders: 1);
      final row = (data['orders'] as List).single as Map<String, dynamic>;
      row['buyer_full_name'] = 'Recorded Buyer Full Name';
      row['total'] = '60.00';
      row['items'] = [
        {
          'product_name': 'Full Purchased Product Name',
          'quantity': 3,
          'variant': 'Large / Blue',
          'subtotal': '60.00',
        },
      ];
      row['product_preview'] = {
        'thumbnail_url': '/media/orders/recorded-product.png',
      };
      await show(tester, content(data));
      final carousel = find.byType(SellerRecentOrders);
      expect(
        find.descendant(
          of: carousel,
          matching: find.text('Full Purchased Product Name'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: carousel, matching: find.byType(ProductImage)),
        findsOneWidget,
      );
      final details = find.descendant(
        of: carousel,
        matching: find.text('View Order Details'),
      );
      await reach(tester, details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Full Purchased Product Name'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Variant'), findsOneWidget);
      expect(find.text('Large / Blue'), findsOneWidget);
      final photo = find.byKey(const ValueKey('order-item-image-100-0'));
      expect(
        tester.widget<ProductImage>(photo).imageUrl,
        '/media/orders/recorded-product.png',
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: carousel,
          matching: find.text('Full Purchased Product Name'),
        ),
        findsOneWidget,
      );
      expect(find.text('Recorded Buyer Full Name'), findsOneWidget);
    },
  );

  testWidgets(
    'inventory alerts use supplied values and thresholds and exclude expired/healthy records',
    (tester) async {
      final data = layoutData(orders: 0);
      final base = Map<String, dynamic>.from(
        (data['inventory'] as List).first as Map,
      );
      data['inventory'] = [
        {
          ...base,
          'sku': 'LOW-A',
          'product_name': 'Actual Low Product',
          'on_hand': 7,
          'reserved': 3,
          'available': 4,
          'threshold': 7,
        },
        {
          ...base,
          'sku': 'OUT-B',
          'product_name': 'Actual Empty Product',
          'status': 'out_of_stock',
          'status_label': 'Out of Stock',
          'on_hand': 0,
          'reserved': 0,
          'available': 0,
          'threshold': 12,
        },
        {...base, 'product_name': 'Expired Only', 'status': 'expired'},
        {...base, 'product_name': 'Healthy Product', 'status': 'in_stock'},
      ];
      await show(tester, content(data));
      expect(find.byType(SellerInventoryAlert), findsNWidgets(2));
      expect(find.text('Expired Only'), findsNothing);
      expect(find.text('Healthy Product'), findsNothing);
      final low = find.byKey(const ValueKey('inventory-alert-LOW-A'));
      expect(
        find.descendant(of: low, matching: find.text('SKU: LOW-A')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('inventory-available-LOW-A')),
            )
            .data,
        '4',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('inventory-threshold-LOW-A')),
            )
            .data,
        '7',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('inventory-threshold-OUT-B')),
            )
            .data,
        '12',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('inventory-available-LOW-A')),
            )
            .style!
            .fontSize,
        26,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('inventory-status-LOW-A')))
            .right,
        closeTo(tester.getRect(low).right - 15, 1),
      );
      final row = tester
          .widget<SellerInventoryAlert>(find.byType(SellerInventoryAlert).first)
          .row;
      expect(row['reserved'], 3);
      expect(tester.takeException(), isNull);
    },
  );
  for (final (status, label, background, foreground) in [
    ('pending', 'Pending', const Color(0xFFFFF3D6), const Color(0xFF8C5900)),
    (
      'processing',
      'Processing',
      const Color(0xFFEAF0FF),
      const Color(0xFF24428A),
    ),
    ('completed', 'Completed', const Color(0xFFF1F1F5), HomeAppColors.navy),
    ('cancelled', 'Cancelled', const Color(0xFFF1F1F5), HomeAppColors.navy),
    (
      'ready_for_pickup',
      'Ready for Pickup',
      const Color(0xFFEAF0FF),
      const Color(0xFF24428A),
    ),
    (
      'unclassified',
      'Recorded Status',
      const Color(0xFFF1F1F5),
      HomeAppColors.navy,
    ),
  ]) {
    testWidgets('recent-order $status badge hugs its label and aligns right', (
      tester,
    ) async {
      await reviewFonts(tester);
      final row = <String, dynamic>{
        ...(layoutData(orders: 1)['orders'] as List).single as Map,
        'status_key': status,
        'status': label,
      };
      final capture = GlobalKey();
      await show(
        tester,
        SellerRecentOrders(
          orders: [row],
          money: (value) => '$value',
          date: (value) => '$value',
          onDetails: (_) {},
        ),
        width: 375,
        capture: capture,
      );
      final badge = find.byKey(const ValueKey('recent-order-status-100'));
      final header = find.byKey(const ValueKey('recent-order-header-100'));
      final badgeText = find.descendant(of: badge, matching: find.byType(Text));
      final decoration =
          tester.widget<Container>(badge).decoration! as BoxDecoration;
      expect(decoration.color, background);
      expect(decoration.borderRadius, BorderRadius.circular(999));
      expect(
        tester.widget<Container>(badge).padding,
        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      );
      expect(tester.widget<Text>(badgeText).data, label);
      expect(tester.widget<Text>(badgeText).style!.color, foreground);
      expect(
        tester.getSize(badge).width,
        closeTo(tester.getSize(badgeText).width + 22, 0.1),
      );
      expect(
        tester.getSize(badge).height,
        closeTo(tester.getSize(badgeText).height + 12, 0.1),
      );
      expect(
        tester.getRect(badge).right,
        closeTo(tester.getRect(header).right, 0.1),
      );
      expect(
        tester.getRect(badge).top,
        closeTo(tester.getRect(header).top, 0.1),
      );
      expect(
        tester.getSize(badge).width,
        lessThan(tester.getSize(header).width / 2),
      );
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['SELLER_HOME_REVIEW_DIR'];
      if (directory != null) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          File(
            '$directory/badge-$status.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
    });
  }
  for (final (width, scale) in [(280.0, 1.0), (375.0, 1.0), (320.0, 2.0)]) {
    testWidgets('sales menu stays below its filter at $width/$scale', (
      tester,
    ) async {
      await reviewFonts(tester);
      for (final period in ['day', '7', 'month']) {
        final data = layoutData();
        (data['analytics'] as Map)['period'] = period;
        (data['analytics'] as Map)['label'] = {
          'day': 'Today',
          '7': 'Last 7 Days',
          'month': 'This Month',
        }[period]!;
        final capture = GlobalKey();
        await show(
          tester,
          content(data),
          width: width,
          scale: scale,
          capture: capture,
        );
        final filter = find.byTooltip('Filter sales period');
        await reach(tester, filter);
        final trigger = tester.getRect(filter);
        final surface = tester.widget<Container>(
          find.byKey(const ValueKey('seller-sales-period-control')),
        );
        final decoration = surface.decoration! as BoxDecoration;
        final selectedLabel = find.descendant(
          of: find.byKey(const ValueKey('seller-sales-period-control')),
          matching: find.byType(Text),
        );
        final selectedText = tester.widget<Text>(selectedLabel);
        expect(selectedText.maxLines, 1);
        expect(selectedText.softWrap, isFalse);
        final selectedRender = tester.renderObject<RenderParagraph>(
          selectedLabel,
        );
        expect(selectedRender.didExceedMaxLines, isFalse);
        expect(
          selectedRender.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(selectedRender.size.width + 0.1),
        );
        expect(decoration.color, Colors.white);
        expect(decoration.borderRadius, BorderRadius.circular(50));
        expect(decoration.border, Border.all(color: HomeAppColors.border));
        expect(decoration.gradient, isNull);
        expect(decoration.boxShadow, isNull);
        expect(trigger.height, greaterThanOrEqualTo(48));
        expect(trigger.width, greaterThanOrEqualTo(94));
        expect(
          trigger.right,
          closeTo(
            tester
                .getRect(
                  find.byKey(const ValueKey('seller-sales-overview-header')),
                )
                .right,
            0.1,
          ),
        );
        if (scale == 1) {
          expect(trigger.width, closeTo(94, 4));
          expect(trigger.height, 48);
          expect(
            tester.getCenter(find.text('Sales Overview')).dy,
            closeTo(trigger.center.dy, 0.1),
          );
        }
        final directory = Platform.environment['SELLER_HOME_REVIEW_DIR'];
        if (directory != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$directory/selector-$period-$width-$scale.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.tap(filter);
        await tester.pumpAndSettle();
        final daily = find.widgetWithText(
          CheckedPopupMenuItem<String>,
          'Daily',
        );
        final monthly = find.widgetWithText(
          CheckedPopupMenuItem<String>,
          'Monthly',
        );
        final menu = find
            .ancestor(of: daily, matching: find.byType(Material))
            .first;
        final menuRect = tester.getRect(menu);
        expect(menuRect.left, closeTo(trigger.left, 0.1));
        expect(menuRect.right, closeTo(trigger.right, 0.1));
        final dailyLabel = find.descendant(
          of: daily,
          matching: find.text('Daily'),
        );
        final monthlyLabel = find.descendant(
          of: monthly,
          matching: find.text('Monthly'),
        );
        for (final item in [
          dailyLabel,
          monthlyLabel,
          find.descendant(
            of: find.widgetWithText(CheckedPopupMenuItem<String>, 'Weekly'),
            matching: find.text('Weekly'),
          ),
        ]) {
          expect(tester.widget<Text>(item).maxLines, 1);
          expect(tester.widget<Text>(item).softWrap, isFalse);
          expect(
            tester.renderObject<RenderParagraph>(item).didExceedMaxLines,
            isFalse,
          );
          final renderedLabel = tester.renderObject<RenderParagraph>(item);
          expect(
            renderedLabel.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(renderedLabel.size.width + 0.1),
          );
        }
        expect(
          tester.getRect(dailyLabel).left,
          closeTo(tester.getRect(monthlyLabel).left, 0.1),
        );
        final menuSurface = tester.widget<Material>(menu);
        expect(menuSurface.elevation, 0);
        expect(
          (menuSurface.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(12),
        );
        expect(
          tester.getRect(daily).top,
          greaterThanOrEqualTo(trigger.bottom + 8),
        );
        expect(tester.getRect(monthly).bottom, lessThanOrEqualTo(844));
        expect(tester.takeException(), isNull);
        if (directory != null) {
          await tester.runAsync(() async {
            final rendered = await captureImage(
              tester.element(find.byType(MaterialApp)),
            );
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$directory/menu-$period-$width-$scale.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      }
    });
  }
  testWidgets('Home uses requested Inter family, weights and variable axes', (
    tester,
  ) async {
    await show(tester, content(layoutData()));
    for (final (label, weight) in [
      ('Sales Overview', FontWeight.w600),
      ('Total Sales', FontWeight.w600),
      ('₱80.00', FontWeight.w700),
    ]) {
      final style = tester.widget<Text>(find.text(label).first).style!;
      expect(style.fontFamily, 'Inter');
      expect(style.fontWeight, weight);
      expect(style.fontVariations!.single.value, weight.value.toDouble());
    }
    for (final label in [
      'Recent Orders',
      'Latest orders received from buyers.',
      'Inventory Alerts',
      'SKU: STOCK-0',
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style!.fontFamily,
        'Montserrat',
      );
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'five newest orders swipe manually; inside footer dots, exact details and return state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final data = layoutData();
      await show(tester, content(data));
      final pager = find.byType(PageView);
      await reach(tester, pager);
      expect(
        tester.widget<PageView>(pager).childrenDelegate.estimatedChildCount,
        5,
      );
      expect(find.byTooltip('Order 5 of 5'), findsOneWidget);
      expect(find.byTooltip('Order 6 of 5'), findsNothing);
      expect(find.text('Recent Orders'), findsOneWidget);
      expect(find.text('Latest orders received from buyers.'), findsOneWidget);
      expect(find.text('Orders Requiring Action'), findsNothing);
      final header = find.byKey(const ValueKey('seller-section-orders'));
      final seeAll = find.descendant(
        of: header,
        matching: find.byType(TextButton),
      );
      expect(
        tester.getRect(seeAll).right,
        closeTo(tester.getRect(header).right, 1),
      );
      expect(
        tester.getRect(seeAll).top,
        lessThan(
          tester.getRect(find.text('Latest orders received from buyers.')).top,
        ),
      );
      final firstCard = find.byKey(const ValueKey('recent-order-100'));
      for (final value in [
        'Order #ORDER-100',
        'Buyer 0',
        'Processing',
        '₱40.00',
        'Oct 28, 2026',
        'Unpaid',
        'View Order Details',
      ]) {
        expect(
          find.descendant(of: firstCard, matching: find.text(value)),
          findsOneWidget,
        );
      }
      final firstDot = find.byKey(const ValueKey('recent-order-dot-0'));
      final cardSurface = find.byKey(
        const ValueKey('seller-recent-orders-card'),
      );
      expect(
        find.descendant(of: cardSurface, matching: firstDot),
        findsOneWidget,
      );
      final details = find.descendant(
        of: firstCard,
        matching: find.text('View Order Details'),
      );
      final detailsButton = find.ancestor(
        of: details,
        matching: find.byType(FilledButton),
      );
      expect(
        tester.getRect(firstDot).top,
        greaterThanOrEqualTo(tester.getRect(detailsButton).bottom),
      );
      final dotControl = find.byTooltip('Order 1 of 5');
      expect(tester.getSize(dotControl), const Size(24, 44));
      final nextDot = find.byKey(const ValueKey('recent-order-dot-1'));
      expect(
        tester.getCenter(nextDot).dx - tester.getCenter(firstDot).dx,
        closeTo(24, 0.1),
      );
      expect(
        tester.getRect(dotControl).top,
        closeTo(tester.getRect(detailsButton).bottom, 0.1),
      );
      expect(
        tester.getRect(cardSurface).bottom - tester.getRect(dotControl).bottom,
        inInclusiveRange(0, 2),
      );
      final spaceAbove =
          tester.getRect(firstDot).top - tester.getRect(detailsButton).bottom;
      final spaceBelow =
          tester.getRect(cardSurface).bottom - tester.getRect(firstDot).bottom;
      expect(spaceAbove, lessThan(19));
      expect(spaceBelow, closeTo(spaceAbove, 2));
      expect(find.text('Buyer 0'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(tester.widget<PageView>(pager).controller!.page, 0);
      await tester.drag(pager, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pager).controller!.page, 1);
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('recent-order-dot-1')),
      );
      expect((dot.decoration as BoxDecoration).color, const Color(0xFFFCB316));
      final card = find.byKey(const ValueKey('recent-order-99'));
      await tester.tap(
        find.descendant(of: card, matching: find.text('View Order Details')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order ORDER-99'), findsOneWidget);
      expect(find.text('Buyer 1'), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pager).controller!.page, 1);
      await reach(tester, find.byTooltip('Order 5 of 5'));
      Focus.of(
        tester.element(find.byKey(const ValueKey('recent-order-dot-4'))),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pager).controller!.page, 4);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final count in [0, 1]) {
    testWidgets('$count orders has honest content without pagination dots', (
      tester,
    ) async {
      await show(tester, content(layoutData(orders: count)));
      expect(find.byKey(const ValueKey('recent-order-dot-0')), findsNothing);
      expect(
        find.text('No recent orders yet'),
        count == 0 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('New customer orders will appear here.'),
        count == 0 ? findsOneWidget : findsNothing,
      );
      if (count == 1) {
        expect(find.text('Order #ORDER-100'), findsOneWidget);
        expect(find.text('Unpaid'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'carousel tracks the selected order across reorder, shrink and empty data',
    (tester) async {
      Widget carousel(List<Map<String, dynamic>> rows) => SellerRecentOrders(
        orders: rows,
        money: (value) => '$value',
        date: (value) => '$value',
        onDetails: (_) {},
      );
      final initial = (layoutData()['orders'] as List)
          .cast<Map<String, dynamic>>();
      await show(tester, carousel(initial));
      await tester.tap(find.byTooltip('Order 3 of 5'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        2,
      );
      final revised = [initial[2], initial[0], initial[1]];
      await show(tester, carousel(revised));
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      expect(find.text('Order #ORDER-98'), findsOneWidget);
      await show(tester, carousel([initial[0]]));
      expect(find.byKey(const ValueKey('recent-order-dot-0')), findsNothing);
      expect(find.text('Order #ORDER-100'), findsOneWidget);
      await show(tester, carousel([]));
      expect(find.byType(PageView), findsNothing);
      expect(find.text('No recent orders yet'), findsOneWidget);
      expect(
        find.text('New customer orders will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, height, scale) in [
    (280.0, 844.0, 2.0),
    (320.0, 844.0, 2.0),
    (414.0, 844.0, 1.0),
    (600.0, 844.0, 1.3),
    (844.0, 390.0, 1.0),
  ]) {
    testWidgets(
      'seller Home fits a full-width sales banner and adaptive order cards at $width/$height/$scale',
      (tester) async {
        await reviewFonts(tester);
        final capture = GlobalKey();
        await show(
          tester,
          content(layoutData(long: true)),
          width: width,
          height: height,
          scale: scale,
          capture: capture,
        );
        final labels = ['Total Orders', 'Completed Orders', 'Pending Orders'];
        final heights = <double>[];
        for (final label in labels) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, isNull);
          final tile = find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first;
          heights.add(tester.getSize(tile).height);
        }
        expect(heights.toSet().length, 1);
        final banner = tester.getRect(
          find.byKey(const ValueKey('seller-total-sales-banner')),
        );
        expect(banner.left, 16);
        expect(banner.right, width - 16);
        expect(
          tester.getTopLeft(find.text(labels[0])).dy,
          greaterThan(banner.bottom),
        );
        expect(tester.getTopLeft(find.text(labels[0])).dx, banner.left + 12);
        expect(find.text('All-time order counts'), findsOneWidget);
        final directory = Platform.environment['SELLER_HOME_REVIEW_DIR'];
        if (directory != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$directory/sales-$width-$scale.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await reach(tester, find.byType(PageView));
        final badge = find.byKey(const ValueKey('recent-order-status-100'));
        final header = find.byKey(const ValueKey('recent-order-header-100'));
        final reference = find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                '${widget.data}'.startsWith(
                  'Order #CAMPUSHUB-VERY-LONG-ORDER-REFERENCE',
                ),
          ),
        );
        expect(tester.widget<Text>(reference).maxLines, 1);
        expect(tester.widget<Text>(reference).overflow, TextOverflow.ellipsis);
        expect(
          tester.getRect(badge).right,
          closeTo(tester.getRect(header).right, 0.1),
        );
        expect(
          tester.getRect(badge).top,
          closeTo(tester.getRect(header).top, 0.1),
        );
        expect(
          tester.getRect(reference).right + 12,
          lessThanOrEqualTo(tester.getRect(badge).left + 0.1),
        );
        await tester.drag(find.byType(PageView), const Offset(-600, 0));
        await tester.pumpAndSettle();
        await reach(tester, find.text('Inventory Alerts'));
        expect(find.text('Restock Threshold'), findsNWidgets(3));
        expect(find.text('Stock item 3'), findsNothing);
        final onHand = tester.getTopLeft(find.text('On Hand').first).dy;
        expect(tester.getTopLeft(find.text('Reserved').first).dy, onHand);
        expect(
          tester.getTopLeft(find.text('Available Stock').first).dy,
          lessThan(onHand),
        );
        await reach(tester, find.text('Suggested Product Bundles'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('operational order and existing See All/KPI destinations', (
    tester,
  ) async {
    SellerDestination? destination;
    await show(
      tester,
      content(layoutData(), onNavigate: (value) => destination = value),
    );
    final sections = [
      'Sales Overview',
      'Suggested Product Bundles',
      'Recent Orders',
      'Inventory Alerts',
      'Sales Trend',
    ];
    final positions = sections
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
    await tester.tap(find.text('Total Sales'));
    expect(destination, SellerDestination.analytics);
    await tester.tap(find.text('Completed Orders'));
    expect(destination, SellerDestination.orders);
    for (final target in [
      SellerDestination.orders,
      SellerDestination.inventory,
      SellerDestination.recommendations,
    ]) {
      final header = find.byKey(ValueKey('seller-section-${target.name}'));
      await reach(tester, header);
      await tester.tap(
        find.descendant(of: header, matching: find.byType(TextButton)),
      );
      expect(destination, target);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundle empty/error states and actual trend inspection', (
    tester,
  ) async {
    final data = layoutData(orders: 0);
    (data['recommendations'] as Map)['rows'] = [];
    await show(tester, content(data));
    expect(
      find.text(
        'No bundle suggestions yet. More completed transactions are needed.',
      ),
      findsOneWidget,
    );
    (data['recommendations'] as Map)['error'] = true;
    await show(tester, content(data));
    expect(find.text('Unable to load bundle suggestions.'), findsOneWidget);
    expect(
      find.text(
        'No bundle suggestions yet. More completed transactions are needed.',
      ),
      findsNothing,
    );
    await show(
      tester,
      const SellerSalesTrend(
        trend: {
          'labels': ['2026-10-27', '2026-10-28'],
          'sales': [12, 34],
        },
      ),
    );
    expect(find.text('Oct 27: ₱12.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Oct 28: ₱34.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home recent preview includes completed/cancelled orders and ignores action/page data',
    (tester) async {
      final data = layoutData(orders: 1);
      final completed = {
        ...(data['orders'] as List).first as Map,
        'status_key': 'completed',
        'status': 'Completed',
        'code': 'COMPLETED-RECENT',
      };
      final cancelled = {
        ...completed,
        'id': 901,
        'status_key': 'cancelled',
        'status': 'Cancelled',
        'code': 'CANCELLED-NEWEST',
      };
      final older = {
        ...completed,
        'id': 902,
        'status_key': 'pending',
        'status': 'Pending',
        'code': 'OLDER-ACTION',
      };
      data['orders'] = [older];
      data['orders_requiring_action'] = [older];
      data['recent_orders'] = [cancelled, completed];
      await show(tester, content(data));
      expect(
        tester
            .widget<SellerRecentOrders>(find.byType(SellerRecentOrders))
            .orders
            .map((row) => row['id']),
        [901, 100],
      );
      expect(find.text('Order #CANCELLED-NEWEST'), findsOneWidget);
      expect(find.text('Order #OLDER-ACTION'), findsNothing);
      data.remove('recent_orders');
      data['orders'] = [completed, older];
      await show(tester, content(data));
      expect(
        tester
            .widget<SellerRecentOrders>(find.byType(SellerRecentOrders))
            .orders
            .map((row) => row['id']),
        [100, 902],
      );
      expect(find.text('Order #COMPLETED-RECENT'), findsOneWidget);
      data['recent_orders'] = <Map<String, dynamic>>[];
      await show(tester, content(data));
      expect(find.text('No recent orders yet'), findsOneWidget);
      expect(
        find.text('New customer orders will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale) in [(320.0, 2.0), (414.0, 1.0)]) {
    testWidgets('real Explore cards fit and scroll at $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final capture = GlobalKey();
      var opened = '';
      await reviewFonts(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: Colors.white,
                child: HomePage(
                  firstName: 'Test Seller',
                  sellerSections: content(layoutData()),
                  onMarketplace: () => opened = 'marketplace',
                  onFacilities: () => opened = 'facilities',
                  onServices: () => opened = 'services',
                  onRefresh: () async {},
                  catalog: HomeTestCatalog(),
                  loadProducts: () async => [
                    ...await homeProducts(),
                    const ProductItem(
                      'A long product name with several descriptive words',
                      '₱25.00',
                      Icons.inventory_2_outlined,
                      Colors.white,
                      stock: 0,
                      category: 'School Supplies',
                    ),
                  ],
                  loadFacilities: homeFacilities,
                  productBuilder: (product) =>
                      MarketplacePreviewCard(product: product),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final vertical = find
          .descendant(
            of: find.byKey(const PageStorageKey('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final (title, key, card) in [
        ('Marketplace', 'marketplace', MarketplacePreviewCard),
        ('Facilities', 'facilities', FacilityPreviewCard),
        ('Services', 'services', ServicePreviewCard),
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(PageStorageKey('home-preview-$key')),
          350,
          scrollable: vertical,
        );
        await tester.pumpAndSettle();
        final first = tester.getRect(find.byType(card).first);
        expect(first.left, 16);
        expect(first.right, lessThanOrEqualTo(width - 16));
        expect(find.byKey(PageStorageKey('home-preview-$key')), findsOneWidget);
        final header = find.ancestor(
          of: find.text(title),
          matching: find.byType(HomeSectionHeader),
        );
        await reach(tester, header);
        await tester.tap(
          find.descendant(of: header, matching: find.byType(TextButton)),
        );
        expect(opened, key);
        if (key == 'marketplace') {
          final scroller = find.byKey(
            const PageStorageKey('home-preview-marketplace'),
          );
          await tester.drag(scroller, const Offset(-220, 0));
          await tester.pumpAndSettle();
          final scrollable = find.descendant(
            of: scroller,
            matching: find.byType(Scrollable),
          );
          expect(
            tester.state<ScrollableState>(scrollable).position.pixels,
            greaterThan(0),
          );
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
        }
        final directory = Platform.environment['SELLER_HOME_REVIEW_DIR'];
        if (directory != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$directory/explore-$key-$width.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'optional seller Home render evidence in light and dark surroundings',
    (tester) async {
      final directory = Platform.environment['SELLER_HOME_REVIEW_DIR'];
      if (directory == null) return;
      await tester.runAsync(() async {
        for (final font in {
          'Montserrat': 'assets/fonts/Montserrat-VariableFont_wght.ttf',
          'Inter': 'assets/fonts/inter/InterVariable.ttf',
          'Poppins': 'assets/fonts/poppins/Poppins-Regular.ttf',
          'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          'packages/iconsax_flutter/FlutterIconsax':
              'packages/iconsax_flutter/fonts/FlutterIconsax.ttf',
        }.entries) {
          await (FontLoader(
            font.key,
          )..addFont(rootBundle.load(font.value))).load();
        }
      });
      for (final dark in [false, true]) {
        final capture = GlobalKey();
        await show(
          tester,
          content(layoutData()),
          capture: capture,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        for (final (name, target) in [
          ('overview', find.text('Sales Overview')),
          ('orders', find.byType(SellerRecentOrders)),
          ('inventory', find.text('Inventory Alerts')),
          ('trend-bundles', find.text('Sales Trend')),
        ]) {
          await reach(tester, target);
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$directory/$name-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
