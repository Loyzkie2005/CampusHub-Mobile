import 'package:campushub/module_app/theme/app_typography.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/product_item.dart';
import '../services/product_service.dart';
import '../services/seller_application_service.dart';
import '../widgets/product_image.dart';
import '../widgets/seller/product_inventory_fields.dart';
import '../widgets/seller/product_expiry_field.dart';
import '../widgets/seller/product_tag_input.dart';
import '../widgets/seller/product_upload_icon.dart';

/// Four retained draft steps; ownership and approval remain enforced by Django.
enum ProductSubmissionDestination { products, home }

class SellerAddProductPage extends StatefulWidget {
  const SellerAddProductPage({super.key, required this.categories});

  final List<String> categories;

  @override
  State<SellerAddProductPage> createState() => _SellerAddProductPageState();
}

class _SellerAddProductPageState extends State<SellerAddProductPage> {
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxImages = 6;
  static const _line = ProductFormStyle.border;
  static const _muted = ProductFormStyle.muted;
  final _form = GlobalKey<FormState>();
  final _categoryLink = LayerLink();
  final _scroll = ScrollController();
  int _step = 0;
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _tagEntry = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();
  // Prefilled with the backend default (CAMPUSHUB_LOW_STOCK_THRESHOLD = 5).
  final _lowStockThreshold = TextEditingController(text: '5');
  String? _category, _imageError, _submitError;
  String _inventoryMethod = 'simple';
  final _batches = <ProductBatchDraft>[ProductBatchDraft()];
  final _removedBatches = <ProductBatchDraft>[];
  int? _primaryImage;
  final List<String?> _selectedImages = List.filled(_maxImages, null);
  DateTime? _expiry;
  Map<String, dynamic>? _submittedProduct;
  bool _leavingConfirmation = false;
  bool _submitting = false, _picking = false, _submitted = false;

  bool get _busy => _submitting || _picking;
  int get _imageCount => _selectedImages.whereType<String>().length;
  bool get _perishable => ProductItem.isPerishableCategory(_category);
  int get _batchTotal => _batches.fold(0, (sum, batch) {
    final value = int.tryParse(batch.quantity.text.trim());
    return sum + (value != null && value > 0 ? value : 0);
  });
  List<String> get _orderedImages => [
    if (_primaryImage != null && _selectedImages[_primaryImage!] != null)
      _selectedImages[_primaryImage!]!,
    for (var i = 0; i < _selectedImages.length; i++)
      if (i != _primaryImage && _selectedImages[i] != null) _selectedImages[i]!,
  ];

  @override
  void dispose() {
    _scroll.dispose();
    for (final batch in [..._batches, ..._removedBatches]) {
      batch.dispose();
    }
    for (final controller in [
      _name,
      _description,
      _tags,
      _tagEntry,
      _price,
      _quantity,
      _lowStockThreshold,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? '$label is required.' : null;

  String? _validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Selling price is required.';
    final amount = double.tryParse(text);
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text) ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      return 'Please enter a valid selling price.';
    }
    return null;
  }

  String? _validateStock(String? value) {
    return ProductFormStyle.quantity(value);
  }

