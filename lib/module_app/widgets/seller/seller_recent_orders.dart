import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../home/home_preview_cards.dart';
import '../profile/profile_widgets.dart';
import '../product_image.dart';

/// Renders up to five supplied owner-scoped order previews.
class SellerRecentOrders extends StatefulWidget {
  const SellerRecentOrders({
    super.key,
    required this.orders,
    required this.onDetails,
    required this.money,
    required this.date,
    this.emptyTitle = 'No recent orders yet',
    this.emptyMessage = 'New customer orders will appear here.',
  });
  final List<Map<String, dynamic>> orders;
  final ValueChanged<Map<String, dynamic>> onDetails;
  final String Function(dynamic) money, date;
  final String emptyTitle, emptyMessage;
  @override
  State<SellerRecentOrders> createState() => _SellerRecentOrdersState();
}

class _SellerRecentOrdersState extends State<SellerRecentOrders> {
  static const _indicatorGold = Color(0xFFFCB316);
  final _controller = PageController();
  int _page = 0;
  List<Map<String, dynamic>> get _rows => widget.orders.take(5).toList();

  @override
  void didUpdateWidget(covariant SellerRecentOrders oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the selected order when a refreshed snapshot changes the list.
    final old = oldWidget.orders.take(5).toList();
    final selectedId = old.isNotEmpty
        ? old[_page.clamp(0, old.length - 1)]['id']
        : null;
    final index = _rows.indexWhere((row) => row['id'] == selectedId);
    final next = index >= 0 ? index : 0;
    if (next != _page) {
      _page = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(next);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle style(
    double size, {
    int weight = 400,
    Color color = HomeAppColors.navy,
  }) => ProfileStyle.identityText(size, weight: weight, color: color);

  String buyer(Map row) {
    final name =
        '${row.containsKey('buyer_full_name') ? row['buyer_full_name'] ?? '' : row['buyer_name'] ?? ''}'
            .trim();
    return name.isEmpty ? 'Buyer not recorded' : name;
  }

  String orderStatus(Map row) => '${row['status'] ?? ''}'.trim().isEmpty
      ? 'Not recorded'
      : '${row['status']}';

  double _badgeWidth(BuildContext context, Map row, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: orderStatus(row),
        style: DefaultTextStyle.of(context).style.merge(style(11, weight: 600)),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, maxWidth - 22));
    final width = math.min(maxWidth, painter.width + 22);
    painter.dispose();
    return width;
  }

