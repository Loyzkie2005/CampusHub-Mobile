import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'product_inventory_fields.dart';

/// Keeps the existing comma-separated API value while rendering removable tags.
class ProductTagInput extends StatefulWidget {
  static const instructions =
      'Type a tag and press Enter or comma to add it. Tap × to remove a tag.';
  const ProductTagInput({
    super.key,
    required this.tags,
    required this.entry,
    required this.decoration,
    this.enabled = true,
  });

  final TextEditingController tags;
  final TextEditingController entry;
  final InputDecoration decoration;
  final bool enabled;

  static List<String> values(TextEditingController tags) => tags.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  static void _add(TextEditingController tags, Iterable<String> additions) {
    final items = {
      ...values(tags),
      ...additions
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    };
    tags.text = items.join(', ');
  }

  /// Next also commits unfinished text so a seller cannot accidentally lose it.
  static void commit(TextEditingController tags, TextEditingController entry) {
    _add(tags, entry.text.split(RegExp(r'[,\n]')));
    entry.clear();
  }

  @override
  State<ProductTagInput> createState() => _ProductTagInputState();
}

class _ProductTagInputState extends State<ProductTagInput> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.tags.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ProductTagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tags != widget.tags) {
      oldWidget.tags.removeListener(_refresh);
      widget.tags.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.tags.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final pieces = text.split(RegExp(r'[,\n]'));
    if (pieces.length == 1) {
      _refresh();
      return;
    }
    final remainder = pieces.removeLast().trimLeft();
    ProductTagInput._add(widget.tags, pieces);
    widget.entry.value = TextEditingValue(
      text: remainder,
      selection: TextSelection.collapsed(offset: remainder.length),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.enabled ? _focus.requestFocus : null,
    child: InputDecorator(
      key: const ValueKey('product-tags-container'),
      isFocused: _focus.hasFocus,
      isEmpty:
          ProductTagInput.values(widget.tags).isEmpty &&
          widget.entry.text.isEmpty,
      decoration: widget.decoration.copyWith(
        hintText: '',
        enabled: widget.enabled,
        isDense: true,
        constraints: const BoxConstraints(minHeight: 54),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in ProductTagInput.values(widget.tags))
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: InputChip(
                      key: ValueKey('product-tag-$tag'),
                      label: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      tooltip: tag,
                      isEnabled: widget.enabled,
                      onDeleted: !widget.enabled
                          ? null
                          : () {
                              widget.tags.text = ProductTagInput.values(
                                widget.tags,
                              ).where((value) => value != tag).join(', ');
                            },
                      deleteIcon: const Icon(LucideIcons.x, size: 16),
                      deleteButtonTooltipMessage: 'Remove tag $tag',
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: ProductFormStyle.border),
                      labelStyle: AppTypography.helper.copyWith(
                        color: ProductFormStyle.navy,
                      ),
                      deleteIconColor: ProductFormStyle.navy,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
                SizedBox(
                  width: ProductTagInput.values(widget.tags).isEmpty
                      ? constraints.maxWidth
                      : math.min(
                          160 * MediaQuery.textScalerOf(context).scale(1),
                          constraints.maxWidth,
                        ),
                  child: TextFormField(
                    key: const ValueKey('product-tags'),
                    focusNode: _focus,
                    controller: widget.entry,
                    style: AppTypography.input,
                    enabled: widget.enabled,
                    textInputAction: TextInputAction.done,
                    onChanged: _changed,
                    onEditingComplete: () {},
                    onFieldSubmitted: (_) =>
                        ProductTagInput.commit(widget.tags, widget.entry),
                    decoration: InputDecoration(
                      hintText: ProductTagInput.values(widget.tags).isEmpty
                          ? 'e.g. homemade, snacks'
                          : 'Add a tag',
                      hintStyle: AppTypography.placeholder.copyWith(
                        color: ProductFormStyle.muted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProductTagsHelp extends StatefulWidget {
  const ProductTagsHelp({super.key});

  @override
  State<ProductTagsHelp> createState() => _ProductTagsHelpState();
}

class _ProductTagsHelpState extends State<ProductTagsHelp> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltip,
    message: ProductTagInput.instructions,
    triggerMode: TooltipTriggerMode.longPress,
    showDuration: const Duration(seconds: 12),
    constraints: BoxConstraints(
      maxWidth: math.min(320, MediaQuery.sizeOf(context).width - 32),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ProductFormStyle.navy,
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: AppTypography.tooltip.copyWith(color: Colors.white),
    child: Semantics(
      label: 'How to add and remove tags',
      button: true,
      child: IconButton(
        key: const ValueKey('product-tags-info'),
        padding: EdgeInsets.zero,
        alignment: AlignmentDirectional.centerStart,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => _tooltip.currentState?.ensureTooltipVisible(),
        icon: const Icon(
          key: ValueKey('product-tags-info-glyph'),
          LucideIcons.info,
          size: 16,
          color: ProductFormStyle.navy,
        ),
      ),
    ),
  );
}
