import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

import '../models/facility_item.dart';
import '../models/product_item.dart';
import '../models/service_item.dart';
import '../services/facility_service.dart';
import '../services/product_service.dart';
import '../services/service_catalog.dart';
import '../widgets/home/home_preview_cards.dart';
import '../widgets/home/campus_home_banners.dart';
import 'search_page.dart';

const homeNavy = HomeAppColors.navy;
const homeGold = HomeAppColors.gold;
const homeMuted = HomeAppColors.secondaryText;
const homeLine = HomeAppColors.cardBorder;
const homeLight = HomeAppColors.appBackground;

/// Home uses the existing catalogs. Search never substitutes sample data.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.firstName,
    required this.onMarketplace,
    required this.onFacilities,
    required this.onServices,
    required this.onRefresh,
    required this.productBuilder,
    this.catalog = const ServiceCatalog(),
    this.loadProducts = ProductService.fetchApproved,
    this.loadFacilities = FacilityService.fetchFacilities,
    this.sellerSections,
    this.showPromotionalBanners = true,
    this.showWelcomeGreeting = true,
    this.active = true,
    this.preferredCategories = const [],
    this.onCategory,
  });

  final String firstName;
  final VoidCallback onMarketplace, onFacilities, onServices;
  final Future<void> Function() onRefresh;
  final Widget Function(ProductItem) productBuilder;
  final ServiceCatalog catalog;
  final Future<List<ProductItem>> Function() loadProducts;
  final Future<FacilityServiceResult> Function() loadFacilities;
  final Widget? sellerSections;
  final bool showPromotionalBanners;
  final bool showWelcomeGreeting;
  final bool active;
  final List<String> preferredCategories;
  final ValueChanged<String>? onCategory;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late Future<List<ProductItem>> _products;
  late Future<List<FacilityItem>> _facilities;
  late Future<List<ServiceItem>> _services;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _observed<T>(Future<T> future) {
    // Sections below the viewport may attach their FutureBuilder later.
    future.ignore();
    return future;
  }

  void _load() {
    _products = _readProducts();
    _facilities = _readFacilities();
    _services = _readServices();
  }

  Future<List<ProductItem>> _readProducts() => _observed(
    widget.loadProducts().then((rows) {
      // A stable tie-break keeps the server's ordering when sales are equal.
      final indexed = rows.asMap().entries.toList();
      indexed.sort((a, b) {
        final sales = b.value.soldCount.compareTo(a.value.soldCount);
        return sales == 0 ? a.key.compareTo(b.key) : sales;
      });
      return indexed.map((row) => row.value).toList();
    }),
  );

  Future<List<FacilityItem>> _readFacilities() => _observed(
    widget.loadFacilities().then((result) {
      if (!result.success) throw StateError('Facility catalog unavailable');
      return result.facilities.map(FacilityItem.fromJson).toList();
    }),
  );

  Future<List<ServiceItem>> _readServices() => _observed(
    widget.catalog.fetchServices().then(
      (rows) => rows.where((row) => row.active).toList(),
    ),
  );

  Future<void> _refresh() async {
    setState(_load);
    // Futures render their own errors; a failed catalog does not hide others.
    await Future.wait<void>([
      widget.onRefresh(),
      _products.then<void>((_) {}, onError: (Object _) {}),
      _facilities.then<void>((_) {}, onError: (Object _) {}),
      _services.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  /// The shell header reuses Home's already-loaded catalog futures.
  void openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPage(
          catalog: widget.catalog,
          loadProducts: widget.loadProducts,
          loadFacilities: widget.loadFacilities,
          initialProducts: _products,
          initialFacilities: _facilities,
          initialServices: _services,
        ),
      ),
    );
  }

  Widget _section<T>({
    required String title,
    required Future<List<T>> future,
    required VoidCallback onAll,
    required VoidCallback retry,
    required String empty,
    required Widget Function(List<T>) content,
  }) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(title: title, onSeeAll: onAll),
        const SizedBox(height: 12),
        FutureBuilder<List<T>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HomeAppColors.navy,
                    ),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return _CatalogMessage(
                text: 'Unable to load ${title.toLowerCase()}.',
                onRetry: retry,
              );
            }
            final rows = snapshot.data ?? <T>[];
            if (rows.isEmpty) {
              return _CatalogMessage(text: empty);
            }
            return content(rows);
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context);
    final scale = (scaled.scale(14) / 14).clamp(1.0, 1.5);

    // Only six preview cards: intrinsic cross-axis sizing avoids guessed heights
    // that clip wrapped text. Width stays bounded instead of filling tablets.
    Widget strip(String name, double width, List<Widget> cards) =>
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: PageStorageKey('home-preview-$name'),
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SizedBox(
                      width: (width * scale).clamp(1, constraints.maxWidth),
                      child: cards[i],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

    return RefreshIndicator(
      color: HomeAppColors.navy,
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (widget.showWelcomeGreeting) ...[
            Text(
              widget.firstName.trim().isEmpty
                  ? 'Welcome to CampusHub'
                  : 'Welcome Back, ${widget.firstName.trim()}',
              style: InterTypography.text(
                color: HomeAppColors.navy,
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.showPromotionalBanners)
            CampusHomeBanners(
              active: widget.active,
              onMarketplace: widget.onMarketplace,
              onFacilities: widget.onFacilities,
              onServices: widget.onServices,
            ),
          if (widget.sellerSections != null) ...[
            widget.sellerSections!,
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'EXPLORE CAMPUSHUB',
                style: InterTypography.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: HomeAppColors.secondaryText,
                ),
              ),
            ),
          ],
          _section<ProductItem>(
            title: 'Marketplace',
            future: _products,
            onAll: widget.onMarketplace,
            retry: () => setState(() {
              _products = _readProducts();
            }),
            empty: 'No marketplace products are available right now.',
            content: (rows) => strip('marketplace', 176, [
              for (final row in rows.take(6)) widget.productBuilder(row),
            ]),
          ),
          _section<FacilityItem>(
            title: 'Facilities',
            future: _facilities,
            onAll: widget.onFacilities,
            retry: () => setState(() {
              _facilities = _readFacilities();
            }),
            empty: 'No facilities are currently listed.',
            content: (rows) => strip('facilities', 320, [
              for (final row in rows.take(6))
                FacilityPreviewCard(facility: row),
            ]),
          ),
          _section<ServiceItem>(
            title: 'Services',
            future: _services,
            onAll: widget.onServices,
            retry: () => setState(() {
              _services = _readServices();
            }),
            empty: 'No services are currently available.',
            content: (rows) => strip('services', 320, [
              for (final row in rows.take(6))
                ServicePreviewCard(service: row, catalog: widget.catalog),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HomeAppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HomeAppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: InterTypography.text(
            color: HomeAppColors.secondaryText,
            height: 1.5,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: HomeAppColors.navy),
            child: Text(
              'Retry',
              style: InterTypography.text(
                fontWeight: FontWeight.w600,
                color: HomeAppColors.navy,
              ),
            ),
          ),
      ],
    ),
  );
}
