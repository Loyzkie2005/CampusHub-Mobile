import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campushub/module_app/screens/seller_dashboard_page.dart';
import 'package:campushub/module_app/screens/seller_bundle_form.dart';
import 'package:campushub/module_app/screens/seller_demo_bundle_page.dart';
import 'package:campushub/module_app/screens/seller_workspace_content.dart';
import 'package:campushub/module_app/services/demo_bundle_store.dart';
import 'package:campushub/module_app/services/seller_application_service.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'seller_workspace_test.dart' as fixture;
import 'seller_test_fixtures.dart';
import 'seller_home_layout_test.dart' as layout;

class FlowService extends fixture.WorkspaceService {
  Completer<Map<String, dynamic>>? pendingValidation;
  bool rejectValidation = false, admin = false, demoError = false;
  String decision = 'pending';
  int validations = 0, dismissals = 0, accepts = 0, declines = 0;
  @override
  Future<Map<String, dynamic>> recommendationAction(
    Map<String, dynamic> row,
    String action,
  ) async {
    if (action == 'dismiss') {
      dismissals++;
      return {'message': 'Dismissed'};
    }
    if (action == 'decline') {
      declines++;
      decision = 'declined';
      return {'status': decision};
    }
    if (action == 'accept') {
      accepts++;
      decision = 'accepted';
    }
    validations++;
    if (pendingValidation != null) return pendingValidation!.future;
    if (rejectValidation) {
      throw const SellerApplicationException(
        'This product is no longer available.',
        statusCode: 409,
      );
    }
    return {
      'id': row['id'],
      'source': row['source'] ?? 'live',
      'revision': '',
      'status': decision,
      'products': (data['products'] as List)
          .take(2)
          .map((item) => {...item as Map, 'name': 'Fresh ${item['id']}'})
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> recommendations(String source) async {
    if (source == 'synthetic' && demoError) {
      throw const SellerApplicationException('Demo unavailable');
    }
    return {
      'source': source,
      'rows': source == 'admin' && !admin
          ? []
          : [
              {
                ...sellerPairFixture(),
                'id': source == 'admin' ? '17' : '1|2',
                'source': source,
                'status': decision,
                'can_create': source != 'admin' || decision != 'declined',
                'revision': source == 'synthetic'
                    ? 'test-dataset-revision'
                    : '',
              },
            ],
      'error': false,
    };
  }
}

Future<void> home(
  WidgetTester tester,
  FlowService service, {
  ValueChanged<SellerDestination>? navigate,
  int revision = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SellerDashboardPage(
            user: fixture.user,
            service: service,
            homeSection: true,
            refreshRevision: revision,
            onOpenDestination: navigate,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reach(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .3);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [280.0, 390.0]) {
    testWidgets('three stacked sections have no source tabs at $width', (
      tester,
    ) async {
      final data = sellerWorkspaceFixture();
      final service = FlowService()..admin = true;
      data['recommendation_sections'] = {
        for (final source in ['admin', 'live', 'synthetic'])
          source: await service.recommendations(source),
      };
      final capture = GlobalKey();
      await layout.reviewFonts(tester);
      await layout.show(
        tester,
        SizedBox(
          height: width == 280 ? 3300 : 1800,
          child: SellerWorkspaceContent(
            destination: SellerDestination.recommendations,
            data: data,
            sellerFirstName: 'Test',
            onNavigate: (_) {},
            onAddProduct: () {},
            onCreateBundle: (_) {},
            onReload: () {},
            onPeriod: (_) {},
            onOrdersPage: (_) {},
          ),
        ),
        width: width,
        height: width == 280 ? 3400 : 1900,
        scale: width == 280 ? 2 : 1,
        capture: capture,
      );
      expect(find.byType(TabBar), findsNothing);
      final admin = find.byKey(const ValueKey('bundle-section-admin'));
      final live = find.byKey(const ValueKey('bundle-section-live'));
      final demo = find.byKey(const ValueKey('bundle-section-synthetic'));
      expect(tester.getTopLeft(admin).dy, lessThan(tester.getTopLeft(live).dy));
      expect(tester.getTopLeft(live).dy, lessThan(tester.getTopLeft(demo).dy));
      for (final source in ['admin', 'live', 'synthetic']) {
        final card = find.byKey(ValueKey('seller-bundles-$source'));
        expect(tester.getRect(card).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(card).right, lessThanOrEqualTo(width));
      }
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DEMO_BUNDLE_RENDER_DIR'];
      if (output != null && width == 390) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$output/three-sections.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('workspace refresh invalidates an older validation response', (
    tester,
  ) async {
    final service = FlowService()
      ..pendingValidation = Completer<Map<String, dynamic>>();
    await home(tester, service);
    await reach(tester, find.text('Create Bundle'));
    await tester.tap(find.text('Create Bundle'));
    await tester.pump();
    await home(tester, service, revision: 1);
    service.pendingValidation!.complete({
      'id': '1|2',
      'source': 'live',
      'products': (service.data['products'] as List).take(2).toList(),
    });
    await tester.pumpAndSettle();
    expect(find.byType(SellerBundleForm), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'real validation precedes preselected form and blocks repeated taps',
    (tester) async {
      final service = FlowService()..rejectValidation = true;
      await home(tester, service);
      await reach(tester, find.text('Create Bundle'));
      await tester.tap(find.text('Create Bundle'));
      await tester.pumpAndSettle();
      expect(service.validations, 1);
      expect(find.byType(SellerBundleForm), findsNothing);
      service.rejectValidation = false;
      await tester.tap(find.text('Create Bundle'));
      await tester.pumpAndSettle();
      final form = tester.widget<SellerBundleForm>(
        find.byType(SellerBundleForm),
      );
      expect(form.products.map((p) => p['name']), ['Fresh 1', 'Fresh 2']);
      expect(form.source, 'live');
      expect(service.lastProduct, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Accept persists before form, cancellation and refresh retain Accepted',
    (tester) async {
      final service = FlowService()..admin = true;
      await home(tester, service);
      await reach(tester, find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(service.accepts, 1);
      expect(service.decision, 'accepted');
      final form = tester.widget<SellerBundleForm>(
        find.byType(SellerBundleForm),
      );
      expect(form.source, 'admin');
      expect(form.pairId, '17');
      expect(form.products, hasLength(2));
      expect(service.lastProduct, isNull);
      expect(find.widgetWithText(TextFormField, '1'), findsNWidgets(2));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      await home(tester, service, revision: 1);
      expect(find.text('Accepted'), findsOneWidget);
    },
  );
  testWidgets('Decline requires confirmation, persists and stays in history', (
    tester,
  ) async {
    final service = FlowService()..admin = true;
    await home(tester, service);
    await reach(tester, find.text('Decline'));
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(service.declines, 0);
    await tester.tap(find.text('Keep Recommendation'));
    await tester.pumpAndSettle();
    expect(service.declines, 0);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline Recommendation'));
    await tester.pumpAndSettle();
    expect(service.declines, 1);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.text('Decline'), findsNothing);
    await home(tester, service, revision: 1);
    expect(find.text('Declined'), findsOneWidget);
  });
  testWidgets(
    'accepted real submission opens My Products with Pending Approval',
    (tester) async {
      final service = FlowService()..admin = true;
      SellerDestination? destination;
      await home(tester, service, navigate: (value) => destination = value);
      await reach(tester, find.text('Accept'));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bundle Name'),
        'My accepted bundle',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bundle Price (₱)'),
        '35',
      );
      await reach(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('School Supplies').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Submit for Review'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Submit for Review'));
      await tester.pumpAndSettle();
      expect(destination, SellerDestination.products);
      expect(service.lastProduct?['suggestion_source'], 'admin');
      expect(
        service.lastProduct?['submission_key'],
        matches(RegExp(r'^[a-f0-9]{32}$')),
      );
      final submitted = (service.data['products'] as List).last;
      expect(submitted['name'], 'My accepted bundle');
      expect(submitted['approval_status'], 'pending');
    },
  );
  testWidgets(
    'demo failure is independent from real recommendations and retries',
    (tester) async {
      final service = FlowService()..demoError = true;
      await home(tester, service);
      expect(find.text('Create Bundle'), findsOneWidget);
      expect(find.text('Unable to load this section.'), findsOneWidget);
      final retry = find.byKey(const ValueKey('bundle-retry-synthetic'));
      service.demoError = false;
      await reach(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Create Demo Bundle'), findsOneWidget);
      expect(find.text('Create Bundle'), findsOneWidget);
    },
  );
  testWidgets(
    'demo saves locally with fixed quantities and does not call real product API',
    (tester) async {
      final service = FlowService();
      await home(tester, service);
      await reach(tester, find.text('Create Demo Bundle'));
      await tester.tap(find.text('Create Demo Bundle'));
      await tester.pumpAndSettle();
      expect(find.byType(SellerDemoBundlePage), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('demo-price')), '55');
      expect(find.text('×1'), findsNWidgets(2));
      await reach(tester, find.text('Save Demo Bundle'));
      await tester.tap(find.text('Save Demo Bundle'));
      await tester.pumpAndSettle();
      expect(find.text('Bundle Created!'), findsOneWidget);
      final records = await const DemoBundleStore(1).list();
      expect(records, hasLength(1));
      expect(records.single['quantities'], [1, 1]);
      expect(service.lastProduct, isNull);
      expect(service.validations, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await reach(tester, find.text('Create Demo Bundle'));
      await tester.tap(find.text('Create Demo Bundle'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Bundle'), findsOneWidget);
      expect(await const DemoBundleStore(1).list(), hasLength(1));
    },
  );
  test(
    'new read/action transport retains bearer source and does not retry a POST',
    () async {
      SharedPreferences.setMockInitialValues({
        'campushub_chat_token': 'test-token',
      });
      var posts = 0;
      await http.runWithClient(
        () async {
          const service = SellerApplicationService();
          await service.recommendations('synthetic');
          await service.recommendationAction({
            'id': 'S01:P01|S01:P02',
            'source': 'synthetic',
            'revision': 'r',
          }, 'validate');
          expect(posts, 1);
        },
        () => MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer test-token');
          if (request.method == 'GET') {
            expect(request.url.queryParameters, {'source': 'synthetic'});
            return http.Response(
              '{"source":"synthetic","rows":[],"error":false}',
              200,
            );
          }
          posts++;
          expect(jsonDecode(request.body), {
            'id': 'S01:P01|S01:P02',
            'source': 'synthetic',
            'revision': 'r',
            'action': 'validate',
          });
          return http.Response('{"products":[]}', 200);
        }),
      );
    },
  );
}
