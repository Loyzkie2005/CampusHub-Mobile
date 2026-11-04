import 'dart:io';
import 'dart:ui' as ui;
import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/widgets/navigation/seller_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render Home-first drawer for both roles and themes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final font in {
        'Montserrat': 'assets/fonts/Montserrat-VariableFont_wght.ttf',
        'Inter': 'assets/fonts/inter/InterVariable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'packages/iconsax_flutter/FlutterIconsax':
            'packages/iconsax_flutter/fonts/FlutterIconsax.ttf',
      }.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load(font.value))).load();
      }
    });
    final user = AuthUser.fromJson({
      'id': 71,
      'username': 'sidebar-test',
      'full_name': 'Test Student',
      'program': 'BSIT',
      'year_section': '2-A',
    });
    for (final seller in [false, true]) {
      for (final dark in [false, true]) {
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: CampusHubDrawer(
                  user: user,
                  sellerApproved: seller,
                  selected: SellerDestination.overview,
                  onSelected: (_) {},
                  onProfile: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('MAIN'), findsOneWidget);
        expect(find.text('My Purchases'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Seller Dashboard'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File(
            '../scratch/seller-sidebar-design-b-20261104/${seller ? 'seller' : 'regular'}-${dark ? 'dark' : 'light'}.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
