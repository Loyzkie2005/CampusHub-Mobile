import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'booking_widgets.dart';

// Matches the existing Django whole_number and mobile fee-field limit.
const chairQuantityLimit = 100000;

TextStyle _sheetText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = bookingNavy,
}) => TextStyle(
  fontFamily: 'Montserrat',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  height: 1.45,
);

/// Saved pricing accepts non-negative amounts with at most two decimal places.
/// Keep the estimate in integer centavos; never submit a client-calculated price.
int? chairUnitCentavos(dynamic value) {
  final amount = num.tryParse('$value');
  if (amount == null ||
      !amount.isFinite ||
      amount < 0 ||
      amount > 99999999.99) {
    return null;
  }
  final fixed = amount.toStringAsFixed(2);
  if (num.tryParse(fixed) != amount) return null;
  return int.tryParse(fixed.replaceAll('.', ''));
}

String chairMoney(int centavos) =>
    '\u20b1${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

Future<int?> showChairsQuantitySheet({
  required BuildContext context,
  required int currentQuantity,
  required int unitCentavos,
  int maxQuantity = chairQuantityLimit,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 620),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) => ChairsQuantitySheet(
    currentQuantity: currentQuantity,
    unitCentavos: unitCentavos,
    maxQuantity: maxQuantity,
  ),
);

/// Own the draft controller until the modal route finishes its closing animation.
class ChairsQuantitySheet extends StatefulWidget {
  const ChairsQuantitySheet({
    super.key,
    required this.currentQuantity,
    required this.unitCentavos,
    this.maxQuantity = chairQuantityLimit,
  }) : assert(maxQuantity > 0 && maxQuantity <= chairQuantityLimit),
       assert(unitCentavos >= 0 && unitCentavos <= 9999999999);

  final int currentQuantity, unitCentavos, maxQuantity;

  @override
  State<ChairsQuantitySheet> createState() => _ChairsQuantitySheetState();
}

class _ChairsQuantitySheetState extends State<ChairsQuantitySheet> {
  late final _controller = TextEditingController(
    text: '${widget.currentQuantity > 0 ? widget.currentQuantity : 1}',
  );

  int? get _quantity => RegExp(r'^\d+$').hasMatch(_controller.text)
      ? int.tryParse(_controller.text)
      : null;
  bool get _valid =>
      _quantity != null && _quantity! >= 1 && _quantity! <= widget.maxQuantity;

  void _close(int? value) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _actions() => LayoutBuilder(
    builder: (context, constraints) {
      final cancel = OutlinedButton(
        onPressed: () => _close(null),
        style: OutlinedButton.styleFrom(
          foregroundColor: bookingNavy,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: bookingNavy),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: _sheetText(14, weight: FontWeight.w600),
        ),
        child: const Text('Cancel', textAlign: TextAlign.center),
      );
      final confirm = FilledButton(
        onPressed: _valid ? () => _close(_quantity) : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFCB316),
          foregroundColor: bookingNavy,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: _sheetText(14, weight: FontWeight.w600),
        ),
        child: const Text('Confirm', textAlign: TextAlign.center),
      );
      if (constraints.maxWidth < 300 &&
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cancel, const SizedBox(height: 12), confirm],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cancel),
            const SizedBox(width: 12),
            Expanded(child: confirm),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Montserrat'),
    ),
    child: DefaultTextStyle.merge(
      style: _sheetText(14),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            key: const ValueKey('chairs-quantity-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chairs Quantity',
                  style: _sheetText(18, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Chairs quantity',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: TextField(
                      key: const ValueKey('chairs-quantity-input'),
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
                      textAlign: TextAlign.start,
                      style: _sheetText(16, weight: FontWeight.w500),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Quantity',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        errorStyle: _sheetText(12, color: bookingRed),
                        filled: true,
                        fillColor: Colors.white,
                        errorText: _valid
                            ? null
                            : 'Enter a whole number from 1 to ${widget.maxQuantity}.',
                        errorMaxLines: 8,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: bookingOutline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: bookingOutline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                            color: bookingNavy,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Estimated chair charge',
                      style: _sheetText(14, color: bookingMuted),
                    ),
                    Text(
                      _valid
                          ? chairMoney(_quantity! * widget.unitCentavos)
                          : 'Enter a valid quantity',
                      key: const ValueKey('chairs-quantity-subtotal'),
                      style: _sheetText(16, weight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _actions(),
                if (widget.currentQuantity > 0) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _close(0),
                    style: TextButton.styleFrom(
                      foregroundColor: bookingNavy,
                      minimumSize: const Size(0, 48),
                      textStyle: _sheetText(14, weight: FontWeight.w500),
                    ),
                    child: const Text('Remove Chairs'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
