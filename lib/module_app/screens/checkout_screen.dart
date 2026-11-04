import 'package:flutter/material.dart';

import '../models/product_customization.dart';
import '../services/order_service.dart';
import '../services/checkout_validation.dart';
import '../session/session_service.dart';
import '../widgets/order_summary_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.selection,
    required this.imageUrl,
    required this.category,
    required this.sellerName,
    required this.sellerContact,
    this.onOrderPlaced,
  });

  final int? productId;
  final String productName;
  final double basePrice;
  final BuySelection selection;
  final String imageUrl;
  final String category;
  final String sellerName;
  final String sellerContact;
  final VoidCallback? onOrderPlaced;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _showPlacedOrders = false;
  bool _isPlacing = false;
  final _sellerMessageController = TextEditingController();
  String _fulfillmentMethod = 'pickup';
  String _deliveryDestination = '';
  String _requestKey = OrderService.requestKey();
  final _validation = CheckoutValidation();
  Map<String, dynamic>? _submittedOrder;

  late int _quantity = widget.selection.quantity;

  late List<OrderSummaryLineItem> _lineItems = [
    OrderSummaryLineItem(
      productName: widget.productName,
      sellerName: widget.sellerName,
      imageUrl: widget.imageUrl,
      quantity: _quantity,
      unitPrice: widget.selection.unitPrice,
      selections: widget.selection.selections,
    ),
  ];

  double get _subtotal => _validation.ready
      ? _validation.subtotal
      : widget.selection.unitPrice * _quantity;

  double get _grandTotal => _subtotal;

  @override
  void initState() {
    super.initState();
    _validation.addListener(_quoteChanged);
    _refreshQuote();
  }

  void _quoteChanged() {
    if (!mounted) return;
    setState(() {
      if (_validation.ready) {
        _lineItems = [
          OrderSummaryLineItem(
            productName: widget.productName,
            sellerName: widget.sellerName,
            imageUrl: widget.imageUrl,
            quantity: _quantity,
            unitPrice: double.parse(
              '${_validation.quotes.first['unit_price']}',
            ),
            selections: widget.selection.selections,
          ),
        ];
      }
    });
  }

  void _refreshQuote() => _validation.refresh([
    {
      'product_id': widget.productId,
      'quantity': _quantity,
      'customization': widget.selection.customizationPayload,
    },
  ]);

  void _updateQuantity(int newQty) {
    if (newQty < 1 || _isPlacing || _submittedOrder != null) return;
    setState(() {
      _quantity = newQty;
      _lineItems = [
        OrderSummaryLineItem(
          productName: widget.productName,
          sellerName: widget.sellerName,
          imageUrl: widget.imageUrl,
          quantity: newQty,
          unitPrice: widget.selection.unitPrice,
          selections: widget.selection.selections,
        ),
      ];
    });
    _refreshQuote();
  }

  @override
  void dispose() {
    _sellerMessageController.dispose();
    _validation.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_isPlacing || _showPlacedOrders) return;
    if (_submittedOrder == null &&
        !_validation.canSubmit(_fulfillmentMethod, _deliveryDestination)) {
      return;
    }
    if (_submittedOrder == null &&
        _fulfillmentMethod == 'seller_delivery' &&
        !CheckoutValidation.validLocation(_deliveryDestination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the seller delivery destination.')),
      );
      return;
    }
    setState(() => _isPlacing = true);
    final user = await SessionService.loadUser();
    _submittedOrder ??= {
      'fulfillment_method': _fulfillmentMethod,
      'payment_method': _fulfillmentMethod == 'pickup'
          ? 'cash_on_pickup'
          : 'cash_on_delivery',
      'expected_unit_price': _validation.quotes.first['unit_price'],
      'delivery_destination': _fulfillmentMethod == 'seller_delivery'
          ? _deliveryDestination.trim()
          : '',
      'product_id': widget.productId,
      'product_name': widget.productName,
      'category': widget.category,
      'buyer_user_id': user?.id,
      'buyer_name': user?.fullName ?? user?.studentId ?? '',
      'buyer_email': user?.email ?? '',
      'seller_name': widget.sellerName,
      'seller_contact': widget.sellerContact,
      'message_to_seller': _sellerMessageController.text.trim(),
      'option': widget.selection.summary,
      'customization': widget.selection.customizationPayload,
      'quantity': _quantity,
      'unit_price': double.parse('${_validation.quotes.first['unit_price']}'),
      'total_price': _grandTotal,
      'image_url': widget.imageUrl,
    };
    final result = await OrderService.submitOrder(
      operationKey: _requestKey,
      order: _submittedOrder!,
    );
    if (!mounted) return;
    if (!result.confirmed) {
      setState(() {
        _isPlacing = false;
        if (!result.uncertain) {
          _submittedOrder = null;
          _requestKey = OrderService.requestKey();
        }
      });
      if (!result.uncertain) _refreshQuote();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    widget.onOrderPlaced?.call();
    setState(() {
      _isPlacing = false;
      _showPlacedOrders = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _showPlacedOrders
          ? OrderSummaryConstants.pageBg
          : OrderSummaryConstants.checkoutBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: OrderSummaryConstants.navy,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !_showPlacedOrders,
        title: Text(
          _showPlacedOrders ? 'Review' : 'Checkout',
          style: CheckoutTypography.text(fontWeight: FontWeight.w600),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          textTheme: CheckoutTypography.textTheme(Theme.of(context).textTheme),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: _showPlacedOrders
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: _showPlacedOrders
                ? PlacedOrdersReviewView(
                    paymentMethodLabel: _fulfillmentMethod == 'pickup'
                        ? 'Cash on Pickup'
                        : 'Cash on Delivery',
                    items: _lineItems,
                    subtotal: _subtotal,
                    onDone: () => Navigator.of(context).pop(),
                  )
                : _CheckoutSummaryView(
                    items: _lineItems,
                    subtotal: _subtotal,
                    sellerMessageController: _sellerMessageController,
                    isPlacing: _isPlacing,
                    locked: _isPlacing || _submittedOrder != null,
                    validation: _validation,
                    onRetryValidation: _refreshQuote,
                    canPlace:
                        _submittedOrder != null ||
                        _validation.canSubmit(
                          _fulfillmentMethod,
                          _deliveryDestination,
                        ),
                    onPlaceOrder: _placeOrder,
                    onQuantityChanged: _updateQuantity,
                    onFulfillmentChanged: (method, destination) {
                      setState(() {
                        _fulfillmentMethod = method;
                        _deliveryDestination = destination;
                      });
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummaryView extends StatelessWidget {
  const _CheckoutSummaryView({
    required this.items,
    required this.subtotal,
    required this.sellerMessageController,
    required this.isPlacing,
    required this.locked,
    required this.onPlaceOrder,
    required this.validation,
    required this.onRetryValidation,
    required this.canPlace,
    this.onQuantityChanged,
    this.onFulfillmentChanged,
  });

  final List<OrderSummaryLineItem> items;
  final double subtotal;
  final TextEditingController sellerMessageController;
  final bool isPlacing;
  final bool locked;
  final CheckoutValidation validation;
  final VoidCallback onRetryValidation;
  final bool canPlace;
  final VoidCallback onPlaceOrder;
  final ValueChanged<int>? onQuantityChanged;
  final void Function(String, String)? onFulfillmentChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const CheckoutBuyerDetails(),
              OrderSummaryCard(
                locked: locked,
                deliverySupported: validation.deliverySupported,
                validation: validation,
                onRetryValidation: onRetryValidation,
                showCheckoutHeader: true,
                items: items,
                subtotal: subtotal,
                onFulfillmentChanged: onFulfillmentChanged,
                sellerMessageController: sellerMessageController,
                onQuantityChanged: onQuantityChanged != null
                    ? (_, qty) => onQuantityChanged!(qty)
                    : null,
              ),
            ],
          ),
        ),
        CheckoutPlaceOrderBar(
          subtotal: subtotal,
          isLoading: isPlacing,
          onPressed: canPlace ? onPlaceOrder : null,
        ),
      ],
    );
  }
}
