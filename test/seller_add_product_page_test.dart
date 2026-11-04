import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campushub/module_app/config/api_config.dart';
import 'package:campushub/module_app/screens/products_screen.dart';
import 'package:campushub/module_app/screens/seller_add_product_page.dart';
import 'package:campushub/module_app/widgets/seller/product_inventory_fields.dart';
import 'package:campushub/module_app/widgets/product_image.dart';
import 'package:campushub/module_app/widgets/seller/product_expiry_field.dart';
import 'package:campushub/module_app/widgets/seller/product_tag_input.dart';
import 'package:campushub/module_app/widgets/seller/product_upload_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductTestPicker extends ImagePickerPlatform {
  XFile? file;
  List<XFile>? files;
  int singleCalls = 0;
  final limits = <int?>[];
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleCalls++;
    expect(source, ImageSource.gallery);
    expect(options.maxWidth, 1280);
    expect(options.requestFullMetadata, isFalse);
    return file;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    expect(options.imageOptions.maxWidth, 1280);
    expect(options.imageOptions.requestFullMetadata, isFalse);
    limits.add(options.limit);
    return files ?? (file == null ? [] : [file!]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  final reviewDir = Platform.environment['PRODUCT_FORM_REVIEW_DIR'];
  late ImagePickerPlatform originalPicker;
  late ProductTestPicker picker;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==',
  );
  bool? result;
  String? confirmationDestination;

  String successResponse({int? batches}) => jsonEncode({
    'product': {
      'id': 71,
      'name': 'Confirmed server product',
      'price': '35.75',
      'category': 'Snacks',
      'approval_status': 'pending',
      'images': ['data:image/png;base64,${base64Encode(png)}'],
    },
    'initial_batches_saved': ?batches,
  });

  setUpAll(() async {
    // Layout checks must use the app's bundled font, not Flutter's square
    // placeholder glyphs, even when no screenshot directory is requested.
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/inter/InterVariable.ttf'))).load();
    if (reviewDir != null) {
      final loader = FontLoader('Poppins');
      for (final face in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(
          rootBundle.load('assets/fonts/poppins/Poppins-$face.ttf'),
        );
      }
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/lucide_icons/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons/assets/lucide.ttf'),
          ))
          .load();
      final sdkRoot = Platform.environment['FLUTTER_ROOT'];
      if (sdkRoot != null) {
        final font = File(
          '$sdkRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        ).readAsBytesSync();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(font)))).load();
      }
    }
  });

  setUp(() {
    result = null;
    confirmationDestination = null;
    originalPicker = ImagePickerPlatform.instance;
    picker = ProductTestPicker();
    ImagePickerPlatform.instance = picker;
    SharedPreferences.setMockInitialValues({
      'campushub_chat_token': 'test-seller-token',
    });
    ApiConfig.recordWorkingBaseUrl('http://localhost:8000');
  });
  tearDown(() => ImagePickerPlatform.instance = originalPicker);

  http.Response status({
    bool approved = true,
    List<String> categories = const ['School Supplies', 'Snacks'],
  }) => http.Response(
    jsonEncode({'is_approved_seller': approved, 'categories': categories}),
    200,
  );

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
    ThemeData? surroundingTheme,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme:
              surroundingTheme ??
              ThemeData(fontFamilyFallback: const ['Roboto']),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await ProductsScreen.showAddProductPage(
                    context,
                    onViewProducts: () => confirmationDestination = 'products',
                    onBackHome: () => confirmationDestination = 'home',
                  );
                },
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    final target = key == 'inventory-simple' || key == 'inventory-fifo'
        ? find.descendant(of: finder, matching: find.byType(Radio<String>))
        : finder;
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> batchDate(WidgetTester tester, int number) async {
    await tapKey(tester, 'batch-date-$number');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> category(WidgetTester tester, String label) async {
    tester.testTextInput.hide();
    final finder = find.byKey(const ValueKey('product-category'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    // Other workflow checks supply the newly required image before advancing.
    // Empty-image validation is exercised directly in the cover lifecycle test.
    if (find.text('Step 3 of 4').evaluate().isNotEmpty &&
        find.text('0 of 6').evaluate().isNotEmpty) {
      final previous = picker.files;
      picker.files = [XFile.fromData(png, name: 'required-photo.png')];
      await tapKey(tester, 'add-product-image');
      picker.files = previous;
    }
    await tapKey(tester, 'continue-product');
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  void expectStep(WidgetTester tester, int step) {
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Step $step of 4'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('product-step-progress')),
          )
          .value,
      step / 4,
    );
    final titles = [
      'Product Information',
      'Pricing & Inventory',
      step == 4 ? 'Uploaded Photos' : 'Upload Images',
      'Review & Submit',
    ];
    for (var i = 0; i < titles.length; i++) {
      expect(
        find.text(titles[i]),
        i + 1 == step || step == 4 ? findsOneWidget : findsNothing,
      );
    }
    expect(find.byKey(const ValueKey('back-product-step')), findsNothing);
    if (step == 4) {
      expect(find.text('Back'), findsNothing);
      expect(find.byTooltip('Back to Upload Images'), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('submit-product')),
      step == 4 ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey('continue-product')),
      step == 4 ? findsNothing : findsOneWidget,
    );
  }

  Future<void> information(
    WidgetTester tester, {
    String selected = 'School Supplies',
  }) async {
    await field(tester, 'product-name', 'Test Notebook');
    await category(tester, selected);
    await field(tester, 'product-description', 'A test-only ruled notebook.');
    await field(tester, 'product-tags', 'school, local');
    await next(tester);
    expectStep(tester, 2);
  }

  Future<void> inventory(WidgetTester tester, {String quantity = '9'}) async {
    await field(tester, 'product-price', '25.50');
    await field(tester, 'product-quantity', quantity);
    await next(tester);
    expectStep(tester, 3);
  }

  Future<void> review(WidgetTester tester) async {
    await information(tester);
    await inventory(tester);
    await next(tester);
    expectStep(tester, 4);
  }

  Future<void> submit(
    WidgetTester tester, {
    bool waitForResponse = true,
  }) async {
    tester.testTextInput.hide();
    final button = find.byKey(const ValueKey('submit-product'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    if (!waitForResponse) {
      await tester.pump();
      return;
    }
    await tester.pumpAndSettle();
    // Existing workflow checks finish through the new explicit confirmation.
    if (find
        .byKey(const ValueKey('submitted-view-products'))
        .evaluate()
        .isNotEmpty) {
      await tapKey(tester, 'submitted-view-products');
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (reviewDir == null) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(reviewDir).create(recursive: true);
        await File(
          '$reviewDir/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (280.0, 844.0, 2.0),
    (320.0, 844.0, 1.3),
    (640.0, 900.0, 1.0),
    (844.0, 390.0, 1.0),
  ]) {
    testWidgets(
      'four active sections, left progress and right label fit $width/$height/$scale',
      (tester) async {
        var posts = 0;
        await http.runWithClient(
          () async {
            await open(tester, width: width, height: height, scale: scale);
            expectStep(tester, 1);
            expect(find.byType(SingleChildScrollView), findsOneWidget);
            final bar = tester.getRect(
              find.byKey(const ValueKey('product-step-progress')),
            );
            final label = tester.getRect(
              find.byKey(const ValueKey('product-step-label')),
            );
            expect(bar.right, lessThan(label.left));
            expect((bar.center.dy - label.center.dy).abs(), lessThan(1));
            expect(bar.width, greaterThan(0));
            expect(
              tester
                  .widget<LinearProgressIndicator>(
                    find.byKey(const ValueKey('product-step-progress')),
                  )
                  .color,
              Colors.white,
            );
            expect(
              tester
                  .widget<ShaderMask>(
                    find.byKey(const ValueKey('product-step-gradient')),
                  )
                  .blendMode,
              BlendMode.srcIn,
            );
            expect(find.byKey(const ValueKey('product-price')), findsNothing);
            await capture(tester, 'step-1-${width.toInt()}');
            await information(tester);
            await capture(tester, 'step-2-${width.toInt()}');
            await inventory(tester);
            await capture(tester, 'step-3-${width.toInt()}');
            await next(tester);
            expectStep(tester, 4);
            expect(find.text('Test Notebook'), findsOneWidget);
            expect(find.text('9 units'), findsOneWidget);
            await capture(tester, 'step-4-${width.toInt()}');
            await back(tester);
            expectStep(tester, 3);
            await back(tester);
            expect(
              tester
                  .widget<TextFormField>(
                    find.byKey(const ValueKey('product-quantity')),
                  )
                  .controller!
                  .text,
              '9',
            );
            await back(tester);
            expectStep(tester, 1);
            expect(
              tester
                  .widget<TextFormField>(
                    find.byKey(const ValueKey('product-name')),
                  )
                  .controller!
                  .text,
              'Test Notebook',
            );
            expect(
              find.byKey(const ValueKey('product-tag-school')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('product-tag-local')),
              findsOneWidget,
            );
            expect(posts, 0);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.method == 'POST') posts++;
            return status();
          }),
        );
      },
    );
  }

  testWidgets(
    'each required step validates before Continue and never posts early',
    (tester) async {
      var posts = 0;
      await http.runWithClient(
        () async {
          await open(tester);
          await next(tester);
          expectStep(tester, 1);
          expect(find.text('Product name is required.'), findsOneWidget);
          expect(find.text('Category is required.'), findsOneWidget);
          expect(find.text('Description is required.'), findsOneWidget);
          await information(tester);
          for (final price in [
            '',
            '   ',
            '0',
            '-1',
            'NaN',
            'Infinity',
            '1.234',
          ]) {
            await field(tester, 'product-price', price);
            await next(tester);
            expectStep(tester, 2);
            expect(
              find.text(
                price.trim().isEmpty
                    ? 'Selling price is required.'
                    : 'Please enter a valid selling price.',
              ),
              findsOneWidget,
            );
          }
          await field(tester, 'product-price', '1.25');
          for (final quantity in ['', '   ', '-1', '1.5', '2147483648']) {
            await field(tester, 'product-quantity', quantity);
            await next(tester);
            expect(
              find.text(
                quantity.trim().isEmpty
                    ? 'Stock quantity is required.'
                    : 'Please enter a valid stock quantity.',
              ),
              findsOneWidget,
            );
          }
          await field(tester, 'product-quantity', '0');
          for (final threshold in ['', '   ', '-1', '1.5']) {
            await field(tester, 'product-low-stock-threshold', threshold);
            await next(tester);
            expectStep(tester, 2);
            expect(
              find.text(
                threshold.trim().isEmpty
                    ? 'Low stock threshold is required.'
                    : 'Enter a whole-number threshold of 0 or more.',
              ),
              findsOneWidget,
            );
          }
          await field(tester, 'product-low-stock-threshold', '0');
          await next(tester);
          expectStep(tester, 3);
          await next(tester);
          expect(find.text('0 units'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('review-product-image-0')),
            findsOneWidget,
          );
          expect(posts, 0);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') posts++;
          return status();
        }),
      );
    },
  );

  testWidgets('keyboard, header Back and platform Back retain the same draft', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester);
      await information(tester);
      await field(tester, 'product-price', '18.25');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await field(tester, 'product-quantity', '12');
      await capture(tester, 'inventory-keyboard');
      await back(tester);
      expectStep(tester, 1);
      tester.view.resetViewInsets();
      await next(tester);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('product-price')))
            .controller!
            .text,
        '18.25',
      );
      await next(tester);
      expectStep(tester, 3);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectStep(tester, 2);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => status()));
  });

  testWidgets(
    'batch drafts, dates, costs and method switches survive all four steps',
    (tester) async {
      Map<String, dynamic>? posted;
      await http.runWithClient(
        () async {
          await open(tester);
          await information(tester);
          await field(tester, 'product-price', '25.50');
          await field(tester, 'product-quantity', '9');
          await tapKey(tester, 'inventory-fifo');
          expect(find.byKey(const ValueKey('product-quantity')), findsNothing);
          await field(tester, 'batch-quantity-1', '3');
          await field(tester, 'batch-cost-1', '2.50');
          await batchDate(tester, 1);
          await tapKey(tester, 'add-product-batch');
          await field(tester, 'batch-quantity-2', '4');
          await batchDate(tester, 2);
          expect(find.text('Total Available Stock: 7 units'), findsOneWidget);
          await tapKey(tester, 'inventory-simple');
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('product-quantity')),
                )
                .controller!
                .text,
            '9',
          );
          await tapKey(tester, 'inventory-fifo');
          await next(tester);
          await back(tester);
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('batch-cost-1')),
                )
                .controller!
                .text,
            '2.50',
          );
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('batch-quantity-2')),
                )
                .controller!
                .text,
            '4',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('batch-date-1')),
          );
          await capture(tester, 'batch-step-2');
          await next(tester);
          await next(tester);
          expectStep(tester, 4);
          expect(find.text('7 units'), findsOneWidget);
          expect(find.text('Batch Tracking'), findsOneWidget);
          await tapKey(tester, 'review-batches');
          expect(find.textContaining('Unit cost ₱2.50'), findsOneWidget);
          expect(posted, isNull);
          await capture(tester, 'batch-step-4');
          await submit(tester);
          await tester.pumpAndSettle();
          final today = ProductFormStyle.date(
            DateUtils.dateOnly(DateTime.now()),
          );
          expect(posted!['stock'], 7);
          expect(posted!['inventory_method'], 'fifo');
          expect(posted!['initial_batches'], [
            {'quantity': 3, 'received_date': today, 'unit_cost': '2.50'},
            {'quantity': 4, 'received_date': today},
          ]);
          expect(result, isTrue);
          expect(find.byType(SellerAddProductPage), findsNothing);
        },
        () => MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/seller/products/submit/') {
            return http.Response(
              '{"capabilities":{"initial_batches":true}}',
              200,
            );
          }
          if (request.method == 'GET') return status();
          posted = jsonDecode(request.body);
          return http.Response(successResponse(batches: 2), 201);
        }),
      );
    },
  );

  testWidgets(
    'empty, invalid and missing-date batches block Continue and removal updates totals',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        await information(tester);
        await field(tester, 'product-price', '10');
        await tapKey(tester, 'inventory-fifo');
        for (final quantity in ['', '   ', '0', '-1', '1.5']) {
          await field(tester, 'batch-quantity-1', quantity);
          await next(tester);
          expectStep(tester, 2);
          expect(
            find.text(
              quantity.trim().isEmpty
                  ? 'Batch quantity is required.'
                  : 'Enter a whole-number batch quantity greater than 0.',
            ),
            findsOneWidget,
          );
        }
        await field(tester, 'batch-quantity-1', '3');
        await field(tester, 'batch-cost-1', '-1');
        await next(tester);
        expect(find.text('Date received is required.'), findsOneWidget);
        expect(
          find.text('Enter a unit cost of 0 or more, up to 2 decimal places.'),
          findsOneWidget,
        );
        await tapKey(tester, 'add-product-batch');
        await field(tester, 'batch-quantity-2', '5');
        await tapKey(tester, 'remove-batch-1');
        expect(find.text('Total Available Stock: 5 units'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('batch-quantity-1')),
              )
              .controller!
              .text,
          '5',
        );
        await tapKey(tester, 'remove-batch-1');
        await next(tester);
        expectStep(tester, 2);
        expect(
          find.byKey(const ValueKey('product-submit-error')),
          findsOneWidget,
        );
      }, () => MockClient((_) async => status()));
    },
  );

  for (final (width, scale) in [(280.0, 2.0), (390.0, 1.0)]) {
    testWidgets(
      'concise batch tooltip supports tap, long press, hover and outside dismissal at $width',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await http.runWithClient(() async {
            await open(tester, width: width, scale: scale);
            await information(tester);
            await tapKey(tester, 'batch-inventory-info');
            expect(
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .groupValue,
              'simple',
            );
            expect(find.text(ProductInventoryInfo.explanation), findsOneWidget);
            expect(
              find.bySemanticsLabel(RegExp('About Batch Tracking')),
              findsOneWidget,
            );
            final rect = tester.getRect(
              find.byKey(const ValueKey('batch-tooltip-content')),
            );
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.bottom, lessThanOrEqualTo(844));
            await capture(tester, 'batch-tooltip-${width.toInt()}');
            await tester.tapAt(const Offset(150, 28));
            await tester.pumpAndSettle();
            expect(find.text(ProductInventoryInfo.explanation), findsNothing);
            final info = find.byKey(const ValueKey('batch-inventory-info'));
            await tester.longPress(info);
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .groupValue,
              'simple',
            );
            expect(find.text(ProductInventoryInfo.explanation), findsOneWidget);
            await tester.pump(const Duration(seconds: 13));
            await tester.pumpAndSettle();
            expect(find.text(ProductInventoryInfo.explanation), findsNothing);
            final mouse = await tester.createGesture(
              kind: ui.PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: Offset.zero);
            await mouse.moveTo(tester.getCenter(info));
            await tester.pump(const Duration(seconds: 1));
            await tester.pumpAndSettle();
            expect(find.text(ProductInventoryInfo.explanation), findsOneWidget);
            await mouse.removePointer();
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .groupValue,
              'simple',
            );
            expect(tester.takeException(), isNull);
          }, () => MockClient((_) async => status()));
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final (width, scale, dark) in [
    (390.0, 1.0, false),
    (280.0, 2.0, false),
    (390.0, 1.0, true),
    (280.0, 2.0, true),
  ]) {
    testWidgets(
      'stock cards align content and select through the card at $width/$scale dark=$dark',
      (tester) async {
        await http.runWithClient(() async {
          await open(
            tester,
            width: width,
            scale: scale,
            surroundingTheme: dark
                ? ThemeData(
                    brightness: Brightness.dark,
                    colorSchemeSeed: const Color(0xFFFCB315),
                    fontFamilyFallback: const ['Roboto'],
                  )
                : null,
          );
          await information(tester);
          for (final (method, title, description) in [
            (
              'simple',
              'Standard Stock',
              'Enter the number of items available for sale.',
            ),
            (
              'fifo',
              'Batch Tracking',
              'Organize your items based on when you restock them.',
            ),
          ]) {
            final card = find.byKey(ValueKey('inventory-$method'));
            final titleRect = tester.getRect(find.text(title));
            final descriptionRect = tester.getRect(find.text(description));
            final radio = find.descendant(
              of: card,
              matching: find.byType(Radio<String>),
            );
            final radioRect = tester.getRect(radio);
            final cardRect = tester.getRect(card);
            expect(descriptionRect.left, closeTo(titleRect.left, .1));
            expect(descriptionRect.top, closeTo(titleRect.bottom, .1));
            expect(radioRect.center.dy, closeTo(cardRect.center.dy, .1));
            expect(radioRect.right, lessThan(titleRect.left));
            final infoButton = find.byKey(
              ValueKey(
                method == 'fifo'
                    ? 'batch-inventory-info'
                    : 'standard-stock-info',
              ),
            );
            final info = tester.getRect(infoButton);
            final infoContext = tester.element(infoButton);
            final scheme = Theme.of(infoContext).colorScheme;
            expect(scheme.brightness, Brightness.light);
            expect(scheme.onSurfaceVariant, ProductFormStyle.muted);
            expect(scheme.outline, ProductFormStyle.muted);
            expect(
              tester
                  .widget<RichText>(
                    find
                        .descendant(
                          of: infoButton,
                          matching: find.byType(RichText),
                        )
                        .first,
                  )
                  .text
                  .style!
                  .color,
              ProductFormStyle.muted,
            );
            final glyph = tester.getRect(
              find.descendant(
                of: infoButton,
                matching: find.byIcon(Icons.info_outline),
              ),
            );
            expect(glyph.right, closeTo(cardRect.right - 16, .1));
            expect(glyph.center.dy, closeTo(cardRect.center.dy, .1));
            expect(info.left, greaterThanOrEqualTo(titleRect.right + 4));
            expect(info.left, greaterThanOrEqualTo(descriptionRect.right + 4));
            expect(info.right, closeTo(cardRect.right - 16, .1));
            expect(info.width, greaterThanOrEqualTo(48));
            expect(info.height, greaterThanOrEqualTo(48));
            expect(info.top, greaterThanOrEqualTo(cardRect.top));
            expect(info.center.dy, closeTo(cardRect.center.dy, .1));
          }
          final fifoCard = find.byKey(const ValueKey('inventory-fifo'));
          Material cardSurface(Finder card) => tester.widget<Material>(
            find.ancestor(of: card, matching: find.byType(Material)).first,
          );
          expect(cardSurface(fifoCard).color, Colors.white);
          await capture(
            tester,
            'stock-method-simple-${width.toInt()}-dark-$dark',
          );
          final description = find.text(
            'Organize your items based on when you restock them.',
          );
          await tester.ensureVisible(description);
          await tester.tap(description);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('batch-quantity-1')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('product-quantity')), findsNothing);
          expect(cardSurface(fifoCard).color, Colors.white);
          expect(
            (cardSurface(fifoCard).shape! as RoundedRectangleBorder).side.color,
            ProductFormStyle.navy,
          );
          await tester.ensureVisible(fifoCard);
          await capture(
            tester,
            'stock-method-selected-${width.toInt()}-dark-$dark',
          );
          for (final (id, message) in [
            ('standard-stock-info', ProductInventoryInfo.standardExplanation),
            ('batch-inventory-info', ProductInventoryInfo.explanation),
          ]) {
            await tapKey(tester, id);
            expect(find.text(message), findsOneWidget);
            expect(
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .groupValue,
              'fifo',
            );
            await tester.tapAt(const Offset(150, 28));
            await tester.pumpAndSettle();
          }
          final simpleDescription = find.text(
            'Enter the number of items available for sale.',
          );
          await tester.ensureVisible(simpleDescription);
          await tester.tap(simpleDescription);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('product-quantity')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('batch-quantity-1')), findsNothing);
          expect(cardSurface(fifoCard).color, Colors.white);
          expect(tester.takeException(), isNull);
        }, () => MockClient((_) async => status()));
      },
    );
  }

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets(
      'photo upload area opens gallery from its edges without empty placeholders at $width/$scale',
      (tester) async {
        await http.runWithClient(() async {
          await open(tester, width: width, scale: scale);
          await information(tester);
          await inventory(tester);
          final upload = find.byKey(const ValueKey('add-product-image'));
          expect(
            find.descendant(
              of: upload,
              matching: find.byType(ProductUploadIcon),
            ),
            findsOneWidget,
          );
          final arrow = find.byKey(const ValueKey('product-upload-arrow'));
          expect(tester.getSize(arrow), const Size.square(58));
          expect(
            tester
                .widget<ColoredBox>(
                  find.descendant(of: arrow, matching: find.byType(ColoredBox)),
                )
                .color,
            ProductFormStyle.navy,
          );
          final counter = find.byKey(const ValueKey('product-image-counter'));
          expect(
            find.text('Add at least one clear photo of your product.'),
            findsOneWidget,
          );
          expect(
            find.text('Tap to choose photos from your gallery.'),
            findsOneWidget,
          );
          expect(
            find.text(
              'JPEG, PNG, WebP, GIF \u2022 Max 6 photos \u2022 5 MB each',
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('product-image-grid')),
            findsNothing,
          );
          expect(find.text('Uploaded Photos'), findsNothing);
          expect(
            find.byKey(const ValueKey('uploaded-photos-card')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('product-image-error')),
            findsNothing,
          );
          for (var i = 0; i < 6; i++) {
            expect(find.byKey(ValueKey('product-image-slot-$i')), findsNothing);
          }
          final heading = tester.getRect(find.text('Upload Images'));
          final count = tester.getRect(counter);
          expect(count.center.dy, closeTo(heading.center.dy, .1));
          expect(count.right, closeTo(width - 16, .1));
          expect(find.text('0 of 6'), findsOneWidget);
          await capture(tester, 'product-images-empty-${width.toInt()}');
          for (final trailing in [false, true]) {
            await tester.ensureVisible(upload);
            final area = tester.getRect(upload);
            final previous = picker.limits.length;
            await tester.tapAt(
              trailing
                  ? Offset(area.right - 20, area.bottom - 20)
                  : Offset(area.left + 20, area.top + 20),
            );
            await tester.pumpAndSettle();
            expect(picker.limits.length, previous + 1);
            expect(picker.limits.last, 6);
            expect(
              find.byKey(const ValueKey('product-image-error')),
              findsNothing,
            );
          }
          picker.files = List.generate(
            3,
            (i) => XFile.fromData(png, name: 'photo-$i.png'),
          );
          await tapKey(tester, 'add-product-image');
          expect(find.text('3 of 6'), findsOneWidget);
          final photoCard = find.byKey(const ValueKey('uploaded-photos-card'));
          expect(
            find.descendant(
              of: photoCard,
              matching: find.text('Uploaded Photos'),
            ),
            findsOneWidget,
          );
          final card = tester.widget<Container>(photoCard);
          final decoration = card.decoration! as BoxDecoration;
          expect(decoration.color, Colors.white);
          expect(decoration.border, Border.all(color: ProductFormStyle.border));
          expect(find.text('Remove'), findsNothing);
          for (var i = 0; i < 3; i++) {
            final remove = find.byKey(ValueKey('remove-product-image-$i'));
            expect(tester.widget<IconButton>(remove).onPressed, isNotNull);
            expect(
              find.descendant(of: remove, matching: find.byIcon(LucideIcons.x)),
              findsOneWidget,
            );
          }
          final slots = [
            for (var i = 0; i < 3; i++)
              tester.getRect(find.byKey(ValueKey('product-image-slot-$i'))),
          ];
          expect(slots[1].top, closeTo(slots[0].top, .1));
          expect(slots[2].top, closeTo(slots[0].top, .1));
          expect(slots[1].left - slots[0].right, closeTo(8, .1));
          expect(slots[2].left - slots[1].right, closeTo(8, .1));
          for (var i = 3; i < 6; i++) {
            expect(find.byKey(ValueKey('product-image-slot-$i')), findsNothing);
          }
          final cover = find.byKey(const ValueKey('product-cover-0'));
          expect(cover, findsOneWidget);
          expect(
            tester
                .widget<IgnorePointer>(
                  find
                      .ancestor(of: cover, matching: find.byType(IgnorePointer))
                      .first,
                )
                .ignoring,
            isTrue,
          );
          await tester.ensureVisible(photoCard);
          await tester.pumpAndSettle();
          await capture(tester, 'product-images-three-${width.toInt()}');
          await tapKey(tester, 'product-image-preview-0');
          expect(find.text('Replace photo'), findsOneWidget);
          expect(find.byKey(const ValueKey('product-cover-0')), findsOneWidget);
          await tester.tapAt(const Offset(10, 60));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, () => MockClient((_) async => status()));
      },
    );
  }

  testWidgets(
    'six-photo gallery, primary order and review retain actual images',
    (tester) async {
      Map<String, dynamic>? posted;
      final images = [
        for (var i = 0; i < 6; i++) Uint8List.fromList([...png, i]),
      ];
      await http.runWithClient(
        () async {
          await open(tester);
          await information(tester);
          await inventory(tester);
          picker.files = [
            for (var i = 0; i < images.length; i++)
              XFile.fromData(images[i], name: '$i.png'),
          ];
          await tapKey(tester, 'add-product-image');
          expect(find.text('6 of 6'), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const ValueKey('add-product-image')),
                )
                .onPressed,
            isNull,
          );
          await tapKey(tester, 'product-image-preview-2');
          await tapKey(tester, 'primary-product-image-2');
          await capture(tester, 'six-photo-step-3');
          await next(tester);
          for (var i = 0; i < 6; i++) {
            expect(
              find.byKey(ValueKey('review-product-image-$i')),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: find.byKey(ValueKey('review-photo-card-$i')),
                matching: find.text(i == 0 ? 'Cover' : 'Photo ${i + 1}'),
              ),
              findsOneWidget,
            );
          }
          expect(find.text('Cover'), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const ValueKey('review-photo-card-3')),
          );
          await capture(tester, 'six-photo-review');
          await back(tester);
          await tapKey(tester, 'remove-product-image-2');
          expect(find.text('5 of 6'), findsOneWidget);
          expect(find.text('Cover'), findsOneWidget);
          await next(tester);
          await submit(tester);
          await tester.pumpAndSettle();
          expect(posted!['images'], [
            for (final i in [0, 1, 3, 4, 5])
              'data:image/png;base64,${base64Encode(images[i])}',
          ]);
          expect(posted!.containsKey('initial_batches'), isFalse);
          expect(result, isTrue);
          expect(picker.limits.first, 6);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return status();
          posted = jsonDecode(request.body);
          return http.Response(successResponse(), 201);
        }),
      );
    },
  );

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets(
      'required cover photo lifecycle and ordered submission at $width/$scale',
      (tester) async {
        Map<String, dynamic>? posted;
        final bytes = [
          for (var i = 0; i < 3; i++) Uint8List.fromList([...png, i]),
        ];
        String url(int i) => 'data:image/png;base64,${base64Encode(bytes[i])}';
        XFile photo(int i) => XFile.fromData(bytes[i], name: 'cover-$i.png');
        await http.runWithClient(
          () async {
            await open(tester, width: width, scale: scale);
            await information(tester);
            final price = tester.widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('product-price')),
                matching: find.byType(TextField),
              ),
            );
            expect(price.decoration!.prefixText, '₱ ');
            expect(price.decoration!.prefixStyle!.fontWeight, FontWeight.w700);
            await inventory(tester);
            final nextButton = find.byKey(const ValueKey('continue-product'));
            expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
            expect(
              find.text('Please add at least one product photo.'),
              findsNothing,
            );
            await capture(tester, 'required-photos-empty-${width.toInt()}');
            picker.files = [photo(0)];
            await tapKey(tester, 'add-product-image');
            expect(
              find.byKey(const ValueKey('product-cover-0')),
              findsOneWidget,
            );
            expect(find.text('1 of 6'), findsOneWidget);
            expect(
              tester.widget<FilledButton>(nextButton).onPressed,
              isNotNull,
            );
            await tapKey(tester, 'product-image-preview-0');
            expect(find.text('Set as Cover'), findsNothing);
            await tester.tapAt(const Offset(10, 60));
            await tester.pumpAndSettle();
            picker.files = [photo(1), photo(2)];
            await tapKey(tester, 'add-product-image');
            await tapKey(tester, 'product-image-preview-2');
            await tapKey(tester, 'primary-product-image-2');
            expect(
              find.byKey(const ValueKey('product-cover-2')),
              findsOneWidget,
            );
            expect(find.text('Cover'), findsOneWidget);
            await tapKey(tester, 'remove-product-image-1');
            expect(find.text('2 of 6'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('product-cover-1')),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<ProductImage>(
                    find.byKey(const ValueKey('product-image-preview-1')),
                  )
                  .imageUrl,
              url(2),
            );
            await capture(tester, 'selected-cover-${width.toInt()}');
            await next(tester);
            expectStep(tester, 4);
            expect(
              tester
                  .widget<ProductImage>(
                    find.byKey(const ValueKey('review-product-image-0')),
                  )
                  .imageUrl,
              url(2),
            );
            await back(tester);
            expect(
              find.byKey(const ValueKey('product-cover-1')),
              findsOneWidget,
            );
            await tapKey(tester, 'remove-product-image-1');
            expect(
              find.byKey(const ValueKey('product-cover-0')),
              findsOneWidget,
            );
            await tapKey(tester, 'remove-product-image-0');
            expect(find.text('Cover'), findsNothing);
            expect(find.text('0 of 6'), findsOneWidget);
            expect(
              find.text('Please add at least one product photo.'),
              findsOneWidget,
            );
            expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
            picker.files = [photo(0), photo(1)];
            await tapKey(tester, 'add-product-image');
            await tapKey(tester, 'product-image-preview-1');
            await tapKey(tester, 'primary-product-image-1');
            await next(tester);
            await submit(tester);
            await tester.pumpAndSettle();
            expect(posted!['images'], [url(1), url(0)]);
            expect(result, isTrue);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              posted = jsonDecode(request.body);
              return http.Response(successResponse(), 201);
            }
            return status();
          }),
        );
      },
    );
  }

  testWidgets(
    'gallery cancel, invalid type and excess selection preserve the draft',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        await information(tester);
        await inventory(tester);
        await tapKey(tester, 'add-product-image');
        expect(find.text('0 of 6'), findsOneWidget);
        picker.file = XFile.fromData(
          utf8.encode('not an image'),
          name: 'bad.png',
        );
        await tapKey(tester, 'add-product-image');
        expect(
          find.text('Choose a JPEG, PNG, WebP or GIF image up to 5 MB.'),
          findsOneWidget,
        );
        picker.files = [
          XFile.fromData(png, name: 'valid.png'),
          XFile.fromData(Uint8List(5 * 1024 * 1024 + 1), name: 'oversize.png'),
        ];
        await tapKey(tester, 'add-product-image');
        expect(
          find.text('Choose an image no larger than 5 MB.'),
          findsOneWidget,
        );
        expect(find.text('0 of 6'), findsOneWidget);
        expect(find.byKey(const ValueKey('product-image-grid')), findsNothing);
        picker.files = List.generate(
          7,
          (i) => XFile.fromData(png, name: '$i.png'),
        );
        await tapKey(tester, 'add-product-image');
        expect(
          find.text('You can upload up to 6 images. Select fewer images.'),
          findsOneWidget,
        );
        expect(find.text('0 of 6'), findsOneWidget);
        await back(tester);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('product-price')),
              )
              .controller!
              .text,
          '25.50',
        );
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => status()));
    },
  );

  testWidgets(
    'submission is authenticated, guarded while pending and retains review on error',
    (tester) async {
      var posts = 0;
      final pending = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await open(tester);
          await review(tester);
          await submit(tester, waitForResponse: false);
          expect(posts, 1);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('submit-product')),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester.widget<BackButton>(find.byType(BackButton)).onPressed,
            isNull,
          );
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.byType(SellerAddProductPage), findsOneWidget);
          pending.complete(
            http.Response('{"error":"Seller access suspended."}', 403),
          );
          await tester.pumpAndSettle();
          expectStep(tester, 4);
          expect(find.text('Seller access suspended.'), findsOneWidget);
          expect(find.text('Test Notebook'), findsOneWidget);
          await submit(tester);
          await tester.pumpAndSettle();
          expect(posts, 2);
          expect(result, isTrue);
          expect(confirmationDestination, 'products');
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-seller-token');
          if (request.method == 'GET') return status();
          expect(request.url.path, '/api/seller/products/submit/');
          final body = jsonDecode(request.body);
          expect(body['price'], '25.50');
          expect(body['stock'], 9);
          expect(body['description'], 'A test-only ruled notebook.');
          expect(body.containsKey('seller_id'), isFalse);
          expect(body.containsKey('approval_status'), isFalse);
          posts++;
          return posts == 1
              ? pending.future
              : http.Response(successResponse(), 201);
        }),
      );
    },
  );

  for (final action in ['products', 'home', 'android-back']) {
    testWidgets(
      'confirmed product shows server summary and exits through $action',
      (tester) async {
        var posts = 0;
        await http.runWithClient(
          () async {
            await open(
              tester,
              width: action == 'home' ? 280 : 390,
              scale: action == 'home' ? 2 : 1,
            );
            await review(tester);
            await tapKey(tester, 'submit-product');
            expect(posts, 1);
            expect(find.text('Product Submitted!'), findsOneWidget);
            expect(find.text('Confirmed server product'), findsOneWidget);
            expect(find.text('₱35.75'), findsOneWidget);
            expect(find.text('Snacks'), findsOneWidget);
            expect(find.text('Pending Approval'), findsNWidgets(2));
            expect(
              find.byKey(const ValueKey('product-step-progress')),
              findsNothing,
            );
            expect(find.byKey(const ValueKey('submit-product')), findsNothing);
            expect(result, isNull);
            expect(
              tester
                  .widget<ProductImage>(
                    find.byKey(const ValueKey('submitted-product-cover')),
                  )
                  .imageUrl,
              'data:image/png;base64,${base64Encode(png)}',
            );
            await tester.pump(const Duration(seconds: 3));
            expect(find.text('Product Submitted!'), findsOneWidget);
            final viewport = tester.getRect(
              find.byKey(const ValueKey('submitted-content-viewport')),
            );
            final content = tester.getRect(
              find.byKey(const ValueKey('submitted-confirmation-content')),
            );
            expect(content.center.dx, closeTo(viewport.center.dx, .1));
            if (content.height <= viewport.height - 32) {
              expect(content.center.dy, closeTo(viewport.center.dy, .1));
            } else {
              expect(content.top, closeTo(viewport.top + 16, .1));
              await tester.ensureVisible(
                find.byKey(const ValueKey('submitted-product-summary')),
              );
              await tester.pumpAndSettle();
              expect(
                tester
                    .getRect(
                      find.byKey(const ValueKey('submitted-product-summary')),
                    )
                    .bottom,
                lessThanOrEqualTo(viewport.bottom),
              );
            }
            await capture(tester, 'submission-confirmation-$action');
            if (action == 'android-back') {
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            } else {
              await tapKey(
                tester,
                action == 'home'
                    ? 'submitted-back-home'
                    : 'submitted-view-products',
              );
            }
            expect(result, isTrue);
            expect(
              confirmationDestination,
              action == 'products' ? 'products' : 'home',
            );
            expect(find.text('Review & Submit'), findsNothing);
            expect(find.text('Open form'), findsOneWidget);
            expect(posts, 1);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              posts++;
              return http.Response(successResponse(), 201);
            }
            return status();
          }),
        );
      },
    );
  }

  testWidgets(
    'returned approval status is displayed without assuming pending',
    (tester) async {
      await http.runWithClient(
        () async {
          await open(tester);
          await review(tester);
          await tapKey(tester, 'submit-product');
          expect(find.text('Archived'), findsNWidgets(2));
          expect(find.text('Pending Approval'), findsNothing);
          expect(find.textContaining('once it'), findsNothing);
          await tapKey(tester, 'submitted-back-home');
        },
        () => MockClient(
          (request) async => request.method == 'POST'
              ? http.Response(
                  successResponse().replaceAll('"pending"', '"archived"'),
                  201,
                )
              : status(),
        ),
      );
    },
  );

  testWidgets('incomplete product confirmation keeps review and draft', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await open(tester);
        await review(tester);
        await tapKey(tester, 'submit-product');
        expectStep(tester, 4);
        expect(find.text('Product Submitted!'), findsNothing);
        expect(find.text('Test Notebook'), findsOneWidget);
        expect(
          find.textContaining('Check My Products before trying again.'),
          findsOneWidget,
        );
        expect(result, isNull);
      },
      () => MockClient(
        (request) async => request.method == 'POST'
            ? http.Response('{"product":{"id":71}}', 201)
            : status(),
      ),
    );
  });

  testWidgets('malformed success stays on review without a false success', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await open(tester);
        await review(tester);
        await submit(tester);
        await tester.pumpAndSettle();
        expectStep(tester, 4);
        expect(result, isNull);
        expect(
          find.byKey(const ValueKey('product-submit-error')),
          findsOneWidget,
        );
      },
      () => MockClient(
        (request) async =>
            request.method == 'GET' ? status() : http.Response('{}', 201),
      ),
    );
  });

  testWidgets(
    'older batch server preserves review and backward-navigation drafts without posting',
    (tester) async {
      var posts = 0;
      await http.runWithClient(
        () async {
          await open(tester);
          await information(tester);
          await field(tester, 'product-price', '10');
          await tapKey(tester, 'inventory-fifo');
          await field(tester, 'batch-quantity-1', '2');
          await batchDate(tester, 1);
          await next(tester);
          await next(tester);
          await submit(tester);
          await tester.pumpAndSettle();
          expect(
            find.text(
              'This server does not yet support initial batches. Your draft is preserved. Contact your administrator.',
            ),
            findsOneWidget,
          );
          await back(tester);
          await back(tester);
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('batch-quantity-1')),
                )
                .controller!
                .text,
            '2',
          );
          expect(posts, 0);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') posts++;
          return status();
        }),
      );
    },
  );

  testWidgets(
    'optional perishable expiry survives steps and clears for a different category',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        await information(tester, selected: 'Snacks');
        final expiry = find.text('Select expiry date');
        await tester.ensureVisible(expiry);
        await tester.tap(expiry);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear expiry date'), findsOneWidget);
        await inventory(tester);
        await back(tester);
        expect(find.byTooltip('Clear expiry date'), findsOneWidget);
        await back(tester);
        await category(tester, 'School Supplies');
        await next(tester);
        expect(find.text('Expiry Date (Optional)'), findsNothing);
      }, () => MockClient((_) async => status()));
    },
  );

  testWidgets(
    'seller access and empty category guards keep their existing behavior',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        expect(find.byType(SellerAddProductPage), findsNothing);
        expect(
          find.text('Approved active seller access is required.'),
          findsOneWidget,
        );
      }, () => MockClient((_) async => status(approved: false)));
      await http.runWithClient(() async {
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();
        expectStep(tester, 1);
        expect(
          find.text(
            'No categories are available. Go back and reopen Add Product to retry.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('continue-product')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(SellerAddProductPage), findsNothing);
      }, () => MockClient((_) async => status(categories: [])));
    },
  );

  testWidgets(
    'bottom actions stay visible when content scrolls and keyboard opens',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        final action = find.byKey(const ValueKey('continue-product'));
        final initial = tester.getRect(action);
        expect(initial.bottom, closeTo(828, 1));
        await tester.drag(
          find.byKey(const ValueKey('add-product-scroll')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(action), initial);
        await field(tester, 'product-name', 'Keyboard fixture');
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.getRect(action).bottom, closeTo(548, 1));
        await capture(tester, 'bottom-actions-keyboard');
        tester.view.resetViewInsets();
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => status()));
    },
  );

  testWidgets(
    'required markers, validation text and focused error borders use red',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        await next(tester);
        final fieldFinder = find.byKey(const ValueKey('product-name'));
        final input = tester.widget<TextFormField>(fieldFinder);
        expect(
          Theme.of(tester.element(fieldFinder)).colorScheme.error,
          ProductFormStyle.error,
        );
        final decorator = tester.widget<InputDecorator>(
          find.descendant(
            of: fieldFinder,
            matching: find.byType(InputDecorator),
          ),
        );
        expect(decorator.decoration.errorStyle!.color, ProductFormStyle.error);
        expect(
          (decorator.decoration.focusedErrorBorder! as OutlineInputBorder)
              .borderSide
              .color,
          ProductFormStyle.error,
        );
        expect(input.controller!.text, isEmpty);
        final label = tester.widget<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is ProductFieldLabel &&
                  widget.label == 'Product Name *',
            ),
            matching: find.byType(Text),
          ),
        );
        final spans = (label.textSpan! as TextSpan).children!
            .whereType<TextSpan>();
        expect(
          spans.any(
            (span) =>
                span.text == '*' && span.style!.color == ProductFormStyle.error,
          ),
          isTrue,
        );
        await capture(tester, 'required-errors-red');
      }, () => MockClient((_) async => status()));
    },
  );

  testWidgets(
    'tags become removable chips, ignore duplicates and submit unfinished text safely',
    (tester) async {
      Map<String, dynamic>? posted;
      await http.runWithClient(
        () async {
          await open(tester);
          await field(tester, 'product-name', 'Tagged fixture');
          expect(
            tester
                .getSize(find.byKey(const ValueKey('product-tags-container')))
                .height,
            lessThanOrEqualTo(56),
          );
          final tagHeight = tester
              .getSize(find.byKey(const ValueKey('product-tags-container')))
              .height;
          final tagsWrap = find
              .descendant(
                of: find.byKey(const ValueKey('product-tags-container')),
                matching: find.byType(Wrap),
              )
              .first;
          final tagBorderHeight = InputDecorator.containerOf(
            tester.element(tagsWrap),
          )!.size.height;
          final nameEditable = find.descendant(
            of: find.byKey(const ValueKey('product-name')),
            matching: find.byType(EditableText),
          );
          final nameHeight = InputDecorator.containerOf(
            tester.element(nameEditable),
          )!.size.height;
          expect(tagHeight, closeTo(nameHeight, 1));
          expect(tagBorderHeight, closeTo(nameHeight, 1));
          await category(tester, 'School Supplies');
          await field(tester, 'product-description', 'A tag entry test.');
          await field(tester, 'product-tags', 'homemade');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('product-tag-homemade')),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('product-tags-container')))
                .height,
            lessThanOrEqualTo(56),
          );
          await field(tester, 'product-tags', 'local, homemade,');
          expect(find.byType(InputChip), findsNWidgets(2));
          final bounds = tester.getRect(
            find.byKey(const ValueKey('product-tags-container')),
          );
          for (final chip in find.byType(InputChip).evaluate()) {
            final rect = tester.getRect(find.byWidget(chip.widget));
            expect(bounds.contains(rect.topLeft), isTrue);
            expect(bounds.contains(rect.bottomRight), isTrue);
          }
          final remove = find.byTooltip('Remove tag homemade');
          await tester.ensureVisible(remove);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('product-tag-homemade')),
            findsNothing,
          );
          await field(tester, 'product-tags', 'fresh');
          await capture(tester, 'tag-chips');
          await next(tester);
          await back(tester);
          expect(
            find.byKey(const ValueKey('product-tag-local')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('product-tag-fresh')),
            findsOneWidget,
          );
          await next(tester);
          await inventory(tester);
          await next(tester);
          expect(
            find.byKey(const ValueKey('review-tag-local')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('review-tag-fresh')),
            findsOneWidget,
          );
          expect(posted, isNull);
          await submit(tester);
          await tester.pumpAndSettle();
          expect(posted!['tags'], 'local, fresh');
          expect(result, isTrue);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return status();
          posted = jsonDecode(request.body);
          return http.Response(successResponse(), 201);
        }),
      );
    },
  );

  testWidgets(
    'long tag chips fit a narrow large-text form and keep their remove action',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester, width: 280, scale: 2);
        await field(
          tester,
          'product-tags',
          'a-very-long-tag-for-homemade-campus-products,',
        );
        final chip = find.byType(InputChip);
        await tester.ensureVisible(chip);
        final rect = tester.getRect(chip);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(264));
        await capture(tester, 'tag-chips-280');
        await tester.tap(
          find.byTooltip(
            'Remove tag a-very-long-tag-for-homemade-campus-products',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InputChip), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => status()));
    },
  );

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets('tag instructions appear only from help icon at $width', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await open(tester, width: width, scale: scale);
        expect(find.text(ProductTagInput.instructions), findsNothing);
        expect(
          tester
              .widget<InputDecorator>(
                find.byKey(const ValueKey('product-tags-container')),
              )
              .decoration
              .hintText,
          '',
        );
        final info = find.byKey(const ValueKey('product-tags-info'));
        if (scale == 1) {
          final label = find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is ProductFieldLabel &&
                  widget.label == 'Tags (Optional)',
            ),
            matching: find.byType(Text),
          );
          expect(
            tester
                    .getTopLeft(
                      find.byKey(const ValueKey('product-tags-info-glyph')),
                    )
                    .dx -
                tester.getTopRight(label).dx,
            closeTo(4, 1),
          );
        }
        await tapKey(tester, 'product-tags-info');
        expect(find.text(ProductTagInput.instructions), findsOneWidget);
        final rect = tester.getRect(find.text(ProductTagInput.instructions));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844));
        await capture(tester, 'tags-help-${width.toInt()}');
        await tester.tapAt(const Offset(150, 60));
        await tester.pumpAndSettle();
        expect(find.text(ProductTagInput.instructions), findsNothing);
        await tester.longPress(info);
        await tester.pumpAndSettle();
        expect(find.text(ProductTagInput.instructions), findsOneWidget);
        await tester.pump(const Duration(seconds: 13));
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(info));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(ProductTagInput.instructions), findsOneWidget);
        await mouse.removePointer();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => status()));
    });
  }

  Future<void> expiryDate(
    WidgetTester tester,
    String id, {
    DateTime? date,
    bool cancel = false,
  }) async {
    await tapKey(tester, '$id-calendar');
    if (id == 'product-expiry') await capture(tester, 'expiry-calendar');
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateUtils.dateOnly(DateTime.now()));
    if (date != null) calendar.onDateChanged(date);
    await tester.tap(find.text(cancel ? 'Cancel' : 'OK'));
    await tester.pumpAndSettle();
    expectStep(tester, 2);
  }

  for (final selected in [false, true]) {
    testWidgets(
      'optional simple expiry submits selected=$selected and supports cancel/clear',
      (tester) async {
        Map<String, dynamic>? posted;
        await http.runWithClient(
          () async {
            await open(tester);
            await information(tester, selected: 'Snacks');
            expect(
              find.text('Does this product have an expiry date?'),
              findsNothing,
            );
            await expiryDate(tester, 'product-expiry', cancel: true);
            expect(find.byTooltip('Clear expiry date'), findsNothing);
            final today = DateUtils.dateOnly(DateTime.now());
            await expiryDate(tester, 'product-expiry', date: today);
            expect(find.text(ProductExpiryField.format(today)), findsOneWidget);
            await capture(tester, 'simple-expiry-selected');
            if (!selected) {
              await tapKey(tester, 'product-expiry-clear');
              expect(find.text('Select expiry date'), findsOneWidget);
            }
            await inventory(tester);
            await next(tester);
            await submit(tester);
            expect(
              posted?['expiry_date'],
              selected ? ProductFormStyle.date(today) : isNull,
            );
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              posted = jsonDecode(request.body);
              return http.Response(successResponse(), 201);
            }
            return status();
          }),
        );
      },
    );
  }

  for (final supported in [true, false]) {
    testWidgets(
      'batch expiry retains independent dates and requires server support=$supported',
      (tester) async {
        Map<String, dynamic>? posted;
        await http.runWithClient(
          () async {
            await open(tester);
            await information(tester, selected: 'Snacks');
            final today = DateUtils.dateOnly(DateTime.now());
            await expiryDate(
              tester,
              'product-expiry',
              date: today.add(const Duration(days: 3)),
            );
            await field(tester, 'product-price', '20');
            await tapKey(tester, 'inventory-fifo');
            expect(find.byKey(const ValueKey('product-expiry')), findsNothing);
            await field(tester, 'batch-quantity-1', '2');
            await batchDate(tester, 1);
            await expiryDate(tester, 'batch-expiry-1', date: today);
            await tapKey(tester, 'add-product-batch');
            await field(tester, 'batch-quantity-2', '4');
            await batchDate(tester, 2);
            await expiryDate(
              tester,
              'batch-expiry-2',
              date: today.add(const Duration(days: 2)),
            );
            await tapKey(tester, 'inventory-simple');
            expect(
              find.text(
                ProductExpiryField.format(today.add(const Duration(days: 3))),
              ),
              findsOneWidget,
            );
            await tapKey(tester, 'inventory-fifo');
            expect(find.text(ProductExpiryField.format(today)), findsOneWidget);
            expect(
              find.text(
                ProductExpiryField.format(today.add(const Duration(days: 2))),
              ),
              findsOneWidget,
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('batch-expiry-2')),
            );
            await capture(tester, 'batch-expiry');
            await next(tester);
            await back(tester);
            expect(find.text(ProductExpiryField.format(today)), findsOneWidget);
            await next(tester);
            await next(tester);
            await tapKey(tester, 'review-batches');
            expect(
              find.textContaining('Expiry ${ProductExpiryField.format(today)}'),
              findsOneWidget,
            );
            await submit(tester);
            await tester.pumpAndSettle();
            if (supported) {
              final batches = posted!['initial_batches'] as List;
              expect(batches[0]['expiry_date'], ProductFormStyle.date(today));
              expect(
                batches[1]['expiry_date'],
                ProductFormStyle.date(today.add(const Duration(days: 2))),
              );
              expect(posted!['expiry_date'], isNull);
            } else {
              expect(posted, isNull);
              expect(
                find.textContaining('does not yet support batch expiry dates'),
                findsOneWidget,
              );
              await back(tester);
              await back(tester);
              expect(
                find.text(ProductExpiryField.format(today)),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              posted = jsonDecode(request.body);
              return http.Response(successResponse(batches: 2), 201);
            }
            if (request.url.path.endsWith('/products/submit/')) {
              return http.Response(
                jsonEncode({
                  'capabilities': {
                    'initial_batches': true,
                    'initial_batch_expiry': supported,
                  },
                }),
                200,
              );
            }
            return status();
          }),
        );
      },
    );
  }

  for (final width in [390.0, 280.0]) {
    testWidgets(
      'expiry help supports tap long press hover and outside dismissal at $width',
      (tester) async {
        await http.runWithClient(() async {
          await open(tester, width: width, scale: width == 280 ? 2 : 1);
          await information(tester, selected: 'Snacks');
          await tapKey(tester, 'product-expiry-info');
          expect(find.text(ProductExpiryField.explanation), findsOneWidget);
          final rect = tester.getRect(
            find.text(ProductExpiryField.explanation),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(844));
          await capture(tester, 'expiry-help-${width.toInt()}');
          await tester.tapAt(const Offset(10, 60));
          await tester.pumpAndSettle();
          expect(find.text(ProductExpiryField.explanation), findsNothing);
          final info = find.byKey(const ValueKey('product-expiry-info'));
          await tester.longPress(info);
          await tester.pumpAndSettle();
          expect(find.text(ProductExpiryField.explanation), findsOneWidget);
          Tooltip.dismissAllToolTips();
          await tester.pumpAndSettle();
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(info));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.text(ProductExpiryField.explanation), findsOneWidget);
          await mouse.removePointer();
          expect(tester.takeException(), isNull);
        }, () => MockClient((_) async => status()));
      },
    );
  }

  for (final (width, scale) in [(390.0, 1.0), (280.0, 2.0)]) {
    testWidgets(
      'review sections edit existing steps and preserve all drafts at $width/$scale',
      (tester) async {
        await http.runWithClient(() async {
          await open(tester, width: width, scale: scale);
          await information(tester, selected: 'Snacks');
          await field(tester, 'product-price', '30');
          await field(tester, 'product-quantity', '5');
          await field(tester, 'product-low-stock-threshold', '5');
          await expiryDate(tester, 'product-expiry');
          await next(tester);
          picker.files = [
            XFile.fromData(png, name: 'first.png'),
            XFile.fromData(Uint8List.fromList([...png, 2]), name: 'cover.png'),
          ];
          await tapKey(tester, 'add-product-image');
          await tapKey(tester, 'product-image-preview-1');
          await tapKey(tester, 'primary-product-image-1');
          await next(tester);
          expectStep(tester, 4);
          expect(find.byType(TextFormField), findsNothing);
          expect(find.text('₱30.00'), findsOneWidget);
          expect(find.text('5 units'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('review-low-stock-notice')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('review-tag-school')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('remove-product-image-0')),
            findsNothing,
          );
          final cover = tester
              .widget<ProductImage>(
                find.byKey(const ValueKey('review-product-image-0')),
              )
              .imageUrl;
          expect(cover, 'data:image/png;base64,${base64Encode([...png, 2])}');
          final coverCard = find.byKey(const ValueKey('review-photo-card-0'));
          final coverLabel = find.descendant(
            of: coverCard,
            matching: find.text('Cover'),
          );
          expect(
            tester.getRect(coverLabel).top,
            greaterThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('review-product-image-0')))
                  .bottom,
            ),
          );
          expect(find.text('Photo 2'), findsOneWidget);
          expect(
            find.descendant(of: coverCard, matching: find.byIcon(Icons.check)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: coverCard,
              matching: find.byIcon(LucideIcons.check),
            ),
            findsNothing,
          );
          const approvalMessage =
              "Your product will be reviewed by the Administrator before it appears in the marketplace. You'll be notified once the review is complete.";
          expect(find.text(approvalMessage), findsOneWidget);
          expect(find.textContaining('Marketplace Admin'), findsNothing);
          final approval = find.byKey(
            const ValueKey('review-product-approval'),
          );
          final approvalText = tester.getRect(find.text(approvalMessage));
          expect(
            approvalText.left,
            closeTo(tester.getRect(approval).left + 12, .1),
          );
          expect(
            approvalText.top,
            greaterThan(tester.getRect(find.text('Product Approval')).bottom),
          );
          await capture(tester, 'review-top-${width.toInt()}');
          await tester.ensureVisible(
            find.byKey(const ValueKey('review-low-stock-notice')),
          );
          await capture(tester, 'review-inventory-${width.toInt()}');
          await tester.ensureVisible(coverCard);
          await capture(tester, 'review-images-${width.toInt()}');
          await tester.ensureVisible(approval);
          await tester.pumpAndSettle();
          await capture(tester, 'review-approval-${width.toInt()}');
          await tapKey(tester, 'review-edit-0');
          expectStep(tester, 1);
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('product-name')),
                )
                .controller!
                .text,
            'Test Notebook',
          );
          expect(
            find.byKey(const ValueKey('product-tag-school')),
            findsOneWidget,
          );
          await field(tester, 'product-name', 'Updated snack');
          await next(tester);
          await next(tester);
          await next(tester);
          expect(find.text('Updated snack'), findsOneWidget);
          await tapKey(tester, 'review-edit-1');
          expectStep(tester, 2);
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('product-quantity')),
                )
                .controller!
                .text,
            '5',
          );
          expect(find.byTooltip('Clear expiry date'), findsOneWidget);
          await field(tester, 'product-quantity', '6');
          await next(tester);
          await next(tester);
          expect(find.text('6 units'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('review-low-stock-notice')),
            findsNothing,
          );
          await tapKey(tester, 'review-edit-2');
          expectStep(tester, 3);
          expect(find.byKey(const ValueKey('product-cover-1')), findsOneWidget);
          expect(find.text('2 of 6'), findsOneWidget);
          await next(tester);
          expect(
            tester
                .widget<ProductImage>(
                  find.byKey(const ValueKey('review-product-image-0')),
                )
                .imageUrl,
            cover,
          );
          await back(tester);
          expectStep(tester, 3);
          expect(find.byKey(const ValueKey('product-cover-1')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, () => MockClient((_) async => status()));
      },
    );
  }

  for (final batch in [false, true]) {
    for (final invalidQuantity in ['', '-1']) {
      testWidgets(
        'final submission rechecks retained ${batch ? 'batch' : 'standard'} inputs with ${invalidQuantity.isEmpty ? 'missing' : 'invalid'} quantity',
        (tester) async {
          var posts = 0;
          await http.runWithClient(
            () async {
              await open(tester);
              await information(tester);
              await field(tester, 'product-price', '30');
              if (batch) await tapKey(tester, 'inventory-fifo');
              final key = batch ? 'batch-quantity-1' : 'product-quantity';
              await field(tester, key, '5');
              final quantity = tester
                  .widget<TextFormField>(find.byKey(ValueKey(key)))
                  .controller!;
              if (batch) await batchDate(tester, 1);
              await next(tester);
              await next(tester);
              expectStep(tester, 4);
              quantity.text = invalidQuantity;
              await tapKey(tester, 'submit-product');
              expectStep(tester, 2);
              expect(quantity.text, invalidQuantity);
              expect(
                find.byKey(const ValueKey('product-submit-error')),
                findsOneWidget,
              );
              final expectedError = batch
                  ? 'Batch 1: ${invalidQuantity.isEmpty ? 'Batch quantity is required.' : 'Enter a whole-number batch quantity greater than 0.'}'
                  : invalidQuantity.isEmpty
                  ? 'Stock quantity is required.'
                  : 'Please enter a valid stock quantity.';
              expect(
                tester
                    .widget<Text>(
                      find.byKey(const ValueKey('product-submit-error')),
                    )
                    .data,
                expectedError,
              );
              expect(posts, 0);
              expect(find.text('Product Submitted!'), findsNothing);
            },
            () => MockClient((request) async {
              if (request.method == 'POST') posts++;
              return status();
            }),
          );
        },
      );
    }
  }

  testWidgets(
    'zero stock review notice is informational and does not disable submit',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester);
        await information(tester);
        await field(tester, 'product-low-stock-threshold', '0');
        await inventory(tester, quantity: '0');
        await next(tester);
        expect(
          find.byKey(const ValueKey('review-low-stock-notice')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('submit-product')),
              )
              .onPressed,
          isNotNull,
        );
      }, () => MockClient((_) async => status()));
    },
  );

  testWidgets('category popup stays aligned after keyboard inset changes', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester);
      await field(tester, 'product-name', 'Menu alignment fixture');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final anchor = find.byKey(const ValueKey('product-category'));
      await tester.ensureVisible(anchor);
      await tester.tap(anchor);
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final fieldRect = tester.getRect(anchor);
      final menu = find
          .ancestor(
            of: find.byType(MenuItemButton).first,
            matching: find.byType(Material),
          )
          .first;
      final menuRect = tester.getRect(menu);
      expect(menuRect.left, closeTo(fieldRect.left, 1));
      expect(menuRect.right, closeTo(fieldRect.right, 1));
      expect(menuRect.top, closeTo(fieldRect.bottom + 4, 1));
      await capture(tester, 'category-keyboard-alignment');
      await tester.tap(find.text('Snacks').last);
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => status()));
  });

  for (final width in [280.0, 390.0, 640.0]) {
    testWidgets('category menu edges match the input at $width', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await open(tester, width: width);
        await category(tester, 'School Supplies');
        final anchor = find.byKey(const ValueKey('product-category'));
        await tester.ensureVisible(anchor);
        final before = tester.getRect(anchor);
        await tester.tap(anchor);
        await tester.pumpAndSettle();
        final menu = find
            .ancestor(
              of: find.byType(MenuItemButton).first,
              matching: find.byType(Material),
            )
            .first;
        final rect = tester.getRect(menu);
        expect(rect.left, closeTo(before.left, 1));
        expect(rect.right, closeTo(before.right, 1));
        expect(rect.top, closeTo(before.bottom + 4, 1));
        expect(rect.width, closeTo(before.width, 1));
        await capture(tester, 'category-aligned-${width.toInt()}');
        await tester.tapAt(const Offset(150, 60));
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.text('School Supplies'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => status()));
    });
  }
}
