import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'product_expiry_field.dart';

/// Scoped to Add Product; other CampusHub screens keep their current theme.
abstract class ProductFormStyle {
  static const navy = Color(0xFF0B1F3A);
  static const gold = Color(0xFFFCB316);
  static const border = Color(0xFFE8EAF0);
  static const selectedSurface = Color(0xFFF7F8FC);
  static const muted = Color(0xFF667085);
  static const error = Color(0xFFB91C1C);
  static const radius = 12.0;
  static const gap = 16.0;
  static const target = 48.0;
  static const maxQuantity = 2147483647;

  static String? quantity(String? value, {bool positive = false}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return positive
          ? 'Batch quantity is required.'
          : 'Stock quantity is required.';
    }
    final amount = int.tryParse(raw);
    if (!RegExp(r'^\d+$').hasMatch(raw) ||
        amount == null ||
        amount < (positive ? 1 : 0) ||
        amount > maxQuantity) {
      return positive
          ? 'Enter a whole-number batch quantity greater than 0.'
          : 'Please enter a valid stock quantity.';
    }
    return null;
  }

  static String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String? unitCost(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(raw)
        ? null
        : 'Enter a unit cost of 0 or more, up to 2 decimal places.';
  }

  static String? receivedDate(DateTime? value) {
    if (value == null) return 'Date received is required.';
    if (value.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return 'Date received cannot be in the future.';
    }
    return null;
  }

  static String? expiryDate(DateTime? value) =>
      value != null &&
          DateUtils.dateOnly(value).isBefore(DateUtils.dateOnly(DateTime.now()))
      ? 'Select today or a future expiry date, or clear this field.'
      : null;
}

/// Required markers share the same semantic error color as field validation.
class ProductFieldLabel extends StatelessWidget {
  const ProductFieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: label.endsWith(' *')
              ? label.substring(0, label.length - 1)
              : label,
        ),
        if (label.endsWith(' *'))
          TextSpan(
            text: '*',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    style: AppTypography.fieldLabel,
  );
}

/// Controllers belong to the form, so hiding a method never clears its draft.
class ProductBatchDraft {
  final quantity = TextEditingController();
  final unitCost = TextEditingController();
  DateTime? receivedAt;
  DateTime? expiryDate;

