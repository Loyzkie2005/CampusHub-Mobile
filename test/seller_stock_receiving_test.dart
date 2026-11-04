import 'dart:async';
import 'dart:convert';
import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'seller_test_fixtures.dart';

void main() {
  testWidgets(
    'seller reopens an unconfirmed receipt and retries the same persisted operation',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'campushub_logged_user': jsonEncode({
          'id': 1,
          'username': 'test-seller',
          'user_type': 'student',
          'role': 'User',
          'profile_completed': true,
        }),
        'campushub_chat_token': 'isolated-test-token',
      });
      final data = sellerWorkspaceFixture();
      (data['inventory'] as List).first.addAll({
        'sku_id': 1,
        'can_receive': true,
        'inventory_method': 'simple',
      });
      final posts = <Map<String, dynamic>>[];
      var reloads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SellerWorkspaceContent(
                  destination: SellerDestination.inventory,
                  data: data,
                  onNavigate: (_) {},
                  onAddProduct: () {},
                  onCreateBundle: (_) {},
                  onReload: () => reloads++,
                  onPeriod: (_) {},
                  onOrdersPage: (_) {},
                  sellerFirstName: 'Test',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Receive Stock'));
          await tester.tap(find.text('Receive Stock'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).at(0), '3');
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'Actual test receipt',
          );
          await tester.tap(find.text('Record Receipt'));
          await tester.pumpAndSettle();
          expect(posts.length, 1);
          expect(reloads, 0);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Receive Stock'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .controller!
                .text,
            '3',
          );
          await tester.tap(find.text('Record Receipt'));
          await tester.pumpAndSettle();
          expect(posts.length, 2);
          expect(posts[1], posts[0]);
          expect(posts[0]['inventory_method'], 'simple');
          expect(reloads, 1);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.containsKey('campushub.receipt.1.1'), isFalse);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/mobile/seller/inventory/receive/');
          expect(
            request.headers['Authorization'],
            'Bearer isolated-test-token',
          );
          posts.add(Map<String, dynamic>.from(jsonDecode(request.body)));
          if (posts.length == 1) {
            throw TimeoutException('Simulated lost response');
          }
          return http.Response(
            jsonEncode({'message': 'Stock received.', 'batch': null}),
            200,
          );
        }),
      );
    },
  );
}
