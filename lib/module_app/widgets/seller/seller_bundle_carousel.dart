import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import '../home/home_preview_cards.dart';
import '../product_image.dart';
import 'synthetic_demo_images.dart';
import '../../services/demo_bundle_store.dart';

/// Live creation remains in Django; synthetic samples use isolated local storage.
class SellerBundleCarousel extends StatefulWidget {
  const SellerBundleCarousel({
    super.key,
    required this.rows,
    required this.onCreate,
    required this.emptyState,
    this.onDismiss,
    this.onDecline,
    this.carousel = true,
  });
  final List<Map<String, dynamic>> rows;
  final FutureOr<void> Function(Map<String, dynamic>) onCreate;
  final Future<void> Function(Map<String, dynamic>)? onDismiss;
  final Future<void> Function(Map<String, dynamic>)? onDecline;
  final Widget emptyState;
  final bool carousel;

  @override
  State<SellerBundleCarousel> createState() => _SellerBundleCarouselState();
}

class _SellerBundleCarouselState extends State<SellerBundleCarousel> {
  static const gold = Color(0xFFFCB316);
  final _controller = PageController();
  final _hidden = <String>{};
  int _page = 0;
  String? _busy;
  String identity(Map row) =>
      '${row['source'] ?? 'live'}:${row['revision'] ?? ''}:${row['id']}';
  List<Map<String, dynamic>> get rows =>
      widget.rows.where((row) => !_hidden.contains(identity(row))).toList();

