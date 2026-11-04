import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:campushub/module_app/widgets/navigation/floating_bottom_navbar.dart';
import 'package:campushub/module_app/widgets/navigation/home_navigation_icon.dart';
import 'package:campushub/module_app/widgets/navigation/add_product_navigation_icon.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 812), 2.0),
    (const Size(320, 812), 3.0),
    (const Size(390, 844), 1.0),
    (const Size(844, 390), 2.0),
  ]) {
    testWidgets('seller action fits $size/$scale and never selects a page', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = 2, added = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (_, update) => Scaffold(
              bottomNavigationBar: FloatingBottomNavbar(
                currentIndex: selected,
                onTap: (index) => update(() => selected = index),
                onCenterActionTap: () => added++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.byKey(const Key('navbar-center-add-button'));
      expect(tester.getSize(add).shortestSide, greaterThanOrEqualTo(48));
      final circle = find.byKey(const Key('navbar-center-add-circle'));
      expect(find.byType(AddProductNavigationIcon), findsOneWidget);
      expect(tester.getSize(circle), const Size(56, 56));
      expect(
        (tester.widget<Container>(circle).decoration! as BoxDecoration).shape,
        BoxShape.circle,
      );
      final bar = tester.getRect(find.byKey(const Key('floating-navbar-pill')));
      final frame = tester.getRect(
        find.byKey(const Key('floating-navbar-frame')),
      );
      expect(tester.getRect(circle).top, greaterThanOrEqualTo(frame.top));
      expect(tester.getRect(circle).top, lessThan(bar.top));
      expect(
        tester.getRect(circle).top,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('navbar-icon-0'))).top,
        ),
      );
      expect(
        (tester.getRect(find.text('Add Product')).top -
                tester.getRect(find.text('Home')).top)
            .abs(),
        lessThan(2),
      );
      expect(find.text('Profile'), findsNothing);
      for (final label in [
        'Home',
        'Marketplace',
        'Add Product',
        'Services',
        'Facilities',
      ]) {
        expect(find.text(label), findsOneWidget);
        final text = tester.widget<Text>(find.text(label));
        final style = DefaultTextStyle.of(
          tester.element(find.text(label)),
        ).style.merge(text.style);
        expect(style.fontFamily, 'Inter');
        expect(style.fontWeight, FontWeight.w500);
        expect(style.fontVariations!.single.value, 500);
      }
      expect(
        tester.getCenter(find.text('Add Product')).dx,
        greaterThan(tester.getCenter(find.text('Marketplace')).dx),
      );
      expect(
        tester.getCenter(find.text('Add Product')).dx,
        lessThan(tester.getCenter(find.text('Services')).dx),
      );
      expect(
        tester.getRect(find.text('Marketplace')).right,
        lessThanOrEqualTo(tester.getRect(find.text('Add Product')).left - 4),
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(added, 1);
      expect(selected, 2);
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byKey(ValueKey('navbar-item-$index')));
        await tester.pumpAndSettle();
        expect(selected, index);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selection animation remains interruptible without moving the bar or renaming tabs',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) => Scaffold(
              bottomNavigationBar: FloatingBottomNavbar(
                currentIndex: selected,
                onTap: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      );
      final bar = find.byKey(const Key('floating-navbar-pill'));
      final bounds = tester.getRect(bar);
      await tester.tap(find.byKey(const ValueKey('navbar-item-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('navbar-shift-1')),
      );
      expect(transform.transform.storage[13], lessThan(0));
      expect(transform.transform.storage[13], greaterThan(-2));
      await tester.tap(find.byKey(const ValueKey('navbar-item-4')));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.getRect(bar), bounds);
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('navbar-icon-4'))).icon,
        Iconsax.user,
      );
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('navbar-shift-1')))
            .transform
            .storage[13],
        0,
      );
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('navbar-shift-4')))
            .transform
            .storage[13],
        -2,
      );
      expect(find.text('Marketplace'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('navbar destinations pair outline icons with filled active icons', () {
    expect(FloatingBottomNavbar.default5Items.map((item) => item.icon), [
      Iconsax.home_copy,
      Iconsax.shop_copy,
      Iconsax.briefcase_copy,
      Iconsax.building_copy,
      Iconsax.user_copy,
    ]);
    expect(FloatingBottomNavbar.default5Items.map((item) => item.activeIcon), [
      Iconsax.home,
      Iconsax.shop,
      Iconsax.briefcase,
      Iconsax.building,
      Iconsax.user,
    ]);
    expect(
      FloatingBottomNavbar.defaultCenterActionItems.map((item) => item.icon),
      [
        Iconsax.home_copy,
        Iconsax.shop_copy,
        Iconsax.briefcase_copy,
        Iconsax.building_copy,
      ],
    );
  });
  test('navy text and icons retain readable palette contrast', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
    }

    expect(
      contrast(const Color(0xFF1A1851), Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(
        Color.alphaBlend(const Color(0x9E1A1851), Colors.white),
        Colors.white,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
  testWidgets(
    'large text and reduced motion preserve selected glyph without an indicator container',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              bottomNavigationBar: FloatingBottomNavbar(
                currentIndex: 2,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The active glyph/semantics carry selection without a background box.
      expect(find.byKey(const ValueKey('navbar-indicator-2')), findsNothing);
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('navbar-icon-2'))).icon,
        Iconsax.briefcase,
      );
      for (final item in FloatingBottomNavbar.default5Items) {
        final label = tester.widget<Text>(find.text(item.label));
        expect(label.textScaler, TextScaler.noScaling);
        expect(find.byTooltip(item.label), findsOneWidget);
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('navbar-item-2'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .widget<TweenAnimationBuilder<double>>(
              find.byKey(const ValueKey('navbar-motion-2')),
            )
            .duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('Floating navbar fits and switches tabs at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      var selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              backgroundColor: Colors.white,
              body: ListView.builder(
                key: const Key('page-body'),
                itemCount: 50,
                itemBuilder: (_, index) =>
                    SizedBox(height: 90, child: Text('Section $index')),
              ),
              bottomNavigationBar: FloatingBottomNavbar(
                currentIndex: selectedIndex,
                onTap: (index) => setState(() => selectedIndex = index),
              ),
            ),
          ),
        ),
      );

      final pillFinder = find.byKey(const Key('floating-navbar-pill'));
      final initialRect = tester.getRect(pillFinder);
      final expectedWidth = width - 24 < 620 ? width - 24 : 620.0;
      expect(initialRect.width, expectedWidth);
      expect(initialRect.left, (width - expectedWidth) / 2);
      expect(initialRect.right, (width + expectedWidth) / 2);
      expect(initialRect.bottom, 764);
      final surface =
          tester.widget<DecoratedBox>(pillFinder).decoration as BoxDecoration;
      expect(surface.borderRadius, BorderRadius.circular(28));
      expect(surface.color, Colors.white);
      final ink = tester.widget<InkResponse>(
        find.byKey(const ValueKey('navbar-item-0')),
      );
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.splashColor, Colors.transparent);
      expect(ink.hoverColor, Colors.transparent);
      expect(ink.highlightColor, Colors.transparent);
      expect(ink.customBorder, isA<CircleBorder>());
      expect(ink.focusColor, const Color(0xFF1A1851).withValues(alpha: 0.12));
      expect(
        tester.getRect(find.byKey(const Key('page-body'))).bottom,
        lessThanOrEqualTo(initialRect.top),
      );
      // Scroll real sections in both directions; the floating dock stays fixed.
      for (final delta in [-600.0, 300.0]) {
        await tester.drag(find.byKey(const Key('page-body')), Offset(0, delta));
        await tester.pumpAndSettle();
        expect(tester.getRect(pillFinder), initialRect);
        expect(
          find.byKey(const ValueKey('navbar-item-0')).hitTestable(),
          findsOneWidget,
        );
      }

      // Verify text labels are shown
      const labels = [
        'Home',
        'Marketplace',
        'Services',
        'Facilities',
        'Profile',
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }

      // Verify tapping each icon switches tabs
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(ValueKey('navbar-item-$index')));
        await tester.pumpAndSettle();
        expect(selectedIndex, index);
        for (var tab = 0; tab < 5; tab++) {
          expect(find.byKey(ValueKey('navbar-indicator-$tab')), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(ValueKey('navbar-item-$tab')),
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
          expect(
            tester
                .getSize(find.byKey(ValueKey('navbar-item-$tab')))
                .shortestSide,
            greaterThanOrEqualTo(48),
          );
        }
        for (var itemIndex = 0; itemIndex < 5; itemIndex++) {
          if (itemIndex == 0) {
            final home = find.descendant(
              of: find.byKey(const ValueKey('navbar-item-0')),
              matching: find.byType(HomeNavigationIcon),
            );
            expect(home, findsOneWidget);
            expect(
              IconTheme.of(tester.element(home)).color,
              index == 0 ? const Color(0xFF1A1851) : const Color(0x9E1A1851),
            );
            expect(
              tester.widget<HomeNavigationIcon>(home).outlined,
              index != 0,
            );
            continue;
          }
          final icon = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey('navbar-item-$itemIndex')),
              matching: find.byType(Icon),
            ),
          );
          expect(
            icon.icon,
            itemIndex == index
                ? FloatingBottomNavbar
                      .default5Items[itemIndex]
                      .effectiveActiveIcon
                : FloatingBottomNavbar.default5Items[itemIndex].icon,
          );
          expect(
            icon.color,
            itemIndex == index
                ? const Color(0xFF1A1851)
                : const Color(0x9E1A1851),
          );
        }
        for (var itemIndex = 0; itemIndex < 5; itemIndex++) {
          final semanticsData = tester
              .getSemantics(find.byKey(ValueKey('navbar-semantics-$itemIndex')))
              .getSemanticsData();
          expect(
            semanticsData.label,
            FloatingBottomNavbar.default5Items[itemIndex].label,
          );
          expect(
            semanticsData.flagsCollection.isSelected == ui.Tristate.isTrue,
            itemIndex == index,
          );
        }
        expect(tester.getRect(pillFinder), initialRect);
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    });
  }

  testWidgets('optional floating navigation render evidence', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_FLOATING_NAV')) return;
    final originalShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await tester.runAsync(() async {
        await (FontLoader(
              'Inter',
            )..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf')))
            .load();
        await (FontLoader('packages/iconsax_flutter/FlutterIconsax')..addFont(
              rootBundle.load(
                'packages/iconsax_flutter/fonts/FlutterIconsax.ttf',
              ),
            ))
            .load();
      });
      for (final (size, scale, seller) in [
        (const Size(390, 844), 1.0, false),
        (const Size(390, 844), 1.0, true),
        (const Size(320, 812), 2.0, true),
        (const Size(844, 390), 2.0, false),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                extendBody: true,
                backgroundColor: const Color(0xFFF7F8FC),
                body: ListView.builder(
                  key: const Key('preview-sections'),
                  itemCount: 30,
                  itemBuilder: (_, index) => ColoredBox(
                    color: index.isEven
                        ? const Color(0xFFF7F8FC)
                        : const Color(0xFFFFF4D8),
                    child: SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Section $index',
                          style: const TextStyle(fontFamily: 'Inter'),
                        ),
                      ),
                    ),
                  ),
                ),
                bottomNavigationBar: FloatingBottomNavbar(
                  currentIndex: 1,
                  onTap: (_) {},
                  onCenterActionTap: seller ? () {} : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pill = find.byKey(const Key('floating-navbar-pill'));
        final fixedRect = tester.getRect(pill);
        Future<void> captureDock(String state) async {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final screenshot = await boundary.toImage(pixelRatio: 2);
            final png = await screenshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory(
              Platform.environment['FLOATING_NAV_REVIEW_DIR'] ??
                  '../scratch/floating-navbar-no-selection-20261030',
            )..createSync(recursive: true);
            File(
              '${folder.path}/nav-${size.width}-$scale-$seller-$state.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
            screenshot.dispose();
          });
        }

        await captureDock('rest');
        final pressed = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('navbar-item-1'))),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await captureDock('pressed');
        await pressed.up();
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const Key('preview-sections')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(pill), fixedRect);
        expect(
          find.byKey(const ValueKey('navbar-item-1')).hitTestable(),
          findsOneWidget,
        );
        if (seller) {
          final center = tester.widget<InkResponse>(
            find.byKey(const Key('navbar-center-add-button')),
          );
          expect(center.splashFactory, NoSplash.splashFactory);
          expect(center.splashColor, Colors.transparent);
        }
        await captureDock('scrolled');
        expect(tester.takeException(), isNull);
      }
    } finally {
      debugDisableShadows = originalShadows;
    }
  });
}
