import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:campushub/module_app/screens/dashboard_screen.dart';
import 'package:campushub/module_app/screens/profile_details_pages.dart';
import 'package:campushub/module_app/screens/facilities/facility_booking_history_screen.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:campushub/module_app/screens/home_page.dart';
import 'package:campushub/module_app/screens/seller_dashboard_page.dart';
import 'package:campushub/module_app/screens/seller_application_form.dart';
import 'package:campushub/module_app/services/seller_application_service.dart';
import 'package:campushub/module_app/session/session_service.dart';
import 'package:campushub/module_app/widgets/navigation/floating_bottom_navbar.dart';
import 'package:campushub/module_app/widgets/navigation/header_profile_button.dart';
import 'package:campushub/module_app/widgets/home/campus_home_banners.dart';
import 'package:campushub/module_app/screens/search_page.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'home_test_fixtures.dart';
import 'seller_test_fixtures.dart';

// Only test fixtures; production approval always comes from Django.
class HomeAccessService extends SellerApplicationService {
  String state = 'none';
  bool fail = false, malformed = false;
  int reads = 0, workspaceReads = 0;
  @override
  Future<Map<String, dynamic>> status([String? ignoredLegacyId]) async {
    reads++;
    if (fail) throw const SellerApplicationException('Status offline');
    return {
      'status': state,
      if (!malformed) 'is_approved_seller': state == 'approved',
    };
  }

  @override
  Future<Map<String, dynamic>> workspace({
    String period = '30',
    int ordersPage = 1,
  }) async {
    workspaceReads++;
    final data = sellerWorkspaceFixture();
    (data['analytics'] as Map)['period'] = period;
    return data;
  }
}

DashboardScreen home(HomeAccessService service, {int initialTab = 0}) =>
    DashboardScreen(
      initialTab: initialTab,
      sellerService: service,
      serviceCatalog: HomeTestCatalog(),
      loadHomeProducts: homeProducts,
      loadHomeFacilities: homeFacilities,
    );

Future<void> loadHomeReviewFonts() async {
  final poppins = FontLoader('Poppins');
  for (final face in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    poppins.addFont(rootBundle.load('assets/fonts/poppins/Poppins-$face.ttf'));
  }
  await poppins.load();
  for (final font in {
    'Inter': 'assets/fonts/inter/InterVariable.ttf',
    'Montserrat': 'assets/fonts/Montserrat-VariableFont_wght.ttf',
    'SugarPie': 'assets/fonts/Sugar-Pie-W00-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    'packages/iconsax_flutter/FlutterIconsax':
        'packages/iconsax_flutter/fonts/FlutterIconsax.ttf',
  }.entries) {
    await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
  }
}

