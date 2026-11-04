import 'package:campushub/module_app/models/product_customization.dart';
import 'package:campushub/module_app/widgets/order_summary_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('payment circles select once and keep locked choices unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final payments = <String>[];
    final fulfillment = <String>[];
    Future<void> pump({bool locked = false, bool delivery = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderSummaryCard(
                items: const [],
                subtotal: 0,
                locked: locked,
                deliverySupported: delivery,
                onPaymentMethodChanged: payments.add,
                onFulfillmentChanged: (method, _) => fulfillment.add(method),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder circle(String method) => find.descendant(
      of: find.byKey(ValueKey('checkout-cash-$method')),
      matching: find.byType(Radio<String>),
    );

    await pump();
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
    for (final method in ['pickup', 'delivery']) {
      final size = tester.getSize(circle(method));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await tester.tapAt(tester.getCenter(circle('delivery')));
    await tester.pumpAndSettle();
    expect(payments, ['cash_on_delivery']);
    expect(fulfillment, ['seller_delivery']);
    expect(
      find.byKey(const ValueKey('checkout-delivery-destination')),
      findsOneWidget,
    );

    await tester.tapAt(tester.getCenter(circle('pickup')));
    await tester.pumpAndSettle();
    expect(payments, ['cash_on_delivery', 'cash_on_pickup']);
    expect(fulfillment, ['seller_delivery', 'pickup']);
    expect(
      find.byKey(const ValueKey('checkout-delivery-destination')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.local_shipping_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash on Pickup'));
    await tester.pumpAndSettle();
    expect(payments, [
      'cash_on_delivery',
      'cash_on_pickup',
      'cash_on_delivery',
      'cash_on_pickup',
    ]);

    await pump(locked: true);
    await tester.tapAt(tester.getCenter(circle('delivery')));
    await tester.pumpAndSettle();
    expect(payments, hasLength(4));

    await pump(delivery: false);
    await tester.tapAt(tester.getCenter(circle('delivery')));
    await tester.pumpAndSettle();
    expect(payments, hasLength(4));
    expect(
      find.byKey(const ValueKey('checkout-delivery-destination')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('order summary shows item details and accepts a seller message', (
    tester,
  ) async {
    final messageController = TextEditingController();
    addTearDown(messageController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderSummaryCard(
              items: const [
                OrderSummaryLineItem(
                  productName: 'Hotdog',
                  sellerName: 'Campus Store',
                  imageUrl: '',
                  quantity: 1,
                  unitPrice: 65,
                  selections: [
                    SelectedCustomization(
                      group: 'Size',
                      option: 'Medium',
                      extraPrice: 25,
                    ),
                  ],
                ),
              ],
              subtotal: 65,
              sellerMessageController: messageController,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hotdog'), findsOneWidget);
    expect(find.text('Size: Medium (+\u20b125.00)'), findsOneWidget);
    expect(find.text('x1'), findsOneWidget);
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Cash on Pickup'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout-cash-pickup')), findsOneWidget);
    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('Delivery Fee'), findsNothing);
    expect(find.text('Platform Fee'), findsNothing);
    expect(find.text('Add note'), findsOneWidget);

    final msgRect = tester.getRect(find.text('Add note'));
    final payRect = tester.getRect(find.text('Payment Method'));
    final orderSummaryRect = tester.getRect(find.text('Order Summary'));
    final subtotalRect = tester.getRect(find.text('Product Subtotal'));

    expect(payRect.top, greaterThan(msgRect.bottom));
    expect(orderSummaryRect.top, greaterThan(payRect.bottom));
    expect(subtotalRect.top, greaterThan(orderSummaryRect.bottom));

    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    expect(
      find.text('Leave an optional message for the seller.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'No ketchup, please.');
    expect(messageController.text, 'No ketchup, please.');
  });

  testWidgets('quantity controller responds to plus and minus taps', (
    tester,
  ) async {
    var changedQty = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderSummaryCard(
            items: const [
              OrderSummaryLineItem(
                productName: 'Hotdog',
                imageUrl: '',
                quantity: 2,
                unitPrice: 65,
                selections: [],
              ),
            ],
            subtotal: 130,
            onQuantityChanged: (_, qty) => changedQty = qty,
          ),
        ),
      ),
    );

    expect(find.text('x2'), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(changedQty, 3);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(changedQty, 1);
  });

  testWidgets(
    'seller delivery selection sends method and actual destination separately from payment',
    (tester) async {
      String? selected;
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderSummaryCard(
                items: const [
                  OrderSummaryLineItem(
                    productName: 'Hotdog',
                    imageUrl: '',
                    quantity: 1,
                    unitPrice: 65,
                    selections: [],
                  ),
                ],
                subtotal: 65,
                deliverySupported: true,
                onFulfillmentChanged: (method, address) {
                  selected = method;
                  destination = address;
                },
              ),
            ),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-cash-delivery')),
      );
      await tester.tap(find.byKey(const ValueKey('checkout-cash-delivery')));
      await tester.pumpAndSettle();
      expect(selected, 'seller_delivery');
      await tester.enterText(
        find.byKey(const ValueKey('checkout-delivery-destination')),
        'Actual test destination',
      );
      expect(destination, 'Actual test destination');
      expect(find.text('Cash on Delivery'), findsOneWidget);
      expect(
        find.text('The seller delivers your order. Pay upon receiving it.'),
        findsOneWidget,
      );
    },
  );
}
