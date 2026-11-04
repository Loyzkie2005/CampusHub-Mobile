import 'package:campushub/module_app/theme/app_typography.dart';
import 'dart:math' as math;

import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/seller_application_service.dart';
import '../widgets/home/home_preview_cards.dart';
import '../widgets/navigation/seller_drawer.dart';
import '../widgets/profile/profile_widgets.dart';
import 'products_screen.dart';
import 'messages_screen.dart';
import 'profile_page.dart';
import '../widgets/navigation/header_search_button.dart';
import '../widgets/navigation/header_profile_button.dart';
import 'profile_details_pages.dart';
import 'facilities/facility_booking_history_screen.dart';
import 'seller_workspace_content.dart';
import 'seller_bundle_form.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({
    super.key,
    required this.user,
    this.service = const SellerApplicationService(),
    this.onBackToCampusHub,
    this.onMessages,
    this.onProfile,
    this.onNotifications,
    this.onSearch,
    this.homeSection = false,
    this.initialDestination = SellerDestination.overview,
    this.onOpenDestination,
    this.refreshRevision = 0,
    this.afterInventoryAlerts,
  });
  final AuthUser user;
  final SellerApplicationService service;
  final VoidCallback? onBackToCampusHub,
      onMessages,
      onNotifications,
      onProfile,
      onSearch;
  final bool homeSection;
  final SellerDestination initialDestination;
  final ValueChanged<SellerDestination>? onOpenDestination;
  final int refreshRevision;
  final Widget? afterInventoryAlerts;
  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage>
    with AutomaticKeepAliveClientMixin {
  // Home's lazy ListView must not reload seller data when scrolling past it.
  @override
  bool get wantKeepAlive => widget.homeSection;

  final _scaffold = GlobalKey<ScaffoldState>();
  SellerDestination _selected = SellerDestination.overview;
  bool _loading = true, _approved = false;
  String? _error;
  String _period = '7';
  bool _productSearchOpen = false;
  int _ordersPage = 1, _request = 0;
  Map<String, dynamic> _data = {};
  AuthUser? _profileUser;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDestination;
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) _profileUser = null;
    if (widget.homeSection &&
        widget.refreshRevision != oldWidget.refreshRevision) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.service.status();
      if (!mounted || request != _request) return;
      if (status['is_approved_seller'] != true) {
        setState(() {
          _approved = false;
          _data = {};
        });
        throw const SellerApplicationException(
          'Approved active seller access is required.',
        );
      }
      setState(() => _approved = true);
      final data = await widget.service.workspace(
        period: _period,
        ordersPage: _ordersPage,
      );
      if (data['products'] is! List ||
          data['inventory'] is! List ||
          data['orders'] is! List ||
          data['analytics'] is! Map ||
          data['recommendations'] is! Map ||
          data['saved_suggestions'] is! List) {
        throw const SellerApplicationException(
          'The seller workspace returned an unreadable response. Retry.',
        );
      }
      if (mounted && request == _request) setState(() => _data = data);
    } catch (error) {
      if (error is SellerApplicationException &&
          [401, 403].contains(error.statusCode) &&
          request == _request &&
          mounted) {
        setState(() {
          _approved = false;
          _data = {};
        });
      }
      if (mounted && request == _request) {
        setState(
          () => _error = error is SellerApplicationException
              ? error.message
              : 'Unable to load your seller workspace. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _changePeriod(String value) {
    if (value == _period) return;
    _period = value;
    _load();
  }

  void _backHome() {
    if (widget.onBackToCampusHub != null) {
      widget.onBackToCampusHub!();
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false);
  }

  void _openProfile() {
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    if (widget.onProfile != null) {
      widget.onProfile!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ProfilePage(
            onUserChanged: (user) {
              if (mounted && user.id == widget.user.id) {
                setState(() => _profileUser = user);
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _select(SellerDestination destination) async {
    if (widget.homeSection && widget.onOpenDestination != null) {
      widget.onOpenDestination!(destination);
      return;
    }
    if (_scaffold.currentState?.isDrawerOpen == true) Navigator.pop(context);
    if (!_approved) return;
    if (destination == SellerDestination.purchases ||
        destination == SellerDestination.bookings) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => destination == SellerDestination.purchases
              ? const ProfileOrdersPage()
              : const FacilityBookingHistoryScreen(),
        ),
      );
      return;
    }
    if (destination == SellerDestination.overview &&
        widget.onBackToCampusHub != null) {
      _backHome();
      return;
    }
    setState(() {
      _selected = destination;
      _productSearchOpen = false;
    });
    if (destination == SellerDestination.overview && _ordersPage != 1) {
      _ordersPage = 1;
      await _load();
    }
  }

  Future<void> _createBundle(Map<String, dynamic> pair) async {
    final ids = (pair['products'] as List).map((p) => '${p['id']}').toSet();
    final products = (_data['products'] as List)
        .whereType<Map>()
        .where((p) => ids.contains('${p['id']}'))
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    if (ids.length != 2 || products.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refresh this suggestion before creating a bundle.'),
        ),
      );
      return;
    }
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerBundleForm(
          pairId: '${pair['id']}',
          products: products,
          service: widget.service,
        ),
      ),
    );
    if (submitted == true && mounted) {
      if (widget.homeSection) {
        widget.onOpenDestination?.call(SellerDestination.bundles);
      }
      setState(() => _selected = SellerDestination.bundles);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.homeSection) {
      return ProfileTheme(
        child: Padding(
          key: const ValueKey('home-seller-sections'),
          padding: EdgeInsets.zero,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null || !_approved
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error ?? 'Unable to load seller overview.'),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )
              : SellerWorkspaceContent(
                  destination: SellerDestination.overview,
                  data: _data,
                  sellerFirstName: widget.user.firstName,
                  onNavigate: _select,
                  onCreateBundle: _createBundle,
                  onAddProduct: () {},
                  onReload: _load,
                  onOrderProgress: widget.service.orderProgress,
                  onPeriod: _changePeriod,
                  onOrdersPage: (_) {},
                  homeHighlightsOnly: true,
                  afterInventoryAlerts: widget.afterInventoryAlerts,
                ),
        ),
      );
    }
    return ProfileTheme(
      child: Scaffold(
        key: _scaffold,
        backgroundColor: Colors.white,
        drawer: _approved
            ? SellerDrawer(
                user: widget.user,
                selected: _selected,
                onSelected: _select,
                onBackToCampusHub: _backHome,
                onProfile: _openProfile,
              )
            : null,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: HomeAppColors.navy,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: _approved
              ? IconButton(
                  tooltip: 'Open seller menu',
                  icon: const Icon(
                    Iconsax.menu_1_copy,
                    color: HomeAppColors.navy,
                  ),
                  onPressed: () => _scaffold.currentState?.openDrawer(),
                )
              : BackButton(color: HomeAppColors.navy, onPressed: _backHome),
          toolbarHeight: math.max(
            kToolbarHeight,
            MediaQuery.textScalerOf(context).scale(14) * 3 + 8,
          ),
          title: HeaderProfileButton(
            user: _profileUser ?? widget.user,
            onPressed: _openProfile,
            avatarKey: const ValueKey('seller-header-profile-avatar'),
            nameKey: const ValueKey('seller-header-profile-name'),
          ),
          actions: [
            if (_selected == SellerDestination.products && _approved)
              IconButton(
                tooltip: _productSearchOpen
                    ? 'Close search'
                    : 'Search my products',
                icon: _productSearchOpen
                    ? Transform.rotate(
                        angle: math.pi / 4,
                        child: const Icon(
                          Iconsax.add_copy,
                          color: HomeAppColors.navy,
                        ),
                      )
                    : const Icon(
                        Iconsax.search_normal_1_copy,
                        color: HomeAppColors.navy,
                      ),

                onPressed: () {
                  if (_productSearchOpen) FocusScope.of(context).unfocus();
                  setState(() => _productSearchOpen = !_productSearchOpen);
                },
              )
            else
              HeaderSearchButton(onPressed: widget.onSearch),
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(
                Iconsax.notification_copy,
                color: HomeAppColors.navy,
              ),
              onPressed: widget.onNotifications,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selected != SellerDestination.overview &&
                _selected != SellerDestination.messages &&
                (_selected != SellerDestination.products ||
                    _loading ||
                    _error != null ||
                    !_approved))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    _selected.label,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: HomeAppColors.navy,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _approved && _selected == SellerDestination.messages
                  ? const MessagesPage()
                  : _approved && _selected == SellerDestination.settings
                  ? AccountSecurityPage(user: widget.user, embedded: true)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: HomeAppColors.navy,
                      child: _loading || _error != null || !_approved
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              children: [
                                if (_loading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: HomeAppColors.navy,
                                    ),
                                  )
                                else ...[
                                  Text(
                                    _error ??
                                        'Approved active seller access is required.',
                                  ),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                  TextButton(
                                    onPressed: _backHome,
                                    child: const Text('Back to CampusHub'),
                                  ),
                                ],
                              ],
                            )
                          : SellerWorkspaceContent(
                              destination: _selected,
                              productSearchOpen: _productSearchOpen,
                              data: _data,
                              sellerFirstName: widget.user.firstName,
                              onNavigate: _select,
                              onCreateBundle: _createBundle,
                              onAddProduct: () async {
                                await ProductsScreen.showAddProductPage(
                                  context,
                                  onViewProducts: () =>
                                      _select(SellerDestination.products),
                                  onBackHome: _backHome,
                                );
                                if (mounted) await _load();
                              },
                              onReload: _load,
                              onOrderProgress: widget.service.orderProgress,
                              onPeriod: _changePeriod,
                              onOrdersPage: (value) {
                                _ordersPage = value;
                                _load();
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