Future<void> saveHomeReview(
  WidgetTester tester,
  GlobalKey capture,
  String path,
) => tester.runAsync(() async {
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final rendered = await boundary.toImage(pixelRatio: 2);
  final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  rendered.dispose();
});

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'campushub_logged_user': jsonEncode({
        'id': 1,
        'username': 'test-home',
        'first_name': 'Ana',
        'full_name': 'Ana Test',
        'user_type': 'student',
        'role': 'User',
        'profile_completed': true,
      }),
    }),
  );

  for (final (width, scale) in [
    (280.0, 1.0),
    (320.0, 1.0),
    (320.0, 2.0),
    (390.0, 1.0),
    (414.0, 2.0),
    (768.0, 1.0),
  ]) {
    testWidgets('seller Home profile opens its drawer at $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, left: 4, right: 4);
      addTearDown(tester.view.reset);
      const fullName = 'Alexandria Maria Dela Cruz With A Long Account Name';
      SharedPreferences.setMockInitialValues({
        'campushub_logged_user': jsonEncode({
          'id': 1,
          'username': 'test-home',
          'first_name': 'Alexandria',
          'full_name': fullName,
          'user_type': 'student',
          'role': 'User',
          'profile_completed': true,
        }),
      });
      final service = HomeAccessService()..state = 'approved';
      final directory = Platform.environment['SELLER_HEADER_REVIEW_DIR'];
      final capture = GlobalKey();
      if (directory != null) await tester.runAsync(loadHomeReviewFonts);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(key: capture, child: home(service)),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('dashboard-brand-header'));
      final identity = find.byType(HeaderProfileButton);
      final avatar = find.byKey(const ValueKey('dashboard-profile-avatar'));
      final name = find.byKey(const ValueKey('dashboard-profile-name'));
      final greeting = find.text('Welcome Back,');
      final search = find
          .ancestor(
            of: find.byTooltip('Search'),
            matching: find.byType(IconButton),
          )
          .first;
      final notifications = find
          .ancestor(
            of: find.byTooltip('Notifications'),
            matching: find.byType(IconButton),
          )
          .first;
      expect(find.byIcon(Iconsax.menu_1_copy), findsNothing);
      expect(greeting, findsOneWidget);
      expect(tester.widget<Text>(greeting).maxLines, 2);
      expect(find.text('Welcome Back, Alexandria'), findsNothing);
      expect(
        find.descendant(of: find.byType(HomePage), matching: greeting),
        findsNothing,
      );
      final nameText = tester.widget<Text>(name);
      expect(nameText.data, fullName);
      expect(nameText.maxLines, 1);
      expect(nameText.overflow, TextOverflow.ellipsis);
      expect(nameText.style!.fontFamily, 'Montserrat');
      expect(nameText.style!.fontWeight, FontWeight.w600);
      expect(nameText.style!.color, const Color(0xFF1A1851));
      expect(
        tester.getRect(greeting).bottom,
        lessThanOrEqualTo(tester.getRect(name).top),
      );
      expect(
        tester.getRect(name).left,
        greaterThanOrEqualTo(tester.getRect(avatar).right + 8),
      );
      expect(tester.getRect(identity).top, greaterThanOrEqualTo(28));
      expect(tester.getRect(identity).left, greaterThanOrEqualTo(18));
      expect(
        tester.getRect(name).right,
        lessThanOrEqualTo(tester.getRect(search).left),
      );
      expect(
        tester.getRect(search).right,
        lessThanOrEqualTo(tester.getRect(notifications).left),
      );
      expect(
        tester.getRect(search).center.dy,
        closeTo(tester.getRect(notifications).center.dy, 1),
      );
      for (final target in [identity, search, notifications]) {
        expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
      }
      expect(
        tester
            .getRect(find.byKey(const ValueKey('seller-sales-overview-header')))
            .top,
        closeTo(tester.getRect(header).bottom + 8, 1),
      );
      final semantics = tester.ensureSemantics();
      await tester.pump();
      final menuSemantics = find.bySemanticsLabel('Open menu: $fullName');
      expect(menuSemantics, findsOneWidget);
      expect(
        tester
            .getSemantics(menuSemantics)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
      if (directory != null) {
        await saveHomeReview(
          tester,
          capture,
          '$directory/seller-header-${width.toInt()}-$scale.png',
        );
      }

      // Tap the actual avatar, then use the unchanged drawer navigation.
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      final shell = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      expect(shell.isDrawerOpen, isTrue);
      final drawer = find.byType(CampusHubDrawer);
      expect(tester.widget<CampusHubDrawer>(drawer).sellerApproved, isTrue);
      final overview = find.byKey(const ValueKey('seller-menu-overview'));
      await tester.scrollUntilVisible(
        overview,
        200,
        scrollable: find
            .descendant(of: drawer, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(overview.hitTestable(), findsOneWidget);
      await tester.tap(overview);
      await tester.pumpAndSettle();
      expect(shell.isDrawerOpen, isFalse);
      expect(find.text('Sales Overview'), findsOneWidget);
      await tester.tap(search);
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Enable notifications'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Other tabs keep the existing hamburger/profile shortcut header.
      await tester.tap(find.byKey(const ValueKey('navbar-item-2')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Iconsax.menu_1_copy), findsOneWidget);
      expect(greeting, findsNothing);
      expect(find.byTooltip('View profile: $fullName'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('navbar-item-0')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Iconsax.menu_1_copy), findsNothing);
      expect(greeting, findsOneWidget);
      expect(service.workspaceReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final (width, scale) in [(280.0, 2.0), (390.0, 1.0), (768.0, 1.0)]) {
    testWidgets('seller banner follows Inventory Alerts at $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = Platform.environment['SELLER_BANNER_REVIEW_DIR'];
      if (directory != null) await tester.runAsync(loadHomeReviewFonts);
      final capture = GlobalKey();
      final service = HomeAccessService()..state = 'approved';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(key: capture, child: home(service)),
        ),
      );
      await tester.pumpAndSettle();
      final banner = find.byKey(const ValueKey('home-campus-banners'));
      final inventory = find.text('Inventory Alerts');
      final suggestions = find.text('Suggested Product Bundles');
      expect(banner, findsOneWidget);
      expect(
        find.descendant(of: find.byType(SellerDashboardPage), matching: banner),
        findsOneWidget,
      );
      expect(
        tester.getRect(banner).top,
        greaterThan(tester.getRect(inventory).bottom),
      );
      expect(
        tester.getRect(banner).bottom,
        lessThanOrEqualTo(tester.getRect(suggestions).top),
      );
      await Scrollable.ensureVisible(tester.element(banner), alignment: .5);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(banner);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(width));
      if (directory != null) {
        await saveHomeReview(
          tester,
          capture,
          '$directory/seller-banner-$width-$scale.png',
        );
      }
      // Use the actual banner controls to enter the existing Services tab.
      for (var page = 0; page < 2; page++) {
        await tester.drag(
          find.byKey(const ValueKey('home-banner-pages')),
          Offset(-width, 0),
        );
        await tester.pumpAndSettle();
      }
      await Scrollable.ensureVisible(
        tester.element(find.text('View Services')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Services'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FloatingBottomNavbar>(find.byType(FloatingBottomNavbar))
            .currentIndex,
        2,
      );
      expect(
        tester
            .widget<CampusHomeBanners>(
              find.byType(CampusHomeBanners, skipOffstage: false),
            )
            .active,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('navbar-item-0')));
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      expect(
        tester.widget<CampusHomeBanners>(find.byType(CampusHomeBanners)).active,
        isTrue,
      );
      expect(service.workspaceReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'browsing Home preserves seller state; pull-to-refresh still works',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = HomeAccessService()..state = 'approved';
      await tester.pumpWidget(MaterialApp(home: home(service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-campus-banners')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-banner-pages')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-banner-dot-0')), findsOneWidget);
      expect(find.text('View Services'), findsNothing);
      expect(find.text('Seller Dashboard'), findsNothing);
      expect(find.text('Quick Actions'), findsNothing);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('seller-sales-overview-header')))
            .top,
        closeTo(
          tester
                  .getRect(find.byKey(const ValueKey('dashboard-brand-header')))
                  .bottom +
              8,
          1,
        ),
      );
      final sellerState = tester.state(find.byType(SellerDashboardPage));
      final initialStatusReads = service.reads;
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final services = find.descendant(
        of: find.byType(HomePage),
        matching: find.text('Services'),
      );
      await tester.scrollUntilVisible(services, 450, scrollable: scrollable);
      await tester.pumpAndSettle();
      final belowSeller = position.pixels;
      expect(belowSeller, greaterThan(500));
      expect(service.workspaceReads, 1);
      await tester.drag(scrollable, const Offset(0, 120));
      await tester.pumpAndSettle();
      // Native scrolling starts after the test gesture's initial drag slop.
      expect(
        position.pixels,
        closeTo(belowSeller - (120 - kDragSlopDefault), 3),
      );
      await tester.scrollUntilVisible(
        find.text('Sales Overview'),
        -350,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(service.workspaceReads, 1);
      expect(tester.state(find.byType(SellerDashboardPage)), same(sellerState));
      expect(service.reads, initialStatusReads);
      await tester.scrollUntilVisible(
        find.text('Sales Overview'),
        -350,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      position.jumpTo(position.minScrollExtent);
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getTopLeft(scrollable) + const Offset(20, 80),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(service.workspaceReads, 2);
      expect(service.reads, greaterThan(initialStatusReads));
      expect(tester.state(find.byType(SellerDashboardPage)), same(sellerState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final trigger in ['return to Home', 'app resume']) {
    testWidgets(
      '$trigger checks access without automatically refreshing Home',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final service = HomeAccessService()..state = 'approved';
        await tester.pumpWidget(MaterialApp(home: home(service)));
        await tester.pumpAndSettle();
        final sellerState = tester.state(find.byType(SellerDashboardPage));
        final initialReads = service.reads;
        final scrollable = find
            .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        await tester.scrollUntilVisible(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Services'),
          ),
          450,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final offset = position.pixels;
        expect(offset, greaterThan(500));
        if (trigger == 'return to Home') {
          await tester.tap(find.byKey(const ValueKey('navbar-item-2')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('navbar-item-0')));
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(service.workspaceReads, 1);
        expect(service.reads, initialReads + 1);
        expect(position.pixels, closeTo(offset, 1));
        await tester.scrollUntilVisible(
          find.text('Sales Overview'),
          -350,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(
          tester.state(find.byType(SellerDashboardPage)),
          same(sellerState),
        );
        expect(find.text('Sales Overview'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final seller in [false, true]) {
    testWidgets(
      'personal drawer routes and Android Back preserve Home; seller=$seller',
      (tester) async {
        final service = HomeAccessService()
          ..state = seller ? 'approved' : 'none';
        await http.runWithClient(
          () async {
            await tester.pumpWidget(MaterialApp(home: home(service)));
            await tester.pumpAndSettle();
            final shell = tester.state<ScaffoldState>(
              find.byType(Scaffold).first,
            );
            final dashboard = tester.state(find.byType(DashboardScreen));
            await tester.tap(find.byKey(const ValueKey('navbar-item-2')));
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Open menu'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<CampusHubDrawer>(find.byType(CampusHubDrawer))
                  .selected,
              isNull,
            );
            await tester.tap(
              find.byKey(const ValueKey('seller-menu-overview')),
            );
            await tester.pumpAndSettle();
            expect(shell.isDrawerOpen, isFalse);
            expect(tester.state(find.byType(DashboardScreen)), same(dashboard));
            expect(
              tester
                  .widget<FloatingBottomNavbar>(
                    find.byType(FloatingBottomNavbar),
                  )
                  .currentIndex,
              0,
            );
            expect(
              find.text(seller ? 'Welcome Back,' : 'Welcome Back, Ana'),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('home-seller-sections')),
              seller ? findsOneWidget : findsNothing,
            );
            await tester.tap(find.byTooltip('Open menu'));
            await tester.pumpAndSettle();
            expect(find.byType(CampusHubDrawer), findsOneWidget);
            expect(
              tester
                  .widget<CampusHubDrawer>(find.byType(CampusHubDrawer))
                  .selected,
              SellerDestination.overview,
            );
            await tester.tap(
              find.byKey(const ValueKey('seller-menu-overview')),
            );
            await tester.pumpAndSettle();
            expect(shell.isDrawerOpen, isFalse);
            expect(tester.state(find.byType(DashboardScreen)), same(dashboard));
            await tester.tap(find.byTooltip('Open menu'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('seller-menu-products')),
              seller ? findsOneWidget : findsNothing,
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(shell.isDrawerOpen, isFalse);
            for (final destination in [
              SellerDestination.purchases,
              SellerDestination.bookings,
            ]) {
              await tester.tap(find.byTooltip('Open menu'));
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(ValueKey('seller-menu-${destination.name}')),
              );
              await tester.pumpAndSettle();
              expect(shell.isDrawerOpen, isFalse);
              expect(
                find.byType(
                  destination == SellerDestination.purchases
                      ? ProfileOrdersPage
                      : FacilityBookingHistoryScreen,
                ),
                findsOneWidget,
              );
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(find.byType(DashboardScreen), findsOneWidget);
              expect(
                tester
                    .widget<FloatingBottomNavbar>(
                      find.byType(FloatingBottomNavbar),
                    )
                    .currentIndex,
                0,
              );
            }
            expect((await SessionService.loadUser())!.id, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient(
            (request) async =>
                http.Response(jsonEncode({'bookings': [], 'orders': []}), 200),
          ),
        );
      },
    );
  }

  testWidgets(
    'render approved seller additions with the original Home navbar',
    (tester) async {
      final directory = Platform.environment['SELLER_SHARED_HOME_CAPTURE'];
      if (directory == null) return;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHomeReviewFonts);
      final capture = GlobalKey();
      final service = HomeAccessService()..state = 'approved';
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(key: capture, child: home(service)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(DashboardScreen));
        await precacheImage(
          const AssetImage('assets/img/logo_light.png'),
          context,
        );
        await precacheImage(
          const ResizeImage(
            AssetImage('assets/img/ustp_oroquieta_entrance.png'),
            width: 1280,
          ),
          context,
        );
      });
      await tester.pumpAndSettle();
      Future<void> save(String name) =>
          saveHomeReview(tester, capture, '$directory/$name.png');
      await save('shared-home-seller-sections');
      await tester.scrollUntilVisible(
        find.text('Test Chocolate'),
        240,
        scrollable: find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await save('shared-home-marketplace');
      expect(find.byType(FloatingBottomNavbar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in [
    'none',
    'pending',
    'needs_revision',
    'rejected',
    'suspended',
  ]) {
    testWidgets('$status access keeps regular Home and its five tabs', (
      tester,
    ) async {
      final service = HomeAccessService()..state = status;
      await tester.pumpWidget(MaterialApp(home: home(service)));
      await tester.pumpAndSettle();
      expect(find.byType(SellerDashboardPage), findsNothing);
      expect(find.byType(FloatingBottomNavbar), findsOneWidget);
      expect(find.text('Welcome Back, Ana'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-campus-banners')), findsOneWidget);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      expect(find.text('Seller Dashboard'), findsNothing);
      expect(service.reads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'approval and revocation add or remove seller sections on the same Home',
    (tester) async {
      final service = HomeAccessService()..state = 'pending';
      await tester.pumpWidget(MaterialApp(home: home(service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-campus-banners')), findsOneWidget);
      service.state = 'approved';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(SellerDashboardPage), findsOneWidget);
      expect(find.byKey(const ValueKey('home-campus-banners')), findsOneWidget);
      expect(find.byTooltip('Open seller menu'), findsNothing);
      expect(find.byTooltip('Open menu'), findsOneWidget);
      expect(find.byType(FloatingBottomNavbar), findsOneWidget);
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.byKey(const Key('navbar-center-add-button')), findsOneWidget);
      expect((await SessionService.loadUser())!.id, 1);
      service.state = 'suspended';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(SellerDashboardPage), findsNothing);
      expect(find.byKey(const ValueKey('home-campus-banners')), findsOneWidget);
      expect(find.byType(FloatingBottomNavbar), findsOneWidget);
      expect(find.byTooltip('Open seller menu'), findsNothing);
      expect(find.byKey(const Key('navbar-center-add-button')), findsNothing);
      expect(find.text('Profile'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'approval while viewing an application returns to shared Home with seller sections',
    (tester) async {
      final service = HomeAccessService()..state = 'pending';
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(home: home(service, initialTab: 4)),
          );
          await tester.pumpAndSettle();
          // Chat initializes without credentials; the existing status HTTP then uses a test token.
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString('campushub_chat_token', 'test-token');
          final entry = find.byKey(const ValueKey('profile-apply-to-sell'));
          await tester.ensureVisible(entry);
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(find.byType(SellerApplicationForm), findsOneWidget);
          service.state = 'approved';
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(find.byType(SellerApplicationForm), findsNothing);
          expect(find.byType(SellerDashboardPage), findsOneWidget);
          expect(find.byType(FloatingBottomNavbar), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'status': service.state,
              'is_approved_seller': service.state == 'approved',
              'seller_request': {'application_data': {}},
            }),
            200,
          ),
        ),
      );
    },
  );

  testWidgets('failed status is retryable and never grants seller access', (
    tester,
  ) async {
    final service = HomeAccessService()..fail = true;
    await tester.pumpWidget(MaterialApp(home: home(service)));
    await tester.pumpAndSettle();
    expect(find.text('Status offline'), findsOneWidget);
    expect(find.byType(SellerDashboardPage), findsNothing);
    service.fail = false;
    service.state = 'approved';
    await tester.tap(find.text('Status offline'));
    await tester.pumpAndSettle();
    expect(find.byType(SellerDashboardPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unreadable status allows public browsing but no seller menu', (
    tester,
  ) async {
    final service = HomeAccessService()..malformed = true;
    await tester.pumpWidget(MaterialApp(home: home(service)));
    await tester.pumpAndSettle();
    expect(find.text('Unable to verify seller access. Retry.'), findsOneWidget);
    expect(find.byType(FloatingBottomNavbar), findsOneWidget);
    expect(find.byType(SellerDashboardPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'explicit Services entry remains a Services deep link for sellers',
    (tester) async {
      final service = HomeAccessService()..state = 'approved';
      await tester.pumpWidget(MaterialApp(home: home(service, initialTab: 2)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FloatingBottomNavbar>(find.byType(FloatingBottomNavbar))
            .currentIndex,
        2,
      );
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(SellerDashboardPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
