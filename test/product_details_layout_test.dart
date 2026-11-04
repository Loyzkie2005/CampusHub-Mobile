import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/models/product_item.dart';
import 'package:campushub/module_app/services/product_ownership.dart';
import 'package:campushub/module_app/theme/app_typography.dart';
import 'package:campushub/module_app/screens/checkout_screen.dart';
import 'package:campushub/module_app/screens/product_details_screen.dart';
import 'package:campushub/module_app/services/cart_service.dart';
import 'package:campushub/module_app/services/favorite_service.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Isolated API-shaped data, never inserted into Django or a live catalog.
Map<String, dynamic> productRow() => {
  'id': 42,
  'seller_id': 99,
  'seller_ref': 'admin:99',
  'name': 'Campus Shirt',
  'price': '250',
  'category': 'Clothing',
  'seller': 'Test Campus Seller',
  'description': 'A comfortable campus shirt with a relaxed fit.',
  'stock': 27,
  'submitted_at': DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 1))
      .toIso8601String(),
  'customization_enabled': true,
  'customization_options': [
    {
      'name': 'Size',
      'selection': 'single',
      'required': true,
      'options': [
        {'name': 'S', 'stock': 7, 'extra_price': '0'},
        {'name': 'M', 'stock': 9, 'extra_price': '10'},
        {'name': 'L', 'stock': 11, 'extra_price': '20'},
      ],
    },
    {
      'name': 'Print',
      'selection': 'multiple',
      'required': false,
      'options': [
        {'name': 'Front', 'extra_price': '5'},
        {'name': 'Back', 'extra_price': '8'},
      ],
    },
  ],
};

// Requested demonstration only: never sent to a live backend/catalog.
Map<String, dynamic> variantSampleRow() => productRow()
  ..['name'] = 'Sample Campus Shirt'
  ..['customization_options'] = [
    {
      'name': 'Color',
      'required': true,
      'options': [
        {'name': 'Navy'},
        {'name': 'White'},
        {'name': 'Gold'},
      ],
    },
    {
      'name': 'Size',
      'required': true,
      'options': [
        {'name': 'L'},
      ],
    },
  ];

Future<void> withCatalog(Future<void> Function() body) => http.runWithClient(
  body,
  () => MockClient((request) async {
    if (request.url.path.contains('/conversations')) {
      throw http.ClientException('Presence unavailable in isolated UI test');
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/products/interaction/')) {
      final data = jsonDecode(request.body);
      return http.Response(
        jsonEncode({'allowed': true, 'product_id': data['product_id']}),
        200,
      );
    }
    expect(request.method, 'GET');
    return http.Response(jsonEncode({'products': []}), 200);
  }),
);

