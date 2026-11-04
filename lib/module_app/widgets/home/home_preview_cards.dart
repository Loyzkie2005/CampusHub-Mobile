import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import '../../theme/marketplace_colors.dart';

import '../../models/facility_item.dart';
import '../../models/product_item.dart';
import '../../models/service_item.dart';
import '../../services/cart_service.dart';
import '../../services/favorite_service.dart';
import '../../services/product_service.dart';
import '../../services/service_catalog.dart';
import '../../session/session_service.dart';
import '../product_image.dart';
import '../facilities/resource_catalog_card.dart';
import '../../screens/facility_details_screen.dart';
import '../../screens/product_details_screen.dart';
import '../../screens/service_details_screen.dart';

/// Centralized institutional color palette for CampusHub mobile dashboard.
abstract class HomeAppColors {
  // Primary Brand Colors
  static const Color navy = Color(0xFF1A1851);
  static const Color gold = Color(0xFFFCB315);
  static const Color white = Color(0xFFFFFFFF);

  // Supporting Colors
  static const Color appBackground = white;
  static const Color surfaceTint = white;
  static const Color primaryText = navy;
  static const Color secondaryText = Color(0xFF475569);
  static const Color mutedText = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color cardBorder = border;

  // Status Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFECFDF3);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFF7E6);
  static const Color error = Color(0xFFDC2626);
}

/// Institutional Section Header for Home Dashboard
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onSeeAll,
  });

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Text(
        title,
        style: InterTypography.text(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: HomeAppColors.navy,
          letterSpacing: -0.3,
        ),
      );
      final action = TextButton(
        onPressed: onSeeAll,
        style: TextButton.styleFrom(
          foregroundColor: HomeAppColors.navy,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'See All',
              style: InterTypography.text(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeAppColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: HomeAppColors.navy,
            ),
          ],
        ),
      );
      if (constraints.maxWidth < 420 &&
          MediaQuery.textScalerOf(context).scale(19) > 28) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 8),
          action,
        ],
      );
    },
  );
}

/// Shared product destination and existing interaction tracking for Home/Search.
Future<void> openMarketplaceProduct(
  BuildContext context,
  ProductItem product,
) async {
  final user = await SessionService.loadUser();
  if (product.id != null && user != null) {
    await ProductService.trackInteraction(
      userId: user.id,
      productId: product.id!,
      interactionType: 'view',
    );
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductDetailsScreen(
        id: product.id,
        userId: user?.id,
        sellerId: product.sellerId,
        sellerRef: product.sellerRef,
        name: product.name,
        priceLabel: product.price,
        imageUrl: product.imageUrl,
        images: product.images,
        category: product.category,
        seller: product.seller,
        sellerPhotoUrl: product.sellerPhotoUrl,
        sellerContact: product.sellerContact,
        stock: product.stock,
        description: product.description,
        expiryDate: product.expiryDate,
        inventoryStatus: product.inventoryStatus,
        inventoryStatusLabel: product.inventoryStatusLabel,
        isPurchasable: product.isPurchasable,
        soldCount: product.soldCount,
        rating: product.rating,
        reviewsCount: product.reviewsCount,
        submittedAt: product.submittedAt,
        customization: product.customization,
      ),
    ),
  );
}

/// Clean, institutional Marketplace Preview Card for Home Dashboard
class MarketplacePreviewCard extends StatelessWidget {
  const MarketplacePreviewCard({
    super.key,
    required this.product,
    this.width = 158.0,
  });

  final ProductItem product;
  final double width;

  String get _favoriteKey =>
      favoriteKeyForProduct(id: product.id, name: product.name);

  Future<void> _handleQuickAdd(BuildContext context) async {
    if (!product.isPurchasable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is unavailable.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    await CartService.instance.quickAdd(context: context, product: product);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: MarketplaceColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeAppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openMarketplaceProduct(context, product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 126,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageUrl: product.imageUrl,
                      fallbackIcon: product.icon,
                      fallbackColor: HomeAppColors.navy,
                      backgroundColor: MarketplaceColors.imageSurface,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: AnimatedBuilder(
                        animation: FavoriteService.instance,
                        builder: (context, _) {
                          final favorite = FavoriteService.instance.isFavorite(
                            _favoriteKey,
                          );
                          return Material(
                            color: Colors.transparent,
                            child: IconButton(
                              tooltip: favorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              onPressed: () =>
                                  FavoriteService.instance.toggle(_favoriteKey),
                              style: IconButton.styleFrom(
                                backgroundColor: HomeAppColors.white.withValues(
                                  alpha: 0.9,
                                ),
                                foregroundColor: HomeAppColors.navy,
                                minimumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                              ),
                              icon: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: HomeAppColors.navy,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: InterTypography.text(
                        color: HomeAppColors.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          InterTypography.text(
                            color: HomeAppColors.navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ).copyWith(
                            fontFamilyFallback: const [AppTypography.family],
                          ),
                    ),
                    const SizedBox(height: 3),
                    if (product.category.trim().isNotEmpty) ...[
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InterTypography.text(
                          color: HomeAppColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    if ((product.stock != null && product.stock! <= 5) ||
                        !product.isPurchasable) ...[
                      Text(
                        product.stock == 0
                            ? 'Out of Stock'
                            : !product.isPurchasable
                            ? 'Unavailable'
                            : 'Low Stock: ${product.stock}',
                        style: InterTypography.text(
                          color: HomeAppColors.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.seller,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InterTypography.text(
                              color: HomeAppColors.secondaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (product.isPurchasable)
                          IconButton(
                            tooltip: 'Add to cart',
                            onPressed: () => _handleQuickAdd(context),
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18,
                              color: HomeAppColors.navy,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home and listing share the same facility presentation and detail destination.
class FacilityPreviewCard extends StatelessWidget {
  const FacilityPreviewCard({
    super.key,
    required this.facility,
    this.width = 320,
    this.onDetails,
  });
  final FacilityItem facility;
  final double width;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ResourceCatalogCard(
      resource: facility,
      category: facility.facilityTypeLabel,
      information: facilityCardInformation(facility),
      price: facility.cardPriceLabel,
      onDetails:
          onDetails ??
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FacilityDetailsScreen(facility: facility),
            ),
          ),
    ),
  );
}

/// A service remains a service: this opens its existing guidance/details flow.
class ServicePreviewCard extends StatelessWidget {
  const ServicePreviewCard({
    super.key,
    required this.service,
    required this.catalog,
    this.width = 320,
    this.onDetails,
  });
  final ServiceItem service;
  final ServiceCatalog catalog;
  final double width;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ResourceCatalogCard(
      resource: service.facility,
      category: service.category,
      information: service.facility.description,
      price: serviceCardPrice(service),
      onDetails:
          onDetails ??
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/services/details'),
              builder: (_) =>
                  ServiceDetailsScreen(service: service, catalog: catalog),
            ),
          ),
    ),
  );
}