  Widget _statusBadge(Map row, double maxWidth) {
    final recordedKey = '${row['status_key'] ?? ''}'.trim();
    final status = (recordedKey.isEmpty ? '${row['status']}' : recordedKey)
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    final (background, foreground) = switch (status) {
      'pending' => (const Color(0xFFFFF3D6), const Color(0xFF8C5900)),
      'processing' ||
      'ready_for_pickup' => (const Color(0xFFEAF0FF), const Color(0xFF24428A)),
      'completed' ||
      'cancelled' => (const Color(0xFFF1F1F5), HomeAppColors.navy),
      _ => (const Color(0xFFF1F1F5), HomeAppColors.navy),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        key: ValueKey('recent-order-status-${row['id']}'),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          orderStatus(row),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style(11, weight: 600, color: foreground),
        ),
      ),
    );
  }

  Map getPreview(Map row) =>
      row['product_preview'] is Map ? row['product_preview'] as Map : const {};
  List<Map> getItems(Map row) => row['items'] is List
      ? (row['items'] as List).whereType<Map>().toList()
      : const [];
  String productName(Map row) {
    final items = getItems(row);
    for (final value in [
      getPreview(row)['product_name'],
      if (items.isNotEmpty) items.first['product_name'],
      row['product_name'],
    ]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'Product not recorded';
  }

  String productQuantity(Map row) {
    final items = getItems(row);
    final quantity =
        getPreview(row)['quantity'] ??
        (items.isNotEmpty ? items.first['quantity'] : row['quantity']);
    return 'Quantity: ${quantity == null || '$quantity'.trim().isEmpty ? 'Not recorded' : quantity}';
  }

  int extraItems(Map row) {
    final value = getPreview(row)['additional_items'];
    return value is int && value >= 0
        ? value
        : math.max(0, getItems(row).length - 1);
  }

  String receiving(Map row) => switch (row['fulfillment_method']) {
    'pickup' => 'Customer Pickup',
    'seller_delivery' => 'Seller Delivery',
    _ =>
      '${row['fulfillment_label'] ?? ''}'.trim().isEmpty ||
              row['fulfillment_label'] == 'Not recorded'
          ? 'Receiving method not recorded'
          : '${row['fulfillment_label']}',
  };
  String payment(Map row) => '${row['payment_status'] ?? ''}'.trim().isEmpty
      ? 'Not recorded'
      : '${row['payment_status']}';
  String thumbnail(Map row) {
    final items = getItems(row);
    for (final value in [
      getPreview(row)['thumbnail_url'],
      if (items.isNotEmpty) ...[
        items.first['thumbnail_url'],
        items.first['image_url'],
      ],
      row['image_url'],
    ]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  double _amountWidth(BuildContext context, Map row) {
    var width = 0.0;
    for (final (label, size, weight) in [
      ('Order Total', 11.0, 400),
      (widget.money(row['total']), 16.0, 600),
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(
            context,
          ).style.merge(style(size, weight: weight)),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width = math.max(width, painter.width.ceilToDouble());
      painter.dispose();
    }
    return width;
  }

  bool _sideAmount(BuildContext context, Map row, double inner) =>
      inner >= 300 &&
      MediaQuery.textScalerOf(context).scale(12) <= 18 &&
      _amountWidth(context, row) <= inner * .4;

  // Measure the same responsive regions rendered below; carousel pages share
  // the tallest recorded order height, preserving readable scaled text.
  double _height(BuildContext context, double width, Map row) {
    final scaler = MediaQuery.textScalerOf(context);
    double text(
      String value,
      double size,
      double available, {
      int weight = 400,
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: DefaultTextStyle.of(
            context,
          ).style.merge(style(size, weight: weight)),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: available);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final inner = math.max(1.0, width - 34);
    final headerWidth = (inner - 12) / 2;
    final badgeWidth = _badgeWidth(
      context,
      row,
      math.max(22.0, width - 34 - 12 - 96),
    );
    final identityWidth = math.max(1.0, inner - badgeWidth - 12);
    final side = _sideAmount(context, row, inner);
    final amountWidth = _amountWidth(context, row);
    final productWidth = math.max(
      1.0,
      inner - 68 - (side ? amountWidth + 12 : 0),
    );
    final count = extraItems(row);
    final productHeight =
        text(productName(row), 13, productWidth, weight: 600, maxLines: 2) +
        4 +
        text(productQuantity(row), 11, productWidth) +
        4 +
        text(receiving(row), 11, productWidth) +
        (count > 0
            ? 4 +
                  text(
                    '+$count more ${count == 1 ? 'item' : 'items'}',
                    11,
                    productWidth,
                  )
            : 0);
    final amountHeight =
        text('Order Total', 11, side ? amountWidth : inner) +
        4 +
        text(
          widget.money(row['total']),
          16,
          side ? amountWidth : inner,
          weight: 600,
        );
    final productRegion = side
        ? math.max(56, math.max(productHeight, amountHeight))
        : math.max(56, productHeight) + 12 + amountHeight;
    final metadata = math.max(
      text('Payment Status', 11, headerWidth) +
          4 +
          math.max(14, text(payment(row), 12, math.max(1, headerWidth - 18))),
      text('Order Date', 11, headerWidth) +
          4 +
          text(widget.date(row['created_at']), 12, headerWidth),
    );
    return 16 +
        math.max(
          text(buyer(row), 14, identityWidth, weight: 600, maxLines: 2) +
              2 +
              text('Order #${row['code']}', 11, identityWidth, maxLines: 1),
          text(
                orderStatus(row),
                11,
                headerWidth - 22,
                weight: 600,
                maxLines: 1,
              ) +
              12,
        ) +
        25 +
        productRegion +
        25 +
        metadata +
        12 +
        math.max(
          48,
          text('View Order Details', 13, math.max(1, inner - 48), weight: 600) +
              24,
        ) +
        4;
  }

  Widget _amount(BuildContext context, Map row, {bool end = true}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text('Order Total', style: style(11, color: ProfileStyle.secondary)),
      const SizedBox(height: 4),
      Text(widget.money(row['total']), style: style(16, weight: 600)),
    ],
  );

  Widget _productSummary(BuildContext context, Map row, double width) {
    final side = _sideAmount(context, row, width);
    final count = extraItems(row);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImage(
                  key: ValueKey('recent-order-image-${row['id']}'),
                  imageUrl: thumbnail(row),
                  fallbackIcon: Icons.inventory_2_outlined,
                  fallbackColor: HomeAppColors.navy,
                  fallbackSize: 24,
                  backgroundColor: HomeAppColors.border.withValues(alpha: .35),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName(row),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style(13, weight: 600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    productQuantity(row),
                    style: style(11, color: ProfileStyle.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    receiving(row),
                    style: style(11, color: ProfileStyle.secondary),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+$count more ${count == 1 ? 'item' : 'items'}',
                      style: style(11, color: ProfileStyle.secondary),
                    ),
                  ],
                ],
              ),
            ),
            if (side) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: _amountWidth(context, row),
                child: _amount(context, row),
              ),
            ],
          ],
        ),
        if (!side) ...[
          const SizedBox(height: 12),
          _amount(context, row, end: false),
        ],
      ],
    );
  }

  Widget _metadata(Map row) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Status',
              style: style(11, color: ProfileStyle.secondary),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  payment(row).toLowerCase() == 'unpaid'
                      ? Icons.schedule_outlined
                      : payment(row).toLowerCase() == 'paid'
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 14,
                  color: payment(row).toLowerCase() == 'unpaid'
                      ? const Color(0xFF8C5900)
                      : HomeAppColors.navy,
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(payment(row), style: style(12))),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Order Date', style: style(11, color: ProfileStyle.secondary)),
            const SizedBox(height: 4),
            Text(
              widget.date(row['created_at']),
              textAlign: TextAlign.right,
              style: style(12),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.emptyTitle, style: style(14, weight: 600)),
            const SizedBox(height: 4),
            Text(
              widget.emptyMessage,
              style: style(12, color: ProfileStyle.secondary),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the buyer identity while keeping the status compact.
        final statusMaxWidth = math.max(
          22.0,
          constraints.maxWidth - 34 - 12 - 96,
        );
        final height = rows.fold<double>(
          0,
          (h, row) => math.max(h, _height(context, constraints.maxWidth, row)),
        );
        return Container(
          key: const ValueKey('seller-recent-orders-card'),
          padding: EdgeInsets.only(bottom: rows.length > 1 ? 0 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: HomeAppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: PageView.builder(
                  key: const PageStorageKey('seller-recent-orders'),
                  controller: _controller,
                  allowImplicitScrolling: true,
                  itemCount: rows.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Semantics(
                      label: 'Recent order ${index + 1} of ${rows.length}',
                      child: Container(
                        key: ValueKey('recent-order-${row['id']}'),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              key: ValueKey('recent-order-header-${row['id']}'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        buyer(row),
                                        key: ValueKey(
                                          'recent-order-buyer-${row['id']}',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: style(14, weight: 600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Order #${row['code']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: style(
                                          11,
                                          color: ProfileStyle.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _statusBadge(row, statusMaxWidth),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: HomeAppColors.border,
                            ),
                            const SizedBox(height: 12),
                            _productSummary(
                              context,
                              row,
                              math.max(1, constraints.maxWidth - 34),
                            ),
                            const SizedBox(height: 12),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: HomeAppColors.border,
                            ),
                            const SizedBox(height: 12),
                            _metadata(row),
                            const Spacer(),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: ValueKey(
                                'recent-order-details-${row['id']}',
                              ),
                              onPressed: () => widget.onDetails(row),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                textStyle: style(13, weight: 600),
                                backgroundColor: HomeAppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'View Order Details',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (rows.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Semantics(
                        selected: i == _page,
                        button: true,
                        label: 'Show recent order ${i + 1} of ${rows.length}',
                        child: SizedBox(
                          width: 24,
                          height: 44,
                          child: IconButton(
                            tooltip: 'Order ${i + 1} of ${rows.length}',
                            onPressed: () => _controller.jumpToPage(i),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(24, 44),
                              fixedSize: const Size(24, 44),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Container(
                              key: ValueKey('recent-order-dot-$i'),
                              width: i == _page ? 9 : 7,
                              height: i == _page ? 9 : 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page
                                    ? _indicatorGold
                                    : HomeAppColors.border,
                                border: i == _page
                                    ? Border.all(color: HomeAppColors.navy)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