  @override
  void didUpdateWidget(covariant SellerBundleCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page = _page.clamp(0, math.max(0, rows.length - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _controller.hasClients &&
          _controller.page?.round() != _page) {
        _controller.jumpToPage(_page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle text(double size, {int weight = 400}) =>
      InterTypography.sized(size, weight: weight);
  List<Map> products(Map row) =>
      (row['products'] as List).whereType<Map>().toList();
  bool canCreate(Map row) => row['source'] == 'synthetic'
      ? DemoBundleStore.validPair(row)
      : row['can_create'] != false;
  String label(Map row) => switch (row['source']) {
    'admin' => 'Recommended by Marketplace Admin',
    'synthetic' => 'Testing Only',
    _ => 'Live Data',
  };
  String status(Map row) => switch (row['status']) {
    'accepted' => 'Accepted',
    'declined' => 'Declined',
    'bundle_created' => 'Bundle Created',
    _ => 'Pending',
  };
  String title(Map row) => products(row).map((p) => '${p['name']}').join(' + ');
  String caption(Map row) => row['source'] == 'admin'
      ? status(row)
      : row['source'] == 'synthetic'
      ? 'Sample product combination — Not for Sale'
      : 'Based on completed marketplace orders';
  String actionLabel(Map row) =>
      row['source'] == 'admin' && status(row) == 'Pending'
      ? 'Accept'
      : row['source'] == 'synthetic'
      ? 'Create Demo Bundle'
      : 'Create Bundle';

  Future<void> decline(Map<String, dynamic> row) async {
    if (_busy != null || widget.onDecline == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline recommendation?'),
        content: const Text(
          'Your decision will remain in recommendation history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Recommendation'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline Recommendation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy != null) return;
    setState(() => _busy = identity(row));
    try {
      await widget.onDecline!(row);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to decline this recommendation. Retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String reason(Map row) => row['source'] == 'synthetic'
      ? 'This demo pair is incomplete. Refresh suggestions.'
      : '${row['creation_reason'] ?? 'These products are no longer available.'}';

  double measure(
    BuildContext context,
    String value,
    TextStyle style,
    double width, {
    int? lines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: lines,
    )..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double cardHeight(BuildContext context, double width) {
    final inner = math.max(1.0, width - 26);
    final productWidth = math.max(1.0, (inner - 32) / 2);
    var nameHeight = 0.0;
    var explanation = 0.0;
    var details = 0.0;
    var action = 48.0;
    for (final row in rows) {
      details = math.max(
        details,
        measure(context, title(row), text(14, weight: 600), inner, lines: 2) +
            8 +
            measure(context, caption(row), text(12), inner) +
            12,
      );
      final actionWidth = row['source'] == 'admin' && status(row) == 'Pending'
          ? (inner - 12) / 2 - 16
          : inner - 16;
      action = math.max(
        action,
        measure(context, actionLabel(row), text(13, weight: 600), actionWidth) +
            20,
      );
      action = math.max(
        action,
        measure(context, 'Decline', text(13, weight: 600), actionWidth) + 20,
      );
      for (final product in products(row)) {
        nameHeight = math.max(
          nameHeight,
          measure(
            context,
            '${product['name']}',
            text(13, weight: 500),
            productWidth,
            lines: 2,
          ),
        );
      }
      if (!canCreate(row)) {
        explanation = math.max(
          explanation,
          measure(context, reason(row), text(12), inner) + 8,
        );
      }
    }
    // Border/padding + menu/header + images + measured names + action + gaps.
    return 26 +
        headerHeight(context, width) +
        4 +
        80 +
        4 +
        nameHeight +
        8 +
        action +
        details +
        explanation;
  }

  double headerHeight(BuildContext context, double width) => math.max(
    48,
    measure(
      context,
      'Recommended by Marketplace Admin',
      text(12, weight: 500),
      width - 26 - 48,
    ),
  );

  Future<void> dismiss(Map<String, dynamic> row) async {
    if (_busy != null || widget.onDismiss == null) return;
    setState(() => _busy = identity(row));
    try {
      await widget.onDismiss!(row);
      if (!mounted) return;
      setState(() {
        _hidden.add(identity(row));
        _page = _page.clamp(0, math.max(0, rows.length - 1));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to dismiss this suggestion. Retry from its menu.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> create(Map<String, dynamic> row) async {
    if (_busy != null || !canCreate(row)) return;
    setState(() => _busy = identity(row));
    try {
      await widget.onCreate(row);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to validate this suggestion. Retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget card(
    BuildContext context,
    Map<String, dynamic> row,
    int index,
    double height,
    double width,
  ) => Container(
    key: ValueKey('bundle-card-${identity(row)}'),
    height: height,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: HomeAppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: headerHeight(context, width),
          child: Row(
            children: [
              Expanded(child: Text(label(row), style: text(12, weight: 500))),
              if (row['source'] != 'admin')
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    fixedSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  tooltip: 'Suggestion options',
                  enabled: _busy == null && widget.onDismiss != null,
                  icon: const Icon(
                    Icons.more_horiz,
                    color: HomeAppColors.navy,
                    size: 20,
                  ),
                  onSelected: (_) => dismiss(row),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'dismiss',
                      child: Text('Dismiss'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < products(row).length; i++) ...[
              if (i > 0)
                const SizedBox(
                  width: 32,
                  height: 80,
                  child: Icon(Icons.add, size: 18, color: gold),
                ),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ProductImage(
                          imageUrl: '${products(row)[i]['image_url'] ?? ''}',
                          fallbackAsset: syntheticDemoImage(
                            row,
                            products(row)[i],
                          ),
                          fallbackIcon: row['source'] == 'synthetic'
                              ? demoFoodIcon('${products(row)[i]['name']}')
                              : Icons.image_not_supported_outlined,
                          fallbackColor: HomeAppColors.navy,
                          backgroundColor: HomeAppColors.navy.withValues(
                            alpha: .05,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: '${products(row)[i]['name']}',
                      child: Text(
                        '${products(row)[i]['name']}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text(13, weight: 500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const Spacer(),
        const SizedBox(height: 8),
        Tooltip(
          message: title(row),
          child: Text(
            title(row),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text(14, weight: 600),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(caption(row), style: text(12))),
        const SizedBox(height: 12),
        if (row['source'] != 'admin' ||
            !['Declined', 'Bundle Created'].contains(status(row)))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FilledButton(
                  key: ValueKey('bundle-create-${row['id']}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeAppColors.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: text(13, weight: 600),
                  ),
                  onPressed: canCreate(row) && _busy == null
                      ? () => create(row)
                      : null,
                  child: Text(
                    _busy == identity(row) ? 'Please wait…' : actionLabel(row),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (row['source'] == 'admin' && status(row) == 'Pending') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('bundle-decline-${row['id']}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeAppColors.navy,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      textStyle: text(13, weight: 600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _busy == null && widget.onDecline != null
                        ? () => decline(row)
                        : null,
                    child: const Text('Decline', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ],
          ),
        if (!canCreate(row)) ...[
          const SizedBox(height: 8),
          Text(reason(row), style: text(12), textAlign: TextAlign.center),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return widget.emptyState;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = cardHeight(context, constraints.maxWidth);
        if (!widget.carousel) {
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card(
                    context,
                    rows[i],
                    i,
                    height,
                    constraints.maxWidth,
                  ),
                ),
            ],
          );
        }
        final first = (_page - 3).clamp(0, math.max(0, rows.length - 7));
        return Column(
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                key: const ValueKey('seller-bundle-carousel'),
                controller: _controller,
                itemCount: rows.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) => card(
                  context,
                  rows[index],
                  index,
                  height,
                  constraints.maxWidth,
                ),
              ),
            ),
            if (rows.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (
                      var i = first;
                      i < math.min(rows.length, first + 7);
                      i++
                    )
                      Semantics(
                        label: 'Suggestion ${i + 1} of ${rows.length}',
                        selected: i == _page,
                        child: Container(
                          key: ValueKey('bundle-indicator-$i'),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page ? gold : HomeAppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
