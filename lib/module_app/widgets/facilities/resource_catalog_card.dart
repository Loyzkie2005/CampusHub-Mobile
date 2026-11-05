import 'package:flutter/material.dart';

import '../../models/facility_item.dart';
import '../../models/service_item.dart';
import '../../theme/app_typography.dart';
import '../product_image.dart';
import 'facility_status_badge.dart';

/// Shared, read-only presentation for a facility or service. The caller owns
/// navigation; this card never approves, books, pays for or favorites a resource.
class ResourceCatalogCard extends StatelessWidget {
  const ResourceCatalogCard({
    super.key,
    required this.resource,
    required this.category,
    required this.price,
    required this.onDetails,
    this.information = '',
    this.showFacilityStatus = false,
  });

  static const navy = Color(0xFF1A1851);
  // This card's requested star accent; the global mobile palette is unchanged.
  static const gold = Color(0xFFFCB316);
  static const border = Color(0xFFE2E8F0);
  static const secondary = Color(0xFF475569);

  final FacilityItem resource;
  final String category;
  final String information;
  final String price;
  final VoidCallback onDetails;
  final bool showFacilityStatus;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: border),
    ),
    child: InkWell(
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(
                  imageUrl: resource.resolvedImageUrl,
                  fallbackIcon: resource.icon,
                  fallbackColor: navy,
                  backgroundColor: Colors.white,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ResourceReviewBadge(resource: resource),
                  ),
                ),
                if (resource.location.trim().isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ResourceLocationLabel(location: resource.location),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showFacilityStatus) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(category, style: _text(11, secondary)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: FacilityStatusBadge(status: resource.status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ] else if (category.trim().isNotEmpty) ...[
                  Text(category, style: _text(11, secondary)),
                  const SizedBox(height: 4),
                ],
                Text(
                  resource.name,
                  style: _text(14, navy, weight: FontWeight.w600),
                ),
                if (information.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(information, style: _text(12, secondary)),
                ],
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  price,
                  style: _text(
                    13,
                    navy,
                    weight: FontWeight.w600,
                  ).copyWith(fontFamilyFallback: const [AppTypography.family]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: navy,
                    backgroundColor: navy.withValues(alpha: 0.06),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    textAlign: TextAlign.center,
                    style: _text(12, navy, weight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static TextStyle _text(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) => InterTypography.text(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.3,
  );
}

/// The saved location is readable over any photo. Long labels use a two-line
/// preview; the tooltip and accessible label retain the full recorded value.
class ResourceLocationLabel extends StatelessWidget {
  const ResourceLocationLabel({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: location.trim(),
    child: Semantics(
      label: 'Location: ${location.trim()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: ResourceCatalogCard.navy.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                location.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ResourceCatalogCard._text(11, Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Use both a valid aggregate rating AND an actual review count. Never use a
/// booking count as evidence of reviews. Missing API aggregates stay empty.
class ResourceReviewBadge extends StatelessWidget {
  const ResourceReviewBadge({super.key, required this.resource});
  final FacilityItem resource;

  @override
  Widget build(BuildContext context) {
    final rating = double.tryParse(resource.rating);
    final count = int.tryParse(resource.reviews);
    final rated =
        rating != null &&
        rating.isFinite &&
        rating >= 1 &&
        rating <= 5 &&
        count != null &&
        count > 0;
    final label = rated
        ? '${rating.toStringAsFixed(1)} ($count)'
        : 'No reviews yet';
    return Semantics(
      label: rated
          ? '${rating.toStringAsFixed(1)} out of 5 stars from $count ${count == 1 ? 'review' : 'reviews'}'
          : label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: ResourceCatalogCard.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              rated ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13,
              color: ResourceCatalogCard.gold,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: ResourceCatalogCard._text(
                  11,
                  Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keep cards wide: a full row on phones and two columns only when
/// each card can be at least 360dp wide. Intrinsic rows align the bottom actions.
class ResourceCardGrid extends StatelessWidget {
  const ResourceCardGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 732 ? 2 : 1;
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columns) ...[
            if (i > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child: i + j < children.length
                          ? children[i + j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

String facilityCardInformation(FacilityItem facility) {
  if (facility.capacityLabel.trim().isNotEmpty) return facility.capacityLabel;
  final capacity = int.tryParse(facility.capacity);
  return capacity != null && capacity > 0 ? '$capacity pax' : '';
}

/// The public service catalog already supplies active prices with billing units.
/// Only compare analysis fees sharing one unit; do not compare per-sample and
/// per-analysis fees or infer discounts/eligibility from an account type.
String serviceCardPrice(ServiceItem service) {
  final pattern = RegExp(r'^₱\s*([\d,]+(?:\.\d+)?) per (sample|analysis)$');
  final fees = <(double, String)>[];
  for (final entry in service.information) {
    final match = pattern.firstMatch(entry.value.trim());
    if (match == null) continue;
    final amount = double.tryParse(match[1]!.replaceAll(',', ''));
    if (amount != null && amount.isFinite && amount >= 0) {
      fees.add((amount, match[2]!));
    }
  }
  if (service.kind == 'laboratory' &&
      fees.isNotEmpty &&
      fees.map((fee) => fee.$2).toSet().length == 1) {
    fees.sort((a, b) => a.$1.compareTo(b.$1));
    final varies = fees.map((fee) => fee.$1).toSet().length > 1;
    return '${varies ? 'From ' : ''}₱${fees.first.$1.toStringAsFixed(2)} per ${fees.first.$2}';
  }
  for (final entry in service.information) {
    if (entry.key == 'Pricing' && entry.value.trim().isNotEmpty) {
      return entry.value;
    }
  }
  return service.facility.catalogPriceLabel.isNotEmpty
      ? service.facility.catalogPriceLabel
      : 'Contact office for pricing';
}
