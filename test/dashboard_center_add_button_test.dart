import 'package:campushub/module_app/screens/dashboard_screen.dart';
import 'package:campushub/module_app/widgets/navigation/floating_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('dashboard uses five tabs without plus and retains Messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();
    final nav = tester.widget<FloatingBottomNavbar>(
      find.byType(FloatingBottomNavbar),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
      isTrue,
    );
    final homeList = find.byKey(const PageStorageKey('home-scroll'));
    final listPadding =
        tester.widget<ListView>(homeList).padding! as EdgeInsets;
    expect(
      listPadding.bottom,
      32 + MediaQuery.paddingOf(tester.element(homeList)).bottom,
    );
    final pill = find.byKey(const Key('floating-navbar-pill'));
    final dockRect = tester.getRect(pill);
    expect(tester.getRect(homeList).bottom, greaterThan(dockRect.bottom));
    await tester.drag(homeList, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(pill), dockRect);
    expect(nav.effectiveItems.map((e) => e.label), [
      'Home',
      'Marketplace',
      'Services',
      'Facilities',
      'Profile',
    ]);
    expect(nav.onCenterActionTap, isNull);
    expect(find.byKey(const Key('navbar-center-add-button')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).drawer,
      isNotNull,
    );
    expect(find.byTooltip('Messages'), findsNothing);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Messages')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingBottomNavbar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reusable center action remains available for later', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingBottomNavbar(
            currentIndex: 0,
            onTap: (_) {},
            onCenterActionTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('navbar-center-add-button')));
    expect(tapped, isTrue);
  });
}