  Map<String, dynamic> toJson({bool includeExpiry = false}) => {
    'quantity': int.parse(quantity.text.trim()),
    'received_date': ProductFormStyle.date(receivedAt!),
    if (unitCost.text.trim().isNotEmpty) 'unit_cost': unitCost.text.trim(),
    if (includeExpiry && expiryDate != null)
      'expiry_date': ProductFormStyle.date(expiryDate!),
  };

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class ProductInventoryInfo extends StatefulWidget {
  const ProductInventoryInfo({
    super.key,
    this.id = 'batch-inventory-info',
    this.contentKey = 'batch-tooltip-content',
    this.title = 'Batch Tracking',
    this.message = explanation,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String id, contentKey, title, message;
  final AlignmentGeometry alignment;

  static const explanation =
      'Keep track of your stock each time you add new items. Older stock is sold first.';
  static const standardExplanation =
      'Enter the total number of items you have available.';
  static const lowStockExplanation =
      'Set when you want to receive a low-stock alert. For example, enter 5 to get notified when 5 or fewer items remain.';

  @override
  State<ProductInventoryInfo> createState() => _ProductInventoryInfoState();
}

class _ProductInventoryInfoState extends State<ProductInventoryInfo> {
  final _tooltip = GlobalKey<TooltipState>();
  final _tapRegion = Object();

  @override
  Widget build(BuildContext context) => MediaQuery(
    // WidgetSpan scales its whole child. Keep its outer scale neutral and
    // apply the user's scale once to the explanation text itself.
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: Tooltip(
      key: _tooltip,
      excludeFromSemantics: true,
      richMessage: WidgetSpan(
        child: TapRegion(
          groupId: _tapRegion,
          onTapOutside: (_) => Tooltip.dismissAllToolTips(),
          child: SizedBox(
            width: math.min(288, MediaQuery.sizeOf(context).width - 80),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(
                  320,
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom) *
                      .45,
                ),
              ),
              child: SingleChildScrollView(
                key: ValueKey(widget.contentKey),
                child: Text(
                  widget.message,
                  textScaler: MediaQuery.textScalerOf(context),
                  style: AppTypography.tooltip.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 12),
      waitDuration: const Duration(milliseconds: 400),
      // Native tap-to-dismiss also dismisses on a scroll inside the explanation.
      // Grouped tap regions keep reading/scrolling open and dismiss only outside.
      enableTapToDismiss: false,
      constraints: BoxConstraints(
        maxWidth: math.min(320, MediaQuery.sizeOf(context).width - 48),
      ),
      padding: const EdgeInsets.all(ProductFormStyle.gap),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: AppTypography.tooltip.copyWith(color: Colors.white),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(ProductFormStyle.radius),
      ),
      child: TapRegion(
        groupId: _tapRegion,
        onTapOutside: (_) => Tooltip.dismissAllToolTips(),
        child: Semantics(
          label: 'About ${widget.title}. ${widget.message}',
          button: true,
          child: IconButton(
            key: ValueKey(widget.id),
            onPressed: () => _tooltip.currentState?.ensureTooltipVisible(),
            padding: EdgeInsets.zero,
            alignment: widget.alignment,
            constraints: const BoxConstraints(
              minWidth: ProductFormStyle.target,
              minHeight: ProductFormStyle.target,
            ),
            icon: const Icon(Icons.info_outline, size: 18),
          ),
        ),
      ),
    ),
  );
}

class ProductInventorySelector extends StatelessWidget {
  const ProductInventorySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: value,
      onChanged: (value) {
        if (value != null) onChanged?.call(value);
      },
      child: Column(
        children: [
          for (final method in ['simple', 'fifo']) ...[
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ProductFormStyle.radius),
                side: BorderSide(
                  color: value == method
                      ? ProductFormStyle.navy
                      : ProductFormStyle.border,
                  width: value == method ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                key: ValueKey('inventory-$method'),
                onTap: onChanged == null ? null : () => onChanged!(method),
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(ProductFormStyle.radius),
                child: Padding(
                  padding: const EdgeInsets.all(ProductFormStyle.gap),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Semantics(
                        label: method == 'simple'
                            ? 'Standard Stock. Enter the number of items available for sale.'
                            : 'Batch Tracking. Organize your items based on when you restock them.',
                        child: Radio<String>(
                          value: method,
                          activeColor: ProductFormStyle.navy,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          visualDensity: VisualDensity.standard,
                          enabled: onChanged != null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                method == 'simple'
                                    ? 'Standard Stock'
                                    : 'Batch Tracking',
                                style: AppTypography.cardTitle,
                              ),
                            ),
                            ExcludeSemantics(
                              child: Text(
                                method == 'simple'
                                    ? 'Enter the number of items available for sale.'
                                    : 'Organize your items based on when you restock them.',
                                style: AppTypography.helper.copyWith(
                                  color: ProductFormStyle.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      method == 'fifo'
                          ? const ProductInventoryInfo(
                              alignment: AlignmentDirectional.centerEnd,
                            )
                          : const ProductInventoryInfo(
                              alignment: AlignmentDirectional.centerEnd,
                              id: 'standard-stock-info',
                              contentKey: 'standard-stock-tooltip-content',
                              title: 'Standard Stock',
                              message: ProductInventoryInfo.standardExplanation,
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class ProductBatchFields extends StatelessWidget {
  const ProductBatchFields({
    super.key,
    required this.draft,
    required this.number,
    required this.decoration,
    required this.onChanged,
    this.onRemove,
    this.enabled = true,
    this.showExpiry = false,
  });

  final ProductBatchDraft draft;
  final int number;
  final InputDecoration Function(String) decoration;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool enabled;
  final bool showExpiry;

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: ProductFormStyle.gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductFieldLabel(label),
        const SizedBox(height: 8),
        Semantics(label: label, child: child),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      border: Border.all(color: ProductFormStyle.border),
      borderRadius: BorderRadius.circular(ProductFormStyle.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Batch $number', style: AppTypography.cardTitle),
            ),
            IconButton(
              key: ValueKey('remove-batch-$number'),
              tooltip: 'Remove Batch $number',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(LucideIcons.trash2, size: 18),
            ),
          ],
        ),
        _field(
          'Batch Quantity *',
          TextFormField(
            key: ValueKey('batch-quantity-$number'),
            controller: draft.quantity,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: decoration('Enter batch quantity'),
            validator: (value) =>
                ProductFormStyle.quantity(value, positive: true),
            onChanged: (_) => onChanged(),
          ),
        ),
        _field(
          'Date Received *',
          FormField<DateTime>(
            initialValue: draft.receivedAt,
            validator: (_) => ProductFormStyle.receivedDate(draft.receivedAt),
            builder: (state) => InkWell(
              key: ValueKey('batch-date-$number'),
              borderRadius: BorderRadius.circular(ProductFormStyle.radius),
              onTap: !enabled
                  ? null
                  : () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final date = await showDatePicker(
                        context: context,
                        initialDate: draft.receivedAt ?? today,
                        firstDate: DateTime(1900),
                        lastDate: today,
                      );
                      if (date == null || !context.mounted) return;
                      draft.receivedAt = date;
                      state.didChange(date);
                      onChanged();
                    },
              child: Semantics(
                button: true,
                child: InputDecorator(
                  decoration: decoration('Select date').copyWith(
                    enabled: enabled,
                    errorText: state.errorText,
                    suffixIcon: const Icon(LucideIcons.calendarDays, size: 18),
                  ),
                  child: Text(
                    draft.receivedAt == null
                        ? 'Select date'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(draft.receivedAt!),
                    style: AppTypography.input,
                  ),
                ),
              ),
            ),
          ),
        ),
        _field(
          'Unit Cost (Optional)',
          TextFormField(
            key: ValueKey('batch-cost-$number'),
            controller: draft.unitCost,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoration('0.00').copyWith(
              prefixText: '₱ ',
              helperText: 'Saved in this batch’s receipt notes.',
              helperMaxLines: 4,
            ),
            validator: ProductFormStyle.unitCost,
          ),
        ),
        if (showExpiry)
          ProductExpiryField(
            id: 'batch-expiry-$number',
            value: draft.expiryDate,
            enabled: enabled,
            decoration: decoration,
            onChanged: (value) {
              draft.expiryDate = value;
              onChanged();
            },
          ),
      ],
    ),
  );
}