  String? _validateLowStockThreshold(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Low stock threshold is required.';
    final parsed = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) ||
        parsed == null ||
        parsed < 0 ||
        parsed > ProductFormStyle.maxQuantity) {
      return 'Enter a whole-number threshold of 0 or more.';
    }
    return null;
  }

  String? _imageMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        base64Encode(bytes.sublist(0, 8)) == 'iVBORw0KGgo=') {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 6 &&
        [
          'GIF87a',
          'GIF89a',
        ].contains(ascii.decode(bytes.sublist(0, 6), allowInvalid: true))) {
      return 'image/gif';
    }
    return null;
  }

  Future<String> _readImage(XFile file) async {
    if (await file.length() > _maxImageBytes) {
      throw const FormatException('Choose an image no larger than 5 MB.');
    }
    final bytes = await file.readAsBytes();
    final mime = _imageMime(bytes);
    if (bytes.isEmpty || bytes.length > _maxImageBytes || mime == null) {
      throw const FormatException(
        'Choose a JPEG, PNG, WebP or GIF image up to 5 MB.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 20000000) {
          throw const FormatException(
            'Choose an image smaller than 20 megapixels.',
          );
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _pickImages({int? slot}) async {
    if (_busy) return;
    final remaining = _maxImages - _imageCount;
    if (slot == null && remaining == 0) return;
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (slot != null || remaining == 1) {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage(
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
          requestFullMetadata: false,
          limit: remaining,
        );
      }
      if (files.isEmpty || !mounted) return;
      if (files.length > (slot == null ? remaining : 1)) {
        throw const FormatException(
          'You can upload up to 6 images. Select fewer images.',
        );
      }
      // Validate the whole batch before changing any existing slot.
      final images = <String>[];
      for (final file in files) {
        images.add(await _readImage(file));
      }
      if (mounted) {
        setState(() {
          if (slot != null) {
            _selectedImages[slot] = images.single;
          } else {
            final emptySlots = [
              for (var i = 0; i < _maxImages; i++)
                if (_selectedImages[i] == null) i,
            ];
            for (var i = 0; i < images.length; i++) {
              _selectedImages[emptySlots[i]] = images[i];
            }
          }
          _primaryImage ??= _selectedImages.indexWhere(
            (image) => image != null,
          );
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => _imageError = failure is FormatException
              ? failure.message
              : 'Unable to open this image. Check photo access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Widget _categoryField(List<String> categories) => FormField<String>(
    initialValue: _category,
    validator: (_) => _category == null ? 'Category is required.' : null,
    builder: (state) => LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        layerLink: _categoryLink,
        alignmentOffset: const Offset(0, 4),
        consumeOutsideTap: true,
        crossAxisUnconstrained: false,
        style: MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(2),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 320)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 8),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: _line),
            ),
          ),
        ),
        menuChildren: [
          for (final category in categories)
            MenuItemButton(
              onPressed: () {
                setState(() {
                  _category = category;
                  if (!_perishable) {
                    _expiry = null;
                    for (final batch in _batches) {
                      batch.expiryDate = null;
                    }
                  }
                });
                state.didChange(category);
              },
              style: MenuItemButton.styleFrom(
                minimumSize: Size(constraints.maxWidth, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                foregroundColor: ProductFormStyle.navy,
                textStyle: AppTypography.input.copyWith(
                  fontWeight: category == _category
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              child: Text(category),
            ),
        ],
        builder: (context, controller, child) => InkWell(
          key: const ValueKey('product-category'),
          borderRadius: BorderRadius.circular(12),
          onTap: _busy || categories.isEmpty
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
          child: InputDecorator(
            isEmpty: _category == null,
            decoration: _decoration('Select category').copyWith(
              errorText: state.errorText,
              enabled: !_busy && categories.isNotEmpty,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ProductFormStyle.navy,
              ),
            ),
            child: Text(
              _category ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.input.copyWith(color: ProductFormStyle.navy),
            ),
          ),
        ),
      ),
    ),
  );
  bool _validInventoryTotal() {
    if (_inventoryMethod != 'fifo' ||
        (_batches.isNotEmpty && _batchTotal <= ProductFormStyle.maxQuantity)) {
      return true;
    }
    setState(
      () => _submitError =
          'Add at least one batch and keep total stock at 2,147,483,647 or less.',
    );
    return false;
  }

  void _changeStep(int step) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    Tooltip.dismissAllToolTips();
    setState(() {
      _step = step;
      _submitted = false;
      _submitError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _back() {
    if (_busy) return;
    if (_step > 0) {
      _changeStep(_step - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _continue() {
    if (_busy || _step == 3) return;
    if (_step == 2 && _imageCount == 0) {
      setState(() => _imageError = 'Please add at least one product photo.');
      return;
    }
    if (_step == 0) ProductTagInput.commit(_tags, _tagEntry);
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    if (_step == 1 && !_validInventoryTotal()) return;
    _changeStep(_step + 1);
  }

  (int, String)? _draftIssue() {
    if (_required(_name.text, 'Product name') != null ||
        _name.text.characters.length > 150 ||
        _category == null ||
        !widget.categories.contains(_category) ||
        _required(_description.text, 'Description') != null) {
      return (0, 'Check the required product information before submitting.');
    }
    final priceError = _validatePrice(_price.text);
    if (priceError != null) return (1, priceError);
    final thresholdError = _validateLowStockThreshold(_lowStockThreshold.text);
    if (thresholdError != null) return (1, thresholdError);
    if (_inventoryMethod == 'simple') {
      final error =
          _validateStock(_quantity.text) ??
          (_perishable ? ProductFormStyle.expiryDate(_expiry) : null);
      if (error != null) return (1, error);
    } else if (_inventoryMethod == 'fifo') {
      if (_batches.isEmpty ||
          _batches.length > 100 ||
          _batchTotal > ProductFormStyle.maxQuantity) {
        return (
          1,
          'Add valid batches and keep total stock at 2,147,483,647 or less.',
        );
      }
      for (var i = 0; i < _batches.length; i++) {
        final batch = _batches[i];
        final error =
            ProductFormStyle.quantity(batch.quantity.text, positive: true) ??
            ProductFormStyle.receivedDate(batch.receivedAt) ??
            ProductFormStyle.unitCost(batch.unitCost.text) ??
            (_perishable
                ? ProductFormStyle.expiryDate(batch.expiryDate)
                : null);
        if (error != null) return (1, 'Batch ${i + 1}: $error');
      }
    } else {
      return (1, 'Select a valid stock method.');
    }
    if (_imageCount == 0) {
      return (2, 'Please add at least one product photo.');
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || _step != 3 || _submittedProduct != null) return;
    final issue = _draftIssue();
    if (issue != null) {
      _changeStep(issue.$1);
      setState(() {
        _submitted = true;
        _submitError = issue.$2;
        if (issue.$1 == 2) _imageError = issue.$2;
      });
      return;
    }
    setState(() => _submitted = true);
    if (!_validInventoryTotal()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final thresholdText = _lowStockThreshold.text.trim();
      final product = await ProductService.submitProduct(
        name: _name.text.trim(),
        price: _price.text.trim(),
        category: _category!,
        stock: _inventoryMethod == 'fifo'
            ? _batchTotal
            : int.parse(_quantity.text.trim()),
        inventoryMethod: _inventoryMethod,
        initialBatches: _inventoryMethod == 'fifo'
            ? _batches
                  .map((batch) => batch.toJson(includeExpiry: _perishable))
                  .toList()
            : null,
        lowStockThreshold: thresholdText.isNotEmpty
            ? int.tryParse(thresholdText)
            : null,
        tags: _tags.text.trim().isNotEmpty ? _tags.text.trim() : null,
        description: _description.text.trim(),
        expiryDate:
            _inventoryMethod == 'simple' && _perishable && _expiry != null
            ? '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}'
            : null,
        images: _orderedImages,
      );
      if (!mounted) return;
      final price = num.tryParse('${product['price']}');
      if (product['id'] is! int ||
          (product['id'] as int) <= 0 ||
          product['name'] is! String ||
          (product['name'] as String).trim().isEmpty ||
          product['category'] is! String ||
          (product['category'] as String).trim().isEmpty ||
          price == null ||
          !price.isFinite ||
          price <= 0 ||
          ![
            'pending',
            'approved',
            'rejected',
            'archived',
          ].contains(product['approval_status'])) {
        throw const SellerApplicationException(
          'Unable to confirm the submitted product details. Check My Products before trying again.',
        );
      }
      setState(() {
        _submittedProduct = Map<String, dynamic>.unmodifiable(product);
        _submitting = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(
          () => _submitError = failure is SellerApplicationException
              ? failure.message
              : 'Unable to confirm submission. Check My Products before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _submissionConfirmation(Map<String, dynamic> product) {
    final status = switch (product['approval_status']) {
      'pending' => 'Pending Approval',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'archived' => 'Archived',
      _ => 'Status unavailable',
    };
    final images = product['images'];
    final cover = images is List && images.isNotEmpty && images.first is String
        ? images.first as String
        : product['image_url'] is String
        ? product['image_url'] as String
        : '';
    void leave(ProductSubmissionDestination destination) {
      if (!mounted || _leavingConfirmation) return;
      _leavingConfirmation = true;
      Navigator.of(context).pop(destination);
    }

    return Theme(
      data: AppTypography.theme(
        Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: ProductFormStyle.navy,
            displayColor: ProductFormStyle.navy,
          ),
          colorScheme: const ColorScheme.light(
            primary: ProductFormStyle.navy,
            secondary: ProductFormStyle.gold,
            surface: Colors.white,
            onSurface: ProductFormStyle.navy,
          ),
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) leave(ProductSubmissionDestination.home);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    key: const ValueKey('submitted-content-viewport'),
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 32).clamp(
                            0,
                            double.infinity,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              key: const ValueKey(
                                'submitted-confirmation-content',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ProductFormStyle.gold.withValues(
                                        alpha: .12,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: ProductFormStyle.navy,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Semantics(
                                  header: true,
                                  liveRegion: true,
                                  child: const Text(
                                    'Product Submitted!',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.screenHeader,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  product['approval_status'] == 'pending'
                                      ? "Your product has been sent for review. You'll be notified once it's approved."
                                      : 'Your product submission was confirmed. Its current status is shown below.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.helper.copyWith(
                                    color: _muted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ProductFormStyle.gold.withValues(
                                        alpha: .16,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status,
                                      style: AppTypography.progress.copyWith(
                                        color: ProductFormStyle.navy,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  key: const ValueKey(
                                    'submitted-product-summary',
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox.square(
                                          dimension: 72,
                                          child: ProductImage(
                                            key: const ValueKey(
                                              'submitted-product-cover',
                                            ),
                                            imageUrl: cover,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name'] as String,
                                              style: AppTypography.cardTitle,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₱${num.parse('${product['price']}').toStringAsFixed(2)}',
                                              style: AppTypography.cardTitle,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              product['category'] as String,
                                              style: AppTypography.helper
                                                  .copyWith(color: _muted),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              status,
                                              style: AppTypography.helper,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        key: const ValueKey('submitted-view-products'),
                        onPressed: () =>
                            leave(ProductSubmissionDestination.products),
                        style: FilledButton.styleFrom(
                          backgroundColor: ProductFormStyle.navy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View My Products',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('submitted-back-home'),
                        onPressed: () =>
                            leave(ProductSubmissionDestination.home),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          'Back to Home',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progress() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: ColoredBox(
                color: _line,
                child: ShaderMask(
                  key: const ValueKey('product-step-gradient'),
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      ProductFormStyle.gold,
                      ProductFormStyle.gold,
                      ProductFormStyle.navy,
                      ProductFormStyle.navy,
                    ],
                    stops: [0, .5, .75, 1],
                  ).createShader(bounds),
                  child: LinearProgressIndicator(
                    key: const ValueKey('product-step-progress'),
                    value: (_step + 1) / 4,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white,
                    backgroundColor: Colors.transparent,
                    semanticsLabel: 'Product listing progress',
                    semanticsValue: 'Step ${_step + 1} of 4',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Step ${_step + 1} of 4',
            key: const ValueKey('product-step-label'),
            style: AppTypography.progress,
          ),
        ],
      ),
    ),
  );

  Widget _reviewValue(String label, String value, {bool prominent = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.helper.copyWith(color: _muted)),
            const SizedBox(height: 4),
            Text(
              value,
              style:
                  (prominent
                          ? AppTypography.screenHeader
                          : AppTypography.fieldLabel)
                      .copyWith(color: ProductFormStyle.navy, height: 1.45),
            ),
          ],
        ),
      );

  Widget _reviewGroup(
    String title,
    int step,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
            );
            final edit = TextButton(
              key: ValueKey('review-edit-$step'),
              onPressed: _busy ? null : () => _changeStep(step),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                textStyle: AppTypography.fieldLabel,
              ),
              child: Semantics(label: 'Edit $title', child: const Text('Edit')),
            );
            if (constraints.maxWidth <
                280 * MediaQuery.textScalerOf(context).scale(1)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: AlignmentDirectional.topEnd, child: edit),
                  heading,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                edit,
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    ),
  );

  Widget _reviewDetails(List<Widget> details) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >=
              300 * MediaQuery.textScalerOf(context).scale(1)
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final detail in details) SizedBox(width: width, child: detail),
        ],
      );
    },
  );

  Widget _reviewNotice({
    required String title,
    required String message,
    required IconData icon,
    required Color background,
    bool fullWidthBody = false,
    Key? key,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: fullWidthBody
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: ProductFormStyle.navy),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: AppTypography.cardTitle)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTypography.helper.copyWith(color: _muted),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: ProductFormStyle.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: AppTypography.helper.copyWith(
                        color: ProductFormStyle.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );

  Widget _review() {
    final total = _inventoryMethod == 'fifo'
        ? _batchTotal
        : int.tryParse(_quantity.text.trim()) ?? 0;
    final threshold = int.tryParse(_lowStockThreshold.text.trim());
    final tags = ProductTagInput.values(_tags);
    final images = _orderedImages;
    return _section('Review & Submit', [
      Text(
        'Review your product details before submitting for approval.',
        style: AppTypography.helper.copyWith(color: _muted),
      ),
      const SizedBox(height: 12),
      _reviewGroup('Product Information', 0, [
        _reviewValue('Product Name', _name.text.trim()),
        _reviewValue('Category', _category ?? ''),
        _reviewValue('Description', _description.text.trim()),
        if (tags.isNotEmpty) ...[
          Text('Tags', style: AppTypography.helper.copyWith(color: _muted)),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Tooltip(
                      message: tag,
                      child: Chip(
                        key: ValueKey('review-tag-$tag'),
                        label: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        labelStyle: AppTypography.helper.copyWith(
                          color: ProductFormStyle.navy,
                        ),
                        backgroundColor: ProductFormStyle.selectedSurface,
                        side: const BorderSide(color: _line),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ]),
      _reviewGroup('Pricing & Inventory', 1, [
        _reviewValue(
          'Selling Price',
          '₱${double.tryParse(_price.text.trim())?.toStringAsFixed(2) ?? _price.text.trim()}',
          prominent: true,
        ),
        _reviewDetails([
          _reviewValue(
            'Stock Method',
            _inventoryMethod == 'fifo' ? 'Batch Tracking' : 'Standard Stock',
          ),
          _reviewValue('Total Available Stock', '$total units'),
          _reviewValue('Low Stock Threshold', _lowStockThreshold.text.trim()),
          if (_inventoryMethod == 'fifo')
            _reviewValue('Number of Batches', '${_batches.length}'),
          if (_inventoryMethod == 'simple' && _perishable && _expiry != null)
            _reviewValue('Expiry Date', ProductExpiryField.format(_expiry!)),
        ]),
        if (_inventoryMethod == 'fifo')
          ExpansionTile(
            key: const ValueKey('review-batches'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Batch details', style: AppTypography.fieldLabel),
            children: [
              for (var i = 0; i < _batches.length; i++)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _reviewValue(
                    'Batch ${i + 1}',
                    '${_batches[i].quantity.text.trim()} units · ${_batches[i].receivedAt == null ? 'Date not selected' : ProductExpiryField.format(_batches[i].receivedAt!)}'
                        '${_batches[i].unitCost.text.trim().isEmpty ? '' : ' · Unit cost ₱${_batches[i].unitCost.text.trim()}'}'
                        '${!_perishable || _batches[i].expiryDate == null ? '' : ' · Expiry ${ProductExpiryField.format(_batches[i].expiryDate!)}'}',
                  ),
                ),
            ],
          ),
        if (threshold != null && total <= threshold) ...[
          const SizedBox(height: 4),
          _reviewNotice(
            key: const ValueKey('review-low-stock-notice'),
            title: 'Low Stock Notice',
            message:
                'Your available stock is already at or below your low-stock alert level.',
            icon: Icons.warning_amber_rounded,
            background: ProductFormStyle.gold.withValues(alpha: .12),
          ),
        ],
      ]),
      _reviewGroup('Uploaded Photos', 2, [
        Text(
          '${images.length} of 6 images',
          style: AppTypography.helper.copyWith(color: _muted),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >=
                    280 * MediaQuery.textScalerOf(context).scale(1)
                ? 3
                : 2;
            final size = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < images.length; i++)
                  Semantics(
                    key: ValueKey('review-photo-card-$i'),
                    image: true,
                    label: i == 0
                        ? 'Cover product image'
                        : 'Product image ${i + 1}',
                    child: ExcludeSemantics(
                      child: Container(
                        width: size,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ColoredBox(
                                  color: ProductFormStyle.selectedSurface,
                                  child: ProductImage(
                                    key: ValueKey('review-product-image-$i'),
                                    imageUrl: images[i],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 8,
                              ),
                              child: Text(
                                i == 0 ? 'Cover' : 'Photo ${i + 1}',
                                textAlign: TextAlign.center,
                                style: AppTypography.helper.copyWith(
                                  color: _muted,
                                  fontWeight: i == 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ]),
      _reviewNotice(
        key: const ValueKey('review-product-approval'),
        title: 'Product Approval',
        message:
            "Your product will be reviewed by the Administrator before it appears in the marketplace. You'll be notified once the review is complete.",
        icon: Icons.verified_user_outlined,
        background: ProductFormStyle.selectedSurface,
        fullWidthBody: true,
      ),
    ]);
  }

  Widget _navigation(bool categoriesAvailable) {
    final primary = SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: ValueKey(_step == 3 ? 'submit-product' : 'continue-product'),
        onPressed:
            _busy || !categoriesAvailable || (_step == 2 && _imageCount == 0)
            ? null
            : (_step == 3 ? _submit : _continue),
        style: FilledButton.styleFrom(
          backgroundColor: ProductFormStyle.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _step == 3
              ? AppTypography.button.copyWith(fontSize: 15)
              : AppTypography.button,
        ),
        child: _submitting
            ? Semantics(
                label: 'Submitting product for approval',
                child: const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(
                _step == 3 ? 'Submit for Approval' : 'Next',
                textAlign: TextAlign.center,
              ),
      ),
    );
    return primary;
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.placeholder.copyWith(color: _muted),
    helperStyle: AppTypography.helper.copyWith(color: _muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(width: 1.8, color: ProductFormStyle.navy),
    ),
    errorStyle: AppTypography.error.copyWith(color: ProductFormStyle.error),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ProductFormStyle.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ProductFormStyle.error, width: 1.8),
    ),
    errorMaxLines: 3,
  );

  Widget _label(String label, Widget field, {Widget? labelAction}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelAction == null)
          ProductFieldLabel(label)
        else
          Row(
            children: [
              Flexible(child: ProductFieldLabel(label)),
              const SizedBox(width: 4),
              labelAction,
            ],
          ),
        const SizedBox(height: 8),
        Semantics(label: label, child: field),
      ],
    ),
  );
  Widget _section(String title, List<Widget> children, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (trailing == null)
                Text(title, style: AppTypography.sectionTitle)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(title, style: AppTypography.sectionTitle),
                    ),
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  void _removeImage(int index) {
    if (_busy || _selectedImages[index] == null) return;
    setState(() {
      final remaining = [
        for (var i = 0; i < _maxImages; i++)
          if (i != index && _selectedImages[i] != null) i,
      ];
      final cover = _primaryImage == index
          ? (remaining.isEmpty ? null : remaining.first)
          : _primaryImage;
      final images = [for (final i in remaining) _selectedImages[i]];
      final coverIndex = remaining.indexOf(cover ?? -1);
      _selectedImages.setAll(0, [
        ...images,
        ...List<String?>.filled(_maxImages - images.length, null),
      ]);
      _primaryImage = coverIndex < 0 ? null : coverIndex;
      _imageError = images.isEmpty
          ? 'Please add at least one product photo.'
          : null;
    });
  }

  Future<void> _showImageActions(int index) async {
    if (_busy || _selectedImages[index] == null) return;
    final action = await showModalBottomSheet<String>(
      context: _form.currentContext!,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageCount > 1 && _primaryImage != index)
              ListTile(
                key: ValueKey('primary-product-image-$index'),
                leading: const Icon(
                  LucideIcons.image,
                  color: ProductFormStyle.navy,
                ),
                title: const Text(
                  'Set as Cover',
                  style: AppTypography.fieldLabel,
                ),
                onTap: () => Navigator.of(context).pop('cover'),
              ),
            ListTile(
              leading: const Icon(
                LucideIcons.imagePlus,
                color: ProductFormStyle.navy,
              ),
              title: const Text(
                'Replace photo',
                style: AppTypography.fieldLabel,
              ),
              onTap: () => Navigator.of(context).pop('replace'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || _busy) return;
    if (action == 'cover') {
      setState(() => _primaryImage = index);
    } else if (action == 'replace') {
      await _pickImages(slot: index);
    }
  }

  Widget _imageSlot(int index, double size) {
    final image = _selectedImages[index]!;
    // Keep the remove target clear of the photo's center in compact 3-column grids.
    final removeTarget = size < ProductFormStyle.target * 2
        ? 32.0
        : ProductFormStyle.target;
    return SizedBox.square(
      key: ValueKey('product-image-slot-$index'),
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _primaryImage == index ? ProductFormStyle.navy : _line,
                  width: _primaryImage == index ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: _busy ? null : () => _showImageActions(index),
                child: Semantics(
                  button: true,
                  label:
                      'Photo ${index + 1}${_primaryImage == index ? ', Cover' : ''}. Open photo options',
                  child: ProductImage(
                    key: ValueKey('product-image-preview-$index'),
                    imageUrl: image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: ValueKey('remove-product-image-$index'),
              tooltip: 'Remove image ${index + 1}',
              constraints: BoxConstraints.tightFor(
                width: removeTarget,
                height: removeTarget,
              ),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _busy ? null : () => _removeImage(index),
              icon: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _line),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: ProductFormStyle.navy,
                ),
              ),
            ),
          ),
          if (_primaryImage == index)
            Positioned(
              left: 6,
              bottom: 6,
              child: IgnorePointer(
                child: Container(
                  key: ValueKey('product-cover-$index'),
                  constraints: BoxConstraints(maxWidth: size - 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _line),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cover',
                      maxLines: 1,
                      style: AppTypography.helper.copyWith(
                        color: ProductFormStyle.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _images() => _section(
    'Upload Images',
    [
      Text(
        'Add at least one clear photo of your product.',
        style: AppTypography.helper.copyWith(color: _muted),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          key: const ValueKey('add-product-image'),
          onPressed: _busy || _imageCount == _maxImages ? null : _pickImages,
          style: OutlinedButton.styleFrom(
            textStyle: AppTypography.cardTitle,
            padding: const EdgeInsets.all(20),
            minimumSize: const Size(0, 112),
            backgroundColor: Colors.white,
            side: const BorderSide(color: _line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ProductFormStyle.radius),
            ),
          ),
          child: Column(
            children: [
              const SizedBox.square(
                key: ValueKey('product-upload-arrow'),
                dimension: 58,
                child: ColoredBox(
                  color: ProductFormStyle.navy,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: Colors.white),
                      child: ProductUploadIcon(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _picking ? 'Opening photos…' : 'Add product photos',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to choose photos from your gallery.',
                textAlign: TextAlign.center,
                style: AppTypography.helper.copyWith(color: _muted),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'JPEG, PNG, WebP, GIF \u2022 Max 6 photos \u2022 5 MB each',
        style: AppTypography.helper.copyWith(color: _muted),
      ),
      if (_imageCount > 0) ...[
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('uploaded-photos-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(ProductFormStyle.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Uploaded Photos', style: AppTypography.cardTitle),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = (constraints.maxWidth - 2 * 8) / 3;
                  return Wrap(
                    key: const ValueKey('product-image-grid'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _maxImages; i++)
                        if (_selectedImages[i] != null) _imageSlot(i, size),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
      if (_imageError != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            _imageError!,
            key: const ValueKey('product-image-error'),
            style: AppTypography.error.copyWith(color: ProductFormStyle.error),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ],
    trailing: Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: '$_imageCount of $_maxImages product photos selected',
      child: Text(
        '$_imageCount of $_maxImages',
        key: const ValueKey('product-image-counter'),
        style: AppTypography.helper.copyWith(color: ProductFormStyle.navy),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_submittedProduct != null) {
      return _submissionConfirmation(_submittedProduct!);
    }
    final original = Theme.of(context);
    final categories = widget.categories
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
    return Theme(
      data: AppTypography.theme(
        original.copyWith(
          scaffoldBackgroundColor: Colors.white,
          iconTheme: original.iconTheme.copyWith(
            color: ProductFormStyle.muted,
            opacity: 1,
          ),
          unselectedWidgetColor: ProductFormStyle.muted,
          textTheme: original.textTheme.apply(
            fontFamily: AppTypography.family,
            bodyColor: ProductFormStyle.navy,
            displayColor: ProductFormStyle.navy,
          ),
          colorScheme: original.colorScheme.copyWith(
            brightness: Brightness.light,
            primary: ProductFormStyle.navy,
            onPrimary: Colors.white,
            secondary: ProductFormStyle.gold,
            surface: Colors.white,
            onSurface: ProductFormStyle.navy,
            onSurfaceVariant: ProductFormStyle.muted,
            outline: ProductFormStyle.muted,
            outlineVariant: ProductFormStyle.border,
            error: ProductFormStyle.error,
            onError: Colors.white,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: ProductFormStyle.navy,
          ),
        ),
      ),
      child: PopScope(
        canPop: !_busy && _step == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_busy && _step > 0) _back();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: ProductFormStyle.navy,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Add Product',
              style: AppTypography.screenHeader.copyWith(
                color: ProductFormStyle.navy,
              ),
            ),
            leading: BackButton(onPressed: _busy ? null : _back),
          ),
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _form,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scroll,
                          key: const ValueKey('add-product-scroll'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _progress(),
                              if (_step == 0)
                                _section('Product Information', [
                                  _label(
                                    'Product Name *',
                                    TextFormField(
                                      key: const ValueKey('product-name'),
                                      controller: _name,
                                      enabled: !_busy,
                                      maxLength: 150,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.next,
                                      decoration: _decoration(
                                        'Enter product name',
                                      ),
                                      validator: (value) =>
                                          _required(value, 'Product name'),
                                    ),
                                  ),
                                  _label(
                                    'Category *',
                                    _categoryField(categories),
                                  ),
                                  if (categories.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: Text(
                                        'No categories are available. Go back and reopen Add Product to retry.',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  _label(
                                    'Description *',
                                    TextFormField(
                                      key: const ValueKey(
                                        'product-description',
                                      ),
                                      controller: _description,
                                      enabled: !_busy,
                                      minLines: 3,
                                      maxLines: 5,
                                      keyboardType: TextInputType.multiline,
                                      decoration: _decoration(
                                        'Describe your product and relevant details',
                                      ),
                                      validator: (value) =>
                                          _required(value, 'Description'),
                                    ),
                                  ),
                                  _label(
                                    'Tags (Optional)',
                                    ProductTagInput(
                                      tags: _tags,
                                      entry: _tagEntry,
                                      enabled: !_busy,
                                      decoration: _decoration(
                                        'e.g. homemade, snacks',
                                      ),
                                    ),
                                    labelAction: const ProductTagsHelp(),
                                  ),
                                ]),
                              if (_step == 1)
                                _section('Pricing & Inventory', [
                                  _label(
                                    'Selling Price (₱) *',
                                    TextFormField(
                                      key: const ValueKey('product-price'),
                                      controller: _price,
                                      enabled: !_busy,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.next,
                                      decoration: _decoration('0.00').copyWith(
                                        prefixText: '₱ ',
                                        prefixStyle: AppTypography.input
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: ProductFormStyle.navy,
                                            ),
                                      ),
                                      validator: _validatePrice,
                                    ),
                                  ),
                                  _label(
                                    'Stock Method',
                                    ProductInventorySelector(
                                      key: const ValueKey(
                                        'product-inventory-method',
                                      ),
                                      value: _inventoryMethod,
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(() {
                                              _inventoryMethod = value;
                                              _submitError = null;
                                            }),
                                    ),
                                  ),
                                  if (_inventoryMethod == 'simple')
                                    _label(
                                      'Available Stock *',
                                      TextFormField(
                                        key: const ValueKey('product-quantity'),
                                        controller: _quantity,
                                        enabled: !_busy,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        decoration: _decoration(
                                          'Enter available stock',
                                        ),
                                        validator: _validateStock,
                                      ),
                                    )
                                  else ...[
                                    for (var i = 0; i < _batches.length; i++)
                                      ProductBatchFields(
                                        key: ObjectKey(_batches[i]),
                                        draft: _batches[i],
                                        showExpiry: _perishable,
                                        number: i + 1,
                                        decoration: _decoration,
                                        enabled: !_busy,
                                        onChanged: () => setState(() {}),
                                        onRemove: () => setState(() {
                                          _removedBatches.add(
                                            _batches.removeAt(i),
                                          );
                                        }),
                                      ),
                                    OutlinedButton.icon(
                                      key: const ValueKey('add-product-batch'),
                                      onPressed: _busy || _batches.length >= 100
                                          ? null
                                          : () => setState(
                                              () => _batches.add(
                                                ProductBatchDraft(),
                                              ),
                                            ),
                                      icon: const Icon(
                                        LucideIcons.plus,
                                        size: 18,
                                      ),
                                      label: const Text('Add Another Batch'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(
                                          double.infinity,
                                          48,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          'Total Available Stock: $_batchTotal units',
                                          key: const ValueKey('batch-total'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_batches.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: Text(
                                          'Add at least one batch before previewing or submitting.',
                                        ),
                                      ),
                                  ],
                                  _label(
                                    'Low Stock Threshold *',
                                    TextFormField(
                                      key: const ValueKey(
                                        'product-low-stock-threshold',
                                      ),
                                      controller: _lowStockThreshold,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      decoration:
                                          _decoration(
                                            'Enter low stock threshold(e.g. 5)',
                                          ).copyWith(
                                            helperText:
                                                'Get an alert when stock reaches this quantity or lower.',
                                            helperMaxLines: 4,
                                          ),
                                      validator: _validateLowStockThreshold,
                                    ),
                                    labelAction: const ProductInventoryInfo(
                                      id: 'low-stock-threshold-info',
                                      contentKey:
                                          'low-stock-threshold-tooltip-content',
                                      title: 'Low Stock Threshold',
                                      message: ProductInventoryInfo
                                          .lowStockExplanation,
                                    ),
                                  ),
                                  if (_perishable &&
                                      _inventoryMethod == 'simple')
                                    ProductExpiryField(
                                      id: 'product-expiry',
                                      value: _expiry,
                                      enabled: !_busy,
                                      decoration: _decoration,
                                      onChanged: (value) =>
                                          setState(() => _expiry = value),
                                    ),
                                ]),
                              if (_step == 2) _images(),
                              if (_step == 3) _review(),
                              if (_submitError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _submitError!,
                                      key: const ValueKey(
                                        'product-submit-error',
                                      ),
                                      style: AppTypography.error.copyWith(
                                        color: ProductFormStyle.error,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        key: const ValueKey('product-form-navigation'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _navigation(categories.isNotEmpty),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