Future<void> showProduct(
  WidgetTester tester, {
  Map<String, dynamic>? row,
  Size size = const Size(375, 812),
  double scale = 1,
  bool reduceMotion = true,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  double bottomInset = 0,
  bool owner = false,
  bool settle = true,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final p = ProductItem.fromJson(row ?? productRow());
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
          highContrast: highContrast,
          padding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: capture,
        child: ProductDetailsScreen(
          id: p.id,
          userId:
              99999, // Route data must not override the authenticated viewer.
          sellerId: p.sellerId,
          sellerRef: owner ? 'mobile:7' : p.sellerRef,
          name: p.name,
          priceLabel: p.price,
          imageUrl: p.imageUrl,
          images: p.images,
          category: p.category,
          seller: p.seller,
          sellerPhotoUrl: p.sellerPhotoUrl,
          description: p.description,
          stock: p.stock,
          soldCount: p.soldCount,
          rating: p.rating,
          reviewsCount: p.reviewsCount,
          submittedAt: p.submittedAt,
          inventoryStatus: p.inventoryStatus,
          isPurchasable: p.isPurchasable,
          customization: p.customization,
          approvalStatus: owner ? 'pending' : '',
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String group, String name) async {
  final chip = find.byKey(ValueKey('variant-$group-$name'));
  await tester.scrollUntilVisible(
    chip,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'campushub_logged_user': jsonEncode({'id': 7, 'role': 'User'}),
      'campushub_chat_token': 'isolated-product-test-token',
    });
    await CartService.instance.clear();
  });

  test('ownership retains mobile/admin namespaces and unknown identities', () {
    expect(ownsProduct(7, sellerRef: 'mobile:7'), isTrue);
    expect(ownsProduct(7, sellerRef: 'mobile:8'), isFalse);
    expect(ownsProduct(7, sellerRef: 'admin:7'), isFalse);
    expect(ownsProduct(7, sellerId: 7), isFalse);
    expect(ownsProduct(null, sellerRef: 'mobile:7'), isNull);
    expect(ownsProduct(7), isNull);
    expect(ownsProduct(7, sellerRef: 'mobile:bad', sellerId: 7), isNull);
  });

  for (final (reference, expectedBuyer) in [
    ('mobile:7', false),
    ('mobile:8', true),
    ('admin:7', true),
    ('', false),
  ]) {
    testWidgets(
      'actual owner $reference automatically controls actions without seller-role gating',
      (tester) async => withCatalog(() async {
        SharedPreferences.setMockInitialValues({
          'campushub_logged_user': jsonEncode({'id': 7, 'role': 'Seller'}),
          'campushub_chat_token': 'isolated-product-token',
        });
        final row = productRow()
          ..['seller_ref'] = reference
          ..['seller_id'] = null;
        await showProduct(tester, row: row, settle: false);
        expect(
          tester
              .widget<Scaffold>(find.byType(Scaffold).first)
              .bottomNavigationBar,
          isNull,
        );
        expect(find.byTooltip('Add to favorites'), findsNothing);
        await tester.pumpAndSettle();
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.bottomNavigationBar == null, !expectedBuyer);
        expect(
          find.text('Chat'),
          expectedBuyer ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Buy Now'),
          expectedBuyer ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Add to Cart'),
          expectedBuyer ? findsOneWidget : findsNothing,
        );
        expect(
          find.byTooltip('Add to favorites'),
          expectedBuyer ? findsOneWidget : findsNothing,
        );
        expect(find.text('Manage Product'), findsNothing);
        expect(find.byKey(const ValueKey('product-overview')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('product-seller-section')),
          findsOneWidget,
        );
        final scrollRect = tester.getRect(find.byType(CustomScrollView).first);
        if (!expectedBuyer) {
          expect(scrollRect.bottom, tester.view.physicalSize.height);
        }
        await tester.scrollUntilVisible(
          find.text('You May Also Like'),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('You May Also Like'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('product-reviews-heading')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }),
    );
  }

  testWidgets(
    'missing authenticated user never exposes buyer actions',
    (tester) async => withCatalog(() async {
      SharedPreferences.setMockInitialValues({});
      await showProduct(tester);
      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .bottomNavigationBar,
        isNull,
      );
      expect(find.byTooltip('Add to favorites'), findsNothing);
      expect(find.text('Buy Now'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'owner recommendations retain real rows and opening another owner restores buyer actions',
    (tester) async {
      final otherRow = productRow()
        ..['id'] = 43
        ..['name'] = 'Another seller product'
        ..['seller_ref'] = 'mobile:8';
      var recommendationReads = 0;
      await http.runWithClient(
        () async {
          await showProduct(tester, owner: true);
          await tester.scrollUntilVisible(
            find.text('You May Also Like'),
            260,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Another seller product'), findsOneWidget);
          expect(recommendationReads, greaterThan(0));
          await tester.ensureVisible(find.text('Another seller product'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Another seller product'));
          await tester.pumpAndSettle();
          expect(find.text('Buy Now'), findsOneWidget);
          expect(find.text('Chat'), findsOneWidget);
          expect(find.text('Add to Cart'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.url.path.contains('/conversations')) {
            throw http.ClientException('Isolated presence');
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'message': 'Interaction recorded.'}),
              201,
            );
          }
          if (request.url.path.contains('/products/recommended/')) {
            expect(request.url.queryParameters['user_id'], '7');
            recommendationReads++;
            return http.Response(
              jsonEncode({
                'products': [otherRow],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'products': []}), 200);
        }),
      );
    },
  );

  testWidgets(
    'backend ownership denial prevents local cart and favorite writes',
    (tester) async {
      await http.runWithClient(
        () async {
          await showProduct(tester);
          await tester.tap(find.byTooltip('Add to favorites'));
          await tester.pumpAndSettle();
          expect(FavoriteService.instance.isFavorite('id:42'), isFalse);
          await choose(tester, 'Size', 'M');
          await tester.tap(find.text('Add to Cart'));
          await tester.pumpAndSettle();
          expect(CartService.instance.items, isEmpty);
          expect(
            find.text('You cannot purchase your own product.'),
            findsWidgets,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'error': 'You cannot purchase your own product.'}),
              403,
            );
          }
          if (request.url.path.contains('/conversations')) {
            throw http.ClientException('No isolated chat');
          }
          return http.Response(jsonEncode({'products': []}), 200);
        }),
      );
    },
  );

  testWidgets(
    'titleless gallery header uses circular controls and a readable collapsed surface',
    (tester) async => withCatalog(() async {
      await showProduct(tester);
      expect(find.byKey(const ValueKey('sample-variants-label')), findsNothing);
      expect(find.text('Product Details'), findsNothing);
      final header = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(header.backgroundColor, Colors.white);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        Colors.white,
      );
      final heroImage = tester.widget<ProductImage>(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(ProductImage),
        ),
      );
      expect(heroImage.backgroundColor, Colors.transparent);
      expect(heroImage.fit, BoxFit.contain);
      expect(header.surfaceTintColor, Colors.transparent);
      expect(header.title, isNull);
      expect(header.flexibleSpace, isA<FlexibleSpaceBar>());
      for (final tooltip in ['Back', 'Cart', 'Add to favorites']) {
        final control = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
        );
        final button = tester.widget<IconButton>(control);
        expect(button.style!.shape!.resolve({}), isA<CircleBorder>());
        expect(
          button.style!.backgroundColor!.resolve({}),
          const Color(0xFFEEF0F3),
        );
        expect(button.style!.side!.resolve({}), BorderSide.none);
        expect(tester.getSize(control), const Size(48, 48));
      }
      final back = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Back',
        ),
      );
      expect((back.icon as Icon).icon, LucideIcons.chevronLeft);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Clothing'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Quantity'), findsNothing);
      expect(find.byType(Divider), findsNothing);
      for (final name in ['S', 'M', 'L']) {
        final chip = tester.widget<FilterChip>(
          find.byKey(ValueKey('variant-Size-$name')),
        );
        expect((chip.label as Text).data, name);
        expect(chip.avatar, isNull);
        expect(
          tester.getSize(find.byKey(ValueKey('variant-Size-$name'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(find.textContaining('Stock:'), findsNothing);
      final pageView = find.byType(PageView);
      final indicators = find.byKey(const ValueKey('product-image-indicators'));
      expect(indicators, findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('product-overview'))).dy,
        closeTo(tester.getBottomLeft(pageView).dy + 16, .1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'review summary shows supplied average and scrolls to the matching review section',
    (tester) async => withCatalog(() async {
      final row = productRow()
        ..['rating'] = 4.8
        ..['reviews_count'] = 12;
      await showProduct(tester, row: row);
      final summary = find.byKey(const ValueKey('product-review-summary'));
      final stars = find.byKey(const ValueKey('product-summary-stars'));
      final name = find.byKey(const ValueKey('product-heading-name'));
      final price = find.byKey(const ValueKey('product-selected-price'));
      final value = find.byKey(const ValueKey('product-rating-value'));
      expect(tester.widget<Text>(value).data, '4.8 (12)');
      expect(
        tester.getTopLeft(summary).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(name).dy),
      );
      expect(
        tester.getTopLeft(price).dy,
        closeTo(tester.getTopLeft(name).dy, 0.1),
      );
      expect(
        tester.getTopLeft(value).dx,
        closeTo(tester.getTopRight(stars).dx + 8, 0.1),
      );
      final partial = find.descendant(
        of: stars,
        matching: find.byKey(const ValueKey('rating-star-fill-4')),
      );
      expect(tester.widget<Align>(partial).widthFactor, closeTo(0.8, 0.001));
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(summary).label,
        contains('4.8 out of 5 stars from 12 reviews'),
      );
      expect(
        tester
            .getSemantics(summary)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(summary);
      await tester.pumpAndSettle();
      final heading = find.byKey(const ValueKey('product-reviews-heading'));
      final rect = tester.getRect(heading);
      expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
      expect(rect.bottom, lessThan(tester.getTopLeft(find.text('Buy Now')).dy));
      expect(find.text('4.8 / 5 (12 reviews)'), findsOneWidget);
      expect(
        find.text('Individual reviews are not available yet.'),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'missing or invalid review data never fabricates a rating',
    (tester) async => withCatalog(() async {
      for (final (rating, count) in <(Object?, int)>[
        (null, 0),
        (4.8, 0),
        (-1, 3),
        (6, 2),
        ('NaN', 2),
        ('Infinity', 2),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await showProduct(
          tester,
          row: productRow()
            ..['rating'] = rating
            ..['reviews_count'] = count,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('product-rating-value')))
              .data,
          'No reviews yet',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('product-summary-stars')),
            matching: find.byIcon(Icons.star_rounded),
          ),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('product-review-summary')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('product-review-details-state')),
              )
              .data,
          'No reviews yet',
        );
        expect(find.textContaining('Be the first'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'review summary reflows long names and large counts at narrow width',
    (tester) async => withCatalog(() async {
      await showProduct(
        tester,
        size: const Size(320, 700),
        scale: 2,
        row: productRow()
          ..['name'] = 'Campus Shirt With A Long Saved Product Name'
          ..['rating'] = 4.8
          ..['reviews_count'] = 1234567890,
      );
      final summary = find.byKey(const ValueKey('product-review-summary'));
      await tester.ensureVisible(summary);
      await tester.pumpAndSettle();
      expect(tester.getSize(summary).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('product-rating-value')))
            .right,
        lessThanOrEqualTo(304),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'favorite circle reacts to saved state and top cart count updates',
    (tester) async => withCatalog(() async {
      final row = productRow()
        ..['customization_enabled'] = false
        ..['customization_options'] = [];
      await showProduct(tester, row: row);
      final key = favoriteKeyForProduct(id: 42, name: 'Campus Shirt');
      if (FavoriteService.instance.isFavorite(key)) {
        await FavoriteService.instance.toggle(key);
        await tester.pumpAndSettle();
      }
      final addFavIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Add to favorites'),
          matching: find.byType(Icon),
        ),
      );
      expect(addFavIcon.color, const Color(0xFF1A1851));
      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();
      expect(FavoriteService.instance.isFavorite(key), isTrue);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      final savedFavoriteButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Remove from favorites',
        ),
      );
      expect(
        savedFavoriteButton.style!.backgroundColor!.resolve({}),
        const Color(0xFFEEF0F3),
      );
      final removeFavIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Remove from favorites'),
          matching: find.byType(Icon),
        ),
      );
      expect(removeFavIcon.color, const Color(0xFF1A1851));
      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();
      expect(FavoriteService.instance.isFavorite(key), isFalse);
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(CartService.instance.itemCount, 1);
      expect(
        find.descendant(of: find.byTooltip('Cart'), matching: find.text('1')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'badge uses real listing age or supplied sales, never a blanket New fallback',
    (tester) async => withCatalog(() async {
      for (final (row, expected) in [
        (productRow()..['sold_count'] = 3, 'Hot'),
        (
          productRow()
            ..['submitted_at'] = DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 8))
                .toIso8601String(),
          null,
        ),
        (productRow()..remove('submitted_at'), null),
        (
          productRow()
            ..['submitted_at'] = DateTime.now()
                .toUtc()
                .add(const Duration(days: 1))
                .toIso8601String(),
          null,
        ),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await showProduct(tester, row: row);
        final badge = find.byKey(const ValueKey('product-listing-badge'));
        if (expected == null) {
          expect(badge, findsNothing);
        } else {
          expect(
            find.descendant(of: badge, matching: find.text(expected)),
            findsOneWidget,
          );
          expect(
            tester.getTopRight(badge).dx,
            lessThanOrEqualTo(tester.getTopLeft(find.text('Campus Shirt')).dx),
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'all product detail text uses the existing UI font including owner review status',
    (tester) async => withCatalog(() async {
      for (final owner in [false, true]) {
        await showProduct(tester, owner: owner);
        for (final element
            in find
                .descendant(
                  of: find.byType(ProductDetailsScreen),
                  matching: find.byType(Text),
                )
                .evaluate()) {
          final text = element.widget as Text;
          final style = DefaultTextStyle.of(element).style.merge(text.style);
          expect(style.fontFamily, AppTypography.family, reason: text.data);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'required choices block checkout, selected API options reach checkout once',
    (tester) async => withCatalog(() async {
      await showProduct(tester);
      await tester.tap(find.text('Buy Now'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen), findsNothing);
      expect(find.text('Please choose Size.'), findsWidgets);
      await choose(tester, 'Size', 'M');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('product-selected-price')))
            .textSpan!
            .toPlainText(),
        '\u20b1260',
      );
      await choose(tester, 'Print', 'Front');
      await choose(tester, 'Print', 'Back');
      await tester.tap(find.text('Buy Now'));
      await tester.pumpAndSettle();
      final checkout = tester.widget<CheckoutScreen>(
        find.byType(CheckoutScreen),
      );
      expect(checkout.selection.quantity, 1);
      expect(checkout.category, 'Clothing');
      expect(checkout.selection.unitPrice, 273);
      expect(checkout.selection.customizationPayload, [
        {'group': 'Size', 'option': 'M', 'extra_price': '10.00'},
        {'group': 'Print', 'option': 'Front', 'extra_price': '5.00'},
        {'group': 'Print', 'option': 'Back', 'extra_price': '8.00'},
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'cart uses the same variant selection, price and one-item quantity',
    (tester) async => withCatalog(() async {
      await showProduct(tester);
      await choose(tester, 'Size', 'L');
      await choose(tester, 'Size', 'S');
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('variant-Size-L')))
            .selected,
        isFalse,
      );
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      final item = CartService.instance.items.single;
      expect(item.quantity, 1);
      expect(item.category, 'Clothing');
      expect(item.unitPrice, 250);
      expect(item.selections.single.option, 'S');
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'saved colors use circles and retain image selection; other options stay text',
    (tester) async => withCatalog(() async {
      const image =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6SukAAAAASUVORK5CYII=';
      const colorImage =
          'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
      final row = productRow()..['image_url'] = image;
      (row['customization_options'] as List).add({
        'name': 'Color',
        'options': [
          {'name': 'Navy', 'image': colorImage},
        ],
      });
      await showProduct(tester, row: row);
      final pagination = find.byKey(const ValueKey('product-image-indicators'));
      expect(tester.getSize(pagination).height, 48);
      expect(
        tester.getTopLeft(pagination).dy,
        closeTo(tester.getBottomLeft(find.byType(PageView)).dy, .1),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('product-overview'))).dy,
        closeTo(tester.getBottomLeft(pagination).dy, .1),
      );
      final swatch = tester.widget<Container>(
        find.byKey(const ValueKey('color-swatch-Color-Navy')),
      );
      expect((swatch.decoration as BoxDecoration).shape, BoxShape.circle);
      expect(
        (swatch.decoration as BoxDecoration).color,
        const Color(0xFF1A1851),
      );
      await choose(tester, 'Color', 'Navy');
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('variant-Color-Navy')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(find.text('Colors'), findsOneWidget);
      expect(find.text('Select color'), findsNothing);
      expect(find.text('Navy'), findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      final firstIndicator = find.bySemanticsLabel('Product image 1 of 2');
      expect(tester.getSize(firstIndicator), const Size(48, 48));
      await tester.tap(firstIndicator);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'description stays fully visible without expand/collapse controls',
    (tester) async => withCatalog(() async {
      final row = productRow()
        ..['description'] = List.filled(
          8,
          'Comfortable campus clothing for everyday activities.',
        ).join(' ');
      await showProduct(tester, row: row);
      final body = find.byKey(const ValueKey('product-description-text'));
      await tester.scrollUntilVisible(
        body,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(body).data, row['description']);
      expect(tester.widget<Text>(body).maxLines, isNull);
      expect(
        find.byKey(const ValueKey('product-description-toggle')),
        findsNothing,
      );
      expect(find.byType(AnimatedSize), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('product-variant-choices')))
            .dy,
        lessThan(tester.getTopLeft(find.text('Description')).dy),
      );
      await choose(tester, 'Size', 'M');
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('variant-Size-M')))
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'no saved variants hides the complete option section without fake choices',
    (tester) async => withCatalog(() async {
      final row = productRow()
        ..['customization_enabled'] = false
        ..['customization_options'] = [];
      await showProduct(tester, row: row, size: const Size(320, 700), scale: 2);
      expect(find.byKey(const ValueKey('sample-variants-label')), findsNothing);
      expect(find.text('No variants available.'), findsNothing);
      expect(find.text('Variants'), findsNothing);
      expect(
        find.byKey(const ValueKey('product-variant-choices')),
        findsNothing,
      );
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byKey(const ValueKey('variant-Color-Gold')), findsNothing);
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(CartService.instance.items.single.selections, isEmpty);
      expect(CartService.instance.items.single.unitPrice, 250);
      await tester.tap(find.text('Buy Now'));
      await tester.pumpAndSettle();
      final checkout = tester.widget<CheckoutScreen>(
        find.byType(CheckoutScreen),
      );
      expect(checkout.selection.quantity, 1);
      expect(checkout.selection.selections, isEmpty);
      expect(checkout.selection.unitPrice, 250);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'name and price share a row or stack, followed by reviews and saved content with all footer actions',
    (tester) async => withCatalog(() async {
      for (final (size, scale) in [
        (const Size(375, 812), 1.0),
        (const Size(320, 700), 2.0),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await showProduct(tester, size: size, scale: scale);
        final name = find.byKey(const ValueKey('product-heading-name'));
        await tester.scrollUntilVisible(
          name,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final seller = find.byKey(const ValueKey('product-heading-seller'));
        final sellerSection = find.byKey(
          const ValueKey('product-seller-section'),
        );
        final description = find.text('Description');
        final descriptionBody = find.byKey(
          const ValueKey('product-description-text'),
        );
        final options = find.byKey(const ValueKey('product-variant-choices'));
        final price = find.byKey(const ValueKey('product-selected-price'));
        expect(find.text('Test Campus Seller'), findsOneWidget);
        expect(
          tester.widget<Text>(seller).style!.fontSize,
          lessThan(tester.widget<Text>(name).style!.fontSize!),
        );
        expect(
          tester.getTopLeft(seller).dy,
          greaterThan(tester.getBottomLeft(name).dy),
        );
        if (scale > 1.4) {
          expect(tester.getTopLeft(price).dx, closeTo(20, 0.1));
          expect(
            tester.getTopLeft(price).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(name).dy),
          );
        } else {
          expect(
            tester.getTopLeft(price).dx,
            greaterThan(tester.getTopRight(name).dx),
          );
          expect(
            tester.getTopLeft(price).dy,
            closeTo(tester.getTopLeft(name).dy, .1),
          );
        }
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('product-variant-choices')))
              .dy,
          greaterThan(tester.getBottomLeft(price).dy),
        );
        expect(
          tester.getTopLeft(description).dy,
          closeTo(tester.getBottomLeft(options).dy + 24, 0.1),
        );
        expect(
          tester.getTopLeft(sellerSection).dy,
          closeTo(tester.getBottomLeft(descriptionBody).dy + 24, 0.1),
        );
        final dot = find.byKey(const ValueKey('product-seller-status-dot'));
        final status = find.byKey(const ValueKey('product-seller-status'));
        final avatar = find.byKey(const ValueKey('product-seller-photo'));
        expect(
          tester.getTopRight(avatar).dx,
          lessThan(tester.getTopLeft(seller).dx),
        );
        expect(
          tester.getTopLeft(status).dy,
          greaterThan(tester.getBottomLeft(seller).dy),
        );
        expect(
          tester.getTopLeft(dot).dx,
          closeTo(tester.getTopLeft(seller).dx, 0.1),
        );
        expect(find.text('Offline'), findsOneWidget);
        expect(find.byTooltip('Seller offline'), findsOneWidget);
        final chatBtn = find.byKey(
          const ValueKey('product-bottom-chat-button'),
        );
        final chatDivider = find.byKey(
          const ValueKey('product-bottom-chat-divider'),
        );
        final addToCartBtn = find.byKey(
          const ValueKey('product-bottom-add-to-cart-button'),
        );
        final buyNowBtn = find.widgetWithText(ElevatedButton, 'Buy Now');
        expect(chatBtn, findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
        expect(chatDivider, findsOneWidget);
        expect(addToCartBtn, findsOneWidget);
        expect(find.text('Add to Cart'), findsOneWidget);
        expect(
          tester.getTopRight(chatBtn).dx,
          lessThanOrEqualTo(tester.getTopLeft(chatDivider).dx),
        );
        expect(
          tester.getTopRight(chatDivider).dx,
          lessThanOrEqualTo(tester.getTopLeft(addToCartBtn).dx),
        );
        if (scale > 1.4) {
          expect(
            tester.getBottomLeft(addToCartBtn).dy,
            lessThanOrEqualTo(tester.getTopLeft(buyNowBtn).dy),
          );
        } else {
          expect(
            tester.getTopRight(addToCartBtn).dx,
            lessThanOrEqualTo(tester.getTopLeft(buyNowBtn).dx),
          );
        }
        final priceText = tester.widget<Text>(price);
        final peso =
            (priceText.textSpan! as TextSpan).children!.first as TextSpan;
        expect(peso.text, '\u20b1');
        expect(peso.style!.fontFamily, priceText.style!.fontFamily);
        expect(peso.style!.fontWeight, priceText.style!.fontWeight);
        expect(peso.style!.fontSize, priceText.style!.fontSize);
        expect(priceText.semanticsLabel, '\u20b1250');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'seller avatar uses saved photo and safely falls back when missing or broken',
    (tester) async => withCatalog(() async {
      for (final photo in [
        'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
        '',
        'data:image/png;base64,invalid',
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await showProduct(
          tester,
          row: productRow()..['seller_photo_url'] = photo,
        );
        final avatar = find.byKey(const ValueKey('product-seller-photo'));
        expect(tester.widget<ProductImage>(avatar).imageUrl, photo);
        expect(tester.getSize(avatar), const Size(44, 44));
        expect(find.text('Offline'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'saved option groups use full-width phone rows and split only at wide normal text',
    (tester) async => withCatalog(() async {
      for (final (size, scale, sideBySide) in [
        (const Size(375, 812), 1.0, false),
        (const Size(812, 600), 1.0, true),
        (const Size(320, 700), 2.0, false),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await showProduct(
          tester,
          row: variantSampleRow(),
          size: size,
          scale: scale,
        );
        final colors = find.byKey(const ValueKey('variant-group-Color'));
        final sizes = find.byKey(const ValueKey('variant-group-Size'));
        expect(find.text('Variants'), findsNothing);
        if (sideBySide) {
          expect(
            tester.getTopLeft(sizes).dy,
            closeTo(tester.getTopLeft(colors).dy, 0.1),
          );
          expect(
            tester.getTopLeft(sizes).dx,
            greaterThan(tester.getTopRight(colors).dx),
          );
        } else {
          expect(
            tester.getTopLeft(sizes).dy,
            greaterThan(tester.getBottomLeft(colors).dy),
          );
        }
        await choose(tester, 'Color', 'Navy');
        await choose(tester, 'Size', 'L');
        await tester.tap(find.text('Buy Now'));
        await tester.pumpAndSettle();
        final selection = tester
            .widget<CheckoutScreen>(find.byType(CheckoutScreen))
            .selection;
        expect(
          selection.selections.map(
            (option) => '${option.group}:${option.option}',
          ),
          ['Color:Navy', 'Size:L'],
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'web group names and actual values determine circles or text without changing payload names',
    (tester) async => withCatalog(() async {
      final cases = [
        ('Variant', ['Navy', 'White'], true),
        ('Colors', ['RED Cream'], true),
        ('Flavor', ['Green', 'Brown'], false),
        ('Size', ['M', 'L'], false),
        ('Color', ['Custom shade'], true),
      ];
      for (final (group, names, circles) in cases) {
        await tester.pumpWidget(const SizedBox.shrink());
        final row = productRow()
          ..['customization_options'] = [
            {
              'name': group,
              'required': true,
              'selection': 'single',
              'options': [
                for (final name in names) {'name': name},
              ],
            },
          ];
        await showProduct(tester, row: row);
        for (final name in names) {
          final choice = find.byKey(ValueKey('variant-$group-$name'));
          if (circles) {
            expect(
              find.byKey(ValueKey('color-swatch-$group-$name')),
              findsOneWidget,
            );
            expect(find.text(name), findsNothing);
          } else {
            expect(tester.widget<FilterChip>(choice).label, isA<Text>());
            expect(
              find.byKey(ValueKey('color-swatch-$group-$name')),
              findsNothing,
            );
          }
        }
        await choose(tester, group, names.first);
        await tester.tap(find.text('Buy Now'));
        await tester.pumpAndSettle();
        final selection = tester
            .widget<CheckoutScreen>(find.byType(CheckoutScreen))
            .selection;
        expect(selection.selections.single.group, group);
        expect(selection.selections.single.option, names.first);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'saved web color and size options use circles and text without select placeholder text',
    (tester) async => withCatalog(() async {
      await showProduct(
        tester,
        row: variantSampleRow(),
        size: const Size(320, 700),
        scale: 2,
      );
      expect(find.text('Colors'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Select color'), findsNothing);
      expect(find.text('Select size'), findsNothing);
      expect(find.byType(FilterChip), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      await choose(tester, 'Color', 'Gold');
      await choose(tester, 'Size', 'L');
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('variant-Color-Gold')))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('variant-Size-L')))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  testWidgets(
    'unavailable and owner views keep purchase restrictions',
    (tester) async => withCatalog(() async {
      final row = productRow()
        ..['stock'] = 0
        ..['inventory_status'] = 'out_of_stock';
      await showProduct(tester, row: row);
      expect(find.byKey(const ValueKey('product-listing-badge')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Buy Now'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('product-bottom-add-to-cart-button'),
                ),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await showProduct(tester, owner: true);
      expect(find.byKey(const ValueKey('product-listing-badge')), findsNothing);
      expect(find.text('Buy Now'), findsNothing);
      expect(find.text('Add to Cart'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );

  for (final (size, scale, brightness, highContrast) in [
    (const Size(320, 700), 2.0, Brightness.light, false),
    (const Size(812, 375), 2.0, Brightness.light, false),
    (const Size(280, 700), 1.0, Brightness.light, false),
    (const Size(390, 844), 1.0, Brightness.dark, false),
    (const Size(390, 844), 2.0, Brightness.dark, true),
  ]) {
    testWidgets(
      'responsive product choices fit $size scale $scale $brightness contrast $highContrast',
      (tester) async => withCatalog(() async {
        await showProduct(
          tester,
          size: size,
          scale: scale,
          brightness: brightness,
          highContrast: highContrast,
          bottomInset: 24,
        );
        await choose(tester, 'Size', 'M');
        final buy = find.widgetWithText(ElevatedButton, 'Buy Now');
        expect(tester.getRect(buy).bottom, lessThanOrEqualTo(size.height - 24));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.reset();
      }),
    );
  }

  testWidgets(
    'capture native layout when PRODUCT_DETAILS_REVIEW_DIR is supplied',
    (tester) async => withCatalog(() async {
      final output = Platform.environment['PRODUCT_DETAILS_REVIEW_DIR'];
      if (output == null) return;
      await tester.runAsync(() async {
        await (FontLoader(
              'Inter',
            )..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf')))
            .load();
        final poppins = FontLoader('Poppins');
        for (final face in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'ExtraBold',
        ]) {
          poppins.addFont(
            rootBundle.load('assets/fonts/poppins/Poppins-$face.ttf'),
          );
        }
        await poppins.load();
        final currencyFont =
            Platform.environment['PRODUCT_DETAILS_REVIEW_ROBOTO'];
        if (currencyFont != null) {
          await (FontLoader('Roboto')..addFont(
                Future.value(
                  ByteData.sublistView(File(currencyFont).readAsBytesSync()),
                ),
              ))
              .load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('packages/lucide_icons/Lucide')..addFont(
              rootBundle.load('packages/lucide_icons/assets/lucide.ttf'),
            ))
            .load();
      });
      Future<void> captureFrame(GlobalKey capture, String filename) async {
        void repaint(RenderObject object) {
          object.markNeedsPaint();
          object.visitChildren(repaint);
        }

        repaint(capture.currentContext!.findRenderObject()!);
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final dir = Directory(output)..createSync(recursive: true);
          File(
            '${dir.path}/$filename.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }

      final capture = GlobalKey();
      await showProduct(tester, capture: capture);
      await captureFrame(capture, 'product-details-entry');
      await choose(tester, 'Size', 'M');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('product-selected-price')))
            .textSpan!
            .toPlainText(),
        '\u20b1260',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(330);
      await tester.pumpAndSettle();
      await captureFrame(capture, 'product-details');
      for (final (size, scale, filename) in [
        (const Size(320, 700), 2.0, 'product-details-small-text'),
        (const Size(812, 375), 1.5, 'product-details-landscape'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final responsiveCapture = GlobalKey();
        await showProduct(
          tester,
          size: size,
          scale: scale,
          capture: responsiveCapture,
        );
        await choose(tester, 'Size', 'M');
        await captureFrame(responsiveCapture, filename);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final sampleCapture = GlobalKey();
      await showProduct(
        tester,
        row: variantSampleRow(),
        capture: sampleCapture,
      );
      await choose(tester, 'Color', 'Navy');
      await choose(tester, 'Size', 'L');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(300);
      await tester.pumpAndSettle();
      await captureFrame(sampleCapture, 'product-details-web-variants');
      await tester.pumpWidget(const SizedBox.shrink());
      final coffeeCapture = GlobalKey();
      await showProduct(
        tester,
        capture: coffeeCapture,
        size: const Size(390, 844),
        row: productRow()
          ..['name'] = 'Hot Coffee'
          ..['category'] = 'Food & Beverages'
          ..['price'] = '30'
          ..['description'] = 'Freshly prepared coffee.'
          ..['customization_options'] = [
            {
              'name': 'Flavor',
              'required': true,
              'options': [
                {'name': 'RED Cream'},
              ],
            },
          ],
      );
      await captureFrame(coffeeCapture, 'product-details-coffee');
      await choose(tester, 'Flavor', 'RED Cream');
      await tester.ensureVisible(
        find.byKey(const ValueKey('product-reviews-heading')),
      );
      await tester.pumpAndSettle();
      await captureFrame(coffeeCapture, 'product-details-coffee-lower');
      for (final (highContrast, filename) in [
        (false, 'product-details-dark-parent'),
        (true, 'product-details-high-contrast-unavailable'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final stateCapture = GlobalKey();
        await showProduct(
          tester,
          capture: stateCapture,
          brightness: Brightness.dark,
          highContrast: highContrast,
          bottomInset: 24,
          row: highContrast
              ? (productRow()
                  ..['stock'] = 0
                  ..['inventory_status'] = 'out_of_stock')
              : productRow(),
        );
        await captureFrame(stateCapture, filename);
      }
      for (final width in [390.0, 280.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final ownerCapture = GlobalKey();
        await showProduct(
          tester,
          owner: true,
          capture: ownerCapture,
          size: Size(width, 844),
          row: productRow()
            ..['rating'] = 4.5
            ..['reviews_count'] = 3,
        );
        expect(
          tester
              .widget<Scaffold>(find.byType(Scaffold).first)
              .bottomNavigationBar,
          isNull,
        );
        expect(find.byTooltip('Add to favorites'), findsNothing);
        await captureFrame(ownerCapture, 'owner-${width.toInt()}-entry');
        await tester.ensureVisible(find.text('You May Also Like'));
        await tester.pumpAndSettle();
        await captureFrame(ownerCapture, 'owner-${width.toInt()}-reviews');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }),
  );
}
