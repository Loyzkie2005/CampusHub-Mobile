import 'dart:async';
import 'dart:convert';
import 'package:campushub/module_app/models/product_customization.dart';
import 'package:campushub/module_app/screens/checkout_screen.dart';
import 'package:campushub/module_app/services/checkout_validation.dart';
import 'package:campushub/module_app/services/order_service.dart';
import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'seller_test_fixtures.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'campushub_chat_token': 'isolated-test-token',
      'campushub_logged_user': jsonEncode({
        'id': 1,
        'full_name': 'Test Buyer',
        'contact_number': '09123456789',
        'user_type': 'student',
        'student_id': 'TEST-ID',
      }),
    }),
  );
  Map<String, dynamic> quote(Map row, {bool delivery = true}) => {
    'product_id': row['product_id'],
    'quantity': row['quantity'],
    'unit_price': '25.00',
    'subtotal': '${25 * (row['quantity'] as int)}',
    'total': '${25 * (row['quantity'] as int)}',
    'delivery_fee': '0.00',
    'available': 10,
    'delivery_supported': delivery,
  };
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CheckoutScreen(
          productId: 1,
          productName: 'Selected product',
          basePrice: 20,
          selection: BuySelection(
            quantity: 2,
            selections: [],
            summary: '',
            unitPrice: 20,
          ),
          imageUrl: '',
          category: 'School Supplies',
          sellerName: 'Test seller',
          sellerContact: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ElevatedButton button(WidgetTester tester) => tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Place Order'),
  );

  testWidgets(
    'COD requires a location; switching to pickup sends no old location and repeated taps create once',
    (tester) async {
      final submitted = <Map<String, dynamic>>[];
      final pending = Completer<http.Response>();
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('/quote/')) {
          return http.Response(
            jsonEncode({
              'items': (body['items'] as List)
                  .map((row) => quote(row))
                  .toList(),
            }),
            200,
          );
        }
        submitted.add(Map<String, dynamic>.from(body));
        return pending.future;
      });
      await http.runWithClient(() async {
        await pump(tester);
        expect(find.text('Test Buyer'), findsOneWidget);
        expect(find.text('Buyer Information'), findsNothing);
        expect(find.text('Receiving Method'), findsNothing);
        expect(button(tester).onPressed, isNotNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('checkout-cash-delivery')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-cash-delivery')));
        await tester.pumpAndSettle();
        expect(button(tester).onPressed, isNull);
        final location = find.byKey(
          const ValueKey('checkout-delivery-destination'),
        );
        await tester.enterText(location, '...');
        await tester.pump();
        expect(button(tester).onPressed, isNull);
        await tester.enterText(location, 'Library entrance');
        await tester.pump();
        expect(button(tester).onPressed, isNotNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('checkout-cash-pickup')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-cash-pickup')));
        await tester.pumpAndSettle();
        expect(location, findsNothing);
        await tester.tap(find.text('Place Order'));
        await tester.pump();
        await tester.pump();
        expect(submitted, hasLength(1));
        expect(submitted.single['delivery_destination'], '');
        expect(submitted.single['payment_method'], 'cash_on_pickup');
        expect(submitted.single['expected_unit_price'], '25.00');
        expect(submitted.single['total_price'], 50);
        // A loading button has no enabled callback while the API is pending.
        expect(
          tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).first)
              .onPressed,
          isNull,
        );
        pending.complete(
          http.Response(
            jsonEncode({
              'order': {
                'id': 7,
                'total_price': '50.00',
                'payment_status': 'unpaid',
              },
            }),
            201,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Review'), findsOneWidget);
      }, () => client);
    },
  );

  testWidgets(
    'unsupported delivery is disabled and a failed quote prevents submission',
    (tester) async {
      var fail = false;
      final client = MockClient((request) async {
        if (fail) {
          return http.Response(
            jsonEncode({'error': 'Only 1 item available.'}),
            400,
          );
        }
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode({
            'items': (body['items'] as List)
                .map((row) => quote(row, delivery: false))
                .toList(),
          }),
          200,
        );
      });
      await http.runWithClient(() async {
        await pump(tester);
        expect(
          tester
              .widget<RadioListTile<String>>(
                find.byKey(const ValueKey('checkout-cash-delivery')),
              )
              .enabled,
          isFalse,
        );
        fail = true;
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(button(tester).onPressed, isNull);
        await tester.ensureVisible(find.text('Only 1 item available.'));
        expect(find.text('Only 1 item available.'), findsOneWidget);
      }, () => client);
    },
  );

  test(
    'uncertain network retries retain the caller key; definite rejection exposes backend error',
    () async {
      final keys = <String?>[];
      var reject = false;
      await http.runWithClient(
        () async {
          final first = await OrderService.submitOrder(
            order: {'quantity': 1},
            operationKey: 'same-submission',
          );
          expect(first.uncertain, isTrue);
          final second = await OrderService.submitOrder(
            order: {'quantity': 1},
            operationKey: 'same-submission',
          );
          expect(second.confirmed, isTrue);
          reject = true;
          final third = await OrderService.submitOrder(
            order: {'quantity': 1},
            operationKey: 'new-submission',
          );
          expect(third.uncertain, isFalse);
          expect(third.message, 'Stock changed.');
        },
        () => MockClient((request) async {
          keys.add(request.headers['Idempotency-Key']);
          if (keys.length == 1) throw Exception('Connection interrupted');
          return http.Response(
            jsonEncode(
              reject
                  ? {'error': 'Stock changed.'}
                  : {
                      'order': {'id': 7},
                    },
            ),
            reject ? 409 : 201,
          );
        }),
      );
      expect(keys.take(2), ['same-submission', 'same-submission']);
    },
  );

  test(
    'location supports meaningful Unicode and rejects blank punctuation',
    () {
      for (final location in ['', '   ', '....!', 'x', 'x' * 501]) {
        expect(CheckoutValidation.validLocation(location), isFalse);
      }
      expect(CheckoutValidation.validLocation('Library entrance'), isTrue);
      expect(CheckoutValidation.validLocation('図書館の入口'), isTrue);
    },
  );

  testWidgets(
    'confirmed delivery saves COD and destination and reviews the actual method',
    (tester) async {
      Map? submitted;
      await http.runWithClient(
        () async {
          await pump(tester);
          await tester.ensureVisible(
            find.byKey(const ValueKey('checkout-cash-delivery')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('checkout-cash-delivery')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('checkout-delivery-destination')),
            'Library entrance',
          );
          await tester.pump();
          await tester.tap(find.text('Place Order'));
          await tester.pumpAndSettle();
          expect(submitted!['payment_method'], 'cash_on_delivery');
          expect(submitted!['fulfillment_method'], 'seller_delivery');
          expect(submitted!['delivery_destination'], 'Library entrance');
          expect(find.text('Review'), findsOneWidget);
          expect(find.text('Cash on Delivery'), findsOneWidget);
          expect(find.text('Cash on Pickup'), findsNothing);
          expect(find.byType(RadioGroup<String>), findsNothing);
        },
        () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (request.url.path.endsWith('/quote/')) {
            return http.Response(
              jsonEncode({
                'items': (body['items'] as List)
                    .map((row) => quote(row))
                    .toList(),
              }),
              200,
            );
          }
          submitted = body;
          return http.Response(
            '{"order":{"id":8,"payment_status":"unpaid","total_price":"50.00"}}',
            201,
          );
        }),
      );
    },
  );

  testWidgets(
    'seller toggle saves authenticated setting and waits for confirmation',
    (tester) async {
      final pending = Completer<http.Response>();
      Map? sent;
      final data = sellerWorkspaceFixture()
        ..['seller'] = {'seller_delivery_enabled': false};
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SellerWorkspaceContent(
                  destination: SellerDestination.products,
                  data: data,
                  onNavigate: (_) {},
                  onAddProduct: () {},
                  onCreateBundle: (_) {},
                  onReload: () {},
                  onPeriod: (_) {},
                  onOrdersPage: (_) {},
                  sellerFirstName: 'Test',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('seller-enable-delivery'));
          expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
          await tester.tap(toggle);
          await tester.pump();
          await tester.pump();
          expect(sent, {'seller_delivery_enabled': true});
          expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
          pending.complete(
            http.Response('{"seller_delivery_enabled":true}', 200),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
        },
        () => MockClient((request) async {
          sent = jsonDecode(request.body) as Map;
          expect(
            request.headers['Authorization'],
            'Bearer isolated-test-token',
          );
          return pending.future;
        }),
      );
    },
  );
}
