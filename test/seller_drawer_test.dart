import 'package:campushub/module_app/routes/app_routes.dart';
import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final drawerUser = AuthUser.fromJson({
  'id': 71,
  'username': 'sidebar-test',
  'full_name': 'Test Student Seller',
  'program': 'BFPT',
  'year_section': '2-A',
  'email': 'student.seller@example.edu',
});

void main() {
  for (final seller in [false, true]) {
    for (final (size, scale, dark) in [
      (const Size(375, 812), 1.0, false),
      (const Size(320, 640), 2.0, false),
      (const Size(844, 390), 2.0, true),
      (const Size(768, 1024), 1.3, true),
    ]) {
      testWidgets('role drawer seller=$seller fits $size/$scale dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SellerDestination? selected;
        final destinations = [
          SellerDestination.overview,
          SellerDestination.purchases,
          SellerDestination.bookings,
          if (seller) ...[
            SellerDestination.products,
            SellerDestination.inventory,
            SellerDestination.orders,
            SellerDestination.bundles,
            SellerDestination.analytics,
          ],
          SellerDestination.messages,
        ];
        var profileOpens = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, update) => Scaffold(
                body: CampusHubDrawer(
                  user: drawerUser,
                  sellerApproved: seller,
                  selected: selected,
                  onSelected: (value) => update(() => selected = value),
                  onProfile: () => profileOpens++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Test Student Seller'), findsOneWidget);
        expect(find.text('BFPT \u00b7 2-A'), findsOneWidget);
        expect(find.text('student.seller@example.edu'), findsNothing);
        expect(find.text('Student Account'), findsNothing);
        expect(find.text('Seller Access'), findsNothing);
        expect(find.text('Dashboard'), findsNothing);
        expect(find.text('Seller Dashboard'), findsNothing);
        expect(find.text('Home'), findsOneWidget);
        // Design B: My Purchases is relabelled and Account Settings is
        // reached through the profile header instead of a sidebar row.
        expect(find.text('My Purchases'), findsOneWidget);
        expect(find.text('Account Settings'), findsNothing);
        expect(find.text('ACCOUNT'), findsNothing);
        for (final section in [
          'MAIN',
          if (seller) 'SELLER TOOLS',
          'MESSAGES',
        ]) {
          // The list is lazy, so scroll each grouped card into view first.
          final group = find.byKey(ValueKey('seller-menu-group-$section'));
          await tester.scrollUntilVisible(group, 100);
          expect(group, findsOneWidget);
        }
        // Return the scrollable menu to the top before checking the header.
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('seller-navigation-list')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        if (!seller) {
          expect(find.text('SELLER TOOLS'), findsNothing);
        }
        expect(
          tester.getTopLeft(find.text('MAIN')).dy,
          lessThan(tester.getTopLeft(find.text('Home')).dy),
        );
        expect(
          tester
              .widget<CampusHubDrawer>(find.byType(CampusHubDrawer))
              .destinations
              .first,
          SellerDestination.overview,
        );
        expect(find.text('Suggested Product Bundles'), findsNothing);
        expect(
          tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
          Colors.white,
        );
        expect(
          tester
              .widget<Text>(find.text('Test Student Seller'))
              .style
              ?.fontFamily,
          'Montserrat',
        );
        for (final (label, weight) in [
          ('Test Student Seller', FontWeight.w600),
          ('BFPT \u00b7 2-A', FontWeight.w400),
          ('MAIN', FontWeight.w600),
          ('MESSAGES', FontWeight.w600),
        ]) {
          await tester.scrollUntilVisible(find.text(label), 100);
          final style = tester.widget<Text>(find.text(label)).style!;
          expect(
            style.fontFamily,
            ['Test Student Seller', 'BFPT \u00b7 2-A'].contains(label)
                ? 'Montserrat'
                : 'Inter',
          );
          expect(style.fontWeight, weight);
          expect(style.fontVariations!.single.value, weight.value.toDouble());
        }
        await tester.scrollUntilVisible(find.byTooltip('Open Profile'), -100);
        await tester.ensureVisible(find.byTooltip('Open Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(CircleAvatar), findsOneWidget);
        final systemStyle = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find
                  .descendant(
                    of: find.byType(CampusHubDrawer),
                    matching: find.byType(
                      AnnotatedRegion<SystemUiOverlayStyle>,
                    ),
                  )
                  .first,
            )
            .value;
        expect(systemStyle.statusBarIconBrightness, Brightness.dark);
        expect(systemStyle.systemNavigationBarColor, Colors.white);
        expect(systemStyle.systemNavigationBarIconBrightness, Brightness.dark);
        expect(
          tester.widget<Text>(find.text('Test Student Seller')).style!.color,
          const Color(0xFF0B1F3A),
        );

        final background = tester
            .widget<Drawer>(find.byType(Drawer))
            .backgroundColor!;
        final foreground = tester
            .widget<Text>(find.text('BFPT \u00b7 2-A'))
            .style!
            .color!;
        final a = background.computeLuminance(),
            b = foreground.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
          greaterThanOrEqualTo(4.5),
        );
        await tester.ensureVisible(find.byTooltip('Open Profile'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open Profile'));
        expect(profileOpens, 1);
        for (final destination in destinations) {
          final target = find.byKey(
            ValueKey('seller-menu-${destination.name}'),
          );
          await tester.scrollUntilVisible(target, 130);
          await Scrollable.ensureVisible(tester.element(target), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected, destination);
          // Selected row: light-gray surface plus a narrow gold indicator.
          expect(
            find.byKey(ValueKey('seller-menu-indicator-${destination.name}')),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Positioned &&
                  widget.key.toString().contains('seller-menu-indicator'),
            ),
            findsOneWidget,
          );
          final menuStyle = tester
              .widget<Text>(find.text(destination.label))
              .style!;
          expect(menuStyle.color, const Color(0xFF0B1F3A));
          expect(menuStyle.fontWeight, FontWeight.w500);
          expect(menuStyle.fontVariations!.single.value, 500);

          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expect(
            tester.widget<Text>(find.text(destination.label)).style?.fontFamily,
            'Inter',
          );
          expect(
            find.descendant(
              of: target,
              matching: find.byIcon(Iconsax.arrow_right_3_copy),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        if (!seller) {
          for (final restricted in CampusHubDrawer.sellerDestinations) {
            expect(
              find.byKey(ValueKey('seller-menu-${restricted.name}')),
              findsNothing,
            );
          }
        }
        expect(
          tester
              .getSize(find.byKey(const ValueKey('campushub-drawer-logout')))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(find.text('Logout'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'missing academic fields use real username without fake identity or email',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusHubDrawer(
              user: AuthUser.fromJson({
                'id': 1,
                'username': 'existing-user',
                'email': 'private@example.test',
              }),
              sellerApproved: false,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('existing-user'), findsOneWidget);
      expect(find.textContaining('Year / Section'), findsNothing);
      expect(find.textContaining('private@example.test'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Logout confirmation preserves session on cancel and clears it on confirm',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'campushub_logged_user': '{"id":71}',
        'campushub_chat_token': 'test-only',
        'campushub_remember_me': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.login: (_) =>
                const Scaffold(body: Text('Existing login route')),
          },
          home: Scaffold(
            drawer: CampusHubDrawer(
              user: drawerUser,
              sellerApproved: false,
              onSelected: (_) {},
            ),
            body: const Text('Home'),
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.containsKey('campushub_logged_user'), isTrue);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
      await tester.pumpAndSettle();
      expect(find.text('Existing login route'), findsOneWidget);
      expect(prefs.containsKey('campushub_logged_user'), isFalse);
      expect(prefs.containsKey('campushub_chat_token'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
