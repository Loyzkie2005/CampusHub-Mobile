import 'package:flutter/material.dart';

import '../home/home_preview_cards.dart';
import '../profile/profile_widgets.dart';

/// Presents canonical inventory values without calculating stock or thresholds.
class SellerInventoryAlert extends StatelessWidget {
  const SellerInventoryAlert({
    super.key,
    required this.row,
    required this.quantity,
  });

  final Map<String, dynamic> row;
  final String Function(dynamic) quantity;

  @override
  Widget build(BuildContext context) {
    final out = row['status'] == 'out_of_stock';
    return Container(
      key: ValueKey('inventory-alert-${row['sku']}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HomeAppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['product_name'] ?? 'Product not recorded'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileStyle.identityText(14, weight: 600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${row['sku'] ?? 'Not recorded'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileStyle.identityText(
                        11,
                        color: ProfileStyle.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    key: ValueKey('inventory-status-${row['sku']}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: out
                          ? const Color(0xFFF1F1F5)
                          : const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${row['status_label'] ?? (out ? 'Out of Stock' : 'Low Stock')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileStyle.identityText(
                        11,
                        weight: 600,
                        color: out
                            ? ProfileStyle.navy
                            : const Color(0xFF8C5900),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Stock',
                      style: ProfileStyle.identityText(
                        11,
                        color: ProfileStyle.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quantity(row['available']),
                      key: ValueKey('inventory-available-${row['sku']}'),
                      style: ProfileStyle.identityText(26, weight: 700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restock Threshold',
                      style: ProfileStyle.identityText(
                        11,
                        color: ProfileStyle.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quantity(row['threshold']),
                      key: ValueKey('inventory-threshold-${row['sku']}'),
                      style: ProfileStyle.identityText(16, weight: 600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in [
                  ('On Hand', row['on_hand']),
                  ('Reserved', row['reserved']),
                ])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$1,
                          style: ProfileStyle.identityText(
                            11,
                            color: ProfileStyle.secondary,
                          ),
                        ),
                        Text(
                          quantity(entry.$2),
                          style: ProfileStyle.identityText(13, weight: 600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
