import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../home/home_preview_cards.dart';
import '../profile/profile_widgets.dart';

/// Renders up to five supplied owner-scoped order previews.
class SellerRecentOrders extends StatefulWidget {
  const SellerRecentOrders({
    super.key,
    required this.orders,
    required this.onDetails,
    required this.money,
    required this.date,
    this.emptyTitle = 'No Recent Orders',
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

  double _badgeWidth(BuildContext context, Map row, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: '${row['status']}',
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
      'completed' => (const Color(0xFFEAF6EE), const Color(0xFF21643C)),
      'cancelled' => (const Color(0xFFFDECEC), const Color(0xFF9F2D2D)),
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
          '${row['status']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style(11, weight: 600, color: foreground),
        ),
      ),
    );
  }

  // Measure page content only; the shared card owns its border and footer.
  double _height(BuildContext context, double width, Map row) {
    final scaler = MediaQuery.textScalerOf(context);
    double text(
      String value,
      double size,
      double available, {
      int weight = 400,
      int? maxLines,
      bool measureWidth = false,
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
      final height = measureWidth ? painter.width : painter.height;
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
    final total = widget.money(row['total']);
    final labelHeight = text('Order Total', 12, inner);
    final amountHeight = text(total, 22, inner, weight: 700);
    final totalHeight =
        text('Order Total', 12, inner, measureWidth: true) +
                text(total, 22, inner, weight: 700, measureWidth: true) +
                12 <=
            inner
        ? math.max(labelHeight, amountHeight)
        : labelHeight + 4 + amountHeight;
    return 16 +
        math.max(
          text(buyer(row), 14, identityWidth, weight: 600, maxLines: 2) +
              2 +
              text('Order #${row['code']}', 11, identityWidth, maxLines: 1),
          text(
                '${row['status']}',
                11,
                headerWidth - 22,
                weight: 600,
                maxLines: 1,
              ) +
              12,
        ) +
        12 +
        totalHeight +
        12 +
        math.max(
          text(widget.date(row['created_at']), 12, headerWidth),
          text(
            'Payment: ${row['payment_status'] ?? 'Not recorded'}',
            12,
            headerWidth,
          ),
        ) +
        8 +
        math.max(48, text('View Details', 13, inner - 24, weight: 500) + 24) +
        4;
  }

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
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Order Total',
                                  style: style(
                                    12,
                                    color: ProfileStyle.secondary,
                                  ),
                                ),
                                Text(
                                  widget.money(row['total']),
                                  style: style(22, weight: 700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.date(row['created_at']),
                                    style: style(12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Payment: ${row['payment_status'] ?? 'Not recorded'}',
                                    textAlign: TextAlign.right,
                                    style: style(12),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => widget.onDetails(row),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                textStyle: style(13, weight: 500),
                                foregroundColor: HomeAppColors.navy,
                              ),
                              child: const Text('View Details'),
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
