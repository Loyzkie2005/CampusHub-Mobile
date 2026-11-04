import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';

import 'product_inventory_fields.dart';

/// One optional date control shared by simple stock and individual batch drafts.
class ProductExpiryField extends StatelessWidget {
  const ProductExpiryField({
    super.key,
    required this.id,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
  });

  final String id;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final InputDecoration Function(String) decoration;
  final bool enabled;

  static const explanation =
      'Select an expiry date if your product has one. Leave this field blank if your product has no specified expiry date.';

  static String format(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ProductFormStyle.gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Flexible(child: ProductFieldLabel('Expiry Date (Optional)')),
            const SizedBox(width: 4),
            _ExpiryHelp(id: id),
          ],
        ),
        const SizedBox(height: 8),
        FormField<DateTime>(
          initialValue: value,
          validator: (_) => ProductFormStyle.expiryDate(value),
          builder: (state) {
            Future<void> choose() async {
              if (!enabled) return;
              FocusScope.of(context).unfocus();
              Tooltip.dismissAllToolTips();
              final today = DateUtils.dateOnly(DateTime.now());
              final selected = value == null
                  ? today
                  : DateUtils.dateOnly(value!);
              final picked = await showDatePicker(
                context: context,
                initialDate: selected.isBefore(today) ? today : selected,
                firstDate: today,
                lastDate: DateTime(
                  math.max(today.year + 100, selected.year),
                  12,
                  31,
                ),
                cancelText: 'Cancel',
                confirmText: 'OK',
                barrierColor: Colors.black54,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    datePickerTheme: Theme.of(context).datePickerTheme.copyWith(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked == null || !context.mounted) return;
              state.didChange(picked);
              onChanged(picked);
            }

            return InkWell(
              key: ValueKey(id),
              onTap: enabled ? choose : null,
              borderRadius: BorderRadius.circular(ProductFormStyle.radius),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: 'Expiry Date (Optional)',
                child: InputDecorator(
                  decoration: decoration('Select expiry date').copyWith(
                    hintText: '',
                    enabled: enabled,
                    errorText: state.errorText,
                    helperText: 'Leave blank if not applicable.',
                    helperMaxLines: 3,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value != null)
                          IconButton(
                            key: ValueKey('$id-clear'),
                            tooltip: 'Clear expiry date',
                            onPressed: !enabled
                                ? null
                                : () {
                                    state.didChange(null);
                                    onChanged(null);
                                  },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        IconButton(
                          key: ValueKey('$id-calendar'),
                          tooltip: 'Select expiry date',
                          onPressed: enabled ? choose : null,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Text(
                    value == null ? 'Select expiry date' : format(value!),
                    style: AppTypography.input.copyWith(
                      color: value == null
                          ? ProductFormStyle.muted
                          : ProductFormStyle.navy,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _ExpiryHelp extends StatefulWidget {
  const _ExpiryHelp({required this.id});
  final String id;

  @override
  State<_ExpiryHelp> createState() => _ExpiryHelpState();
}

class _ExpiryHelpState extends State<_ExpiryHelp> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltip,
    message: ProductExpiryField.explanation,
    triggerMode: TooltipTriggerMode.longPress,
    showDuration: const Duration(seconds: 12),
    constraints: BoxConstraints(
      maxWidth: math.min(320, MediaQuery.sizeOf(context).width - 32),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ProductFormStyle.navy,
      borderRadius: BorderRadius.circular(ProductFormStyle.radius),
    ),
    textStyle: AppTypography.tooltip.copyWith(color: Colors.white),
    child: Semantics(
      label: 'About expiry date',
      button: true,
      child: IconButton(
        key: ValueKey('${widget.id}-info'),
        padding: EdgeInsets.zero,
        alignment: AlignmentDirectional.centerStart,
        constraints: const BoxConstraints(
          minWidth: ProductFormStyle.target,
          minHeight: ProductFormStyle.target,
        ),
        onPressed: () => _tooltip.currentState?.ensureTooltipVisible(),
        icon: const Icon(
          Icons.info_outline,
          size: 16,
          color: ProductFormStyle.navy,
        ),
      ),
    ),
  );
}
