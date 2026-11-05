import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:campushub/module_app/widgets/navigation/add_product_navigation_icon.dart';

void main() {
  testWidgets('AddProductNavigationIcon uses the Iconsax product-add glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AddProductNavigationIcon(size: 26))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Iconsax.box_add_copy), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      tester.getSize(find.byType(AddProductNavigationIcon)),
      const Size(26, 26),
    );
    expect(tester.takeException(), isNull);
  });
}
