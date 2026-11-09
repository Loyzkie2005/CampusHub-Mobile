import 'package:campushub/module_app/theme/app_typography.dart';
import 'dart:math' as math;
import 'dart:async';

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
import 'seller_demo_bundle_page.dart';
import '../services/demo_bundle_store.dart';

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
    this.afterSalesTrend,
    this.afterInventoryAlerts,
    this.initialRecommendationSource = 'live',
    this.onRecommendationSourceChanged,
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
  final Widget? afterSalesTrend;
  final Widget? afterInventoryAlerts;
  final String initialRecommendationSource;
  final ValueChanged<String>? onRecommendationSourceChanged;
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
  bool _salesLoading = false;
  String? _salesError;
  int _salesRequest = 0;
  String _period = '7';
  bool _productSearchOpen = false;
  int _ordersPage = 1, _request = 0;
  Map<String, dynamic> _data = {};
  AuthUser? _profileUser;
  bool _recommendationsLoading = false;
  int _recommendationRequest = 0;
  final _sectionRequests = <String, int>{};
  final _sectionLoading = <String>{};

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
    final sourceChanged =
        widget.initialRecommendationSource !=
        oldWidget.initialRecommendationSource;
    if (widget.user.id != oldWidget.user.id ||
        (widget.homeSection &&
            (widget.refreshRevision != oldWidget.refreshRevision ||
                sourceChanged))) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    ++_recommendationRequest;
    ++_salesRequest; // A full refresh supersedes any pending sales-only request.
    setState(() {
      _loading = true;
      _error = null;
      _salesLoading = false;
      _salesError = null;
      _recommendationsLoading = false;
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
      _readAnalytics(data['analytics'], _period);
      final overview = data['overview'];
      bool validCount(Object? value) => value is int && value >= 0;
      if (data['products'] is! List ||
          data['inventory'] is! List ||
          data['orders'] is! List ||
          !validCount(data['order_count']) ||
          overview is! Map ||
          !validCount(overview['completed_orders']) ||
          !validCount(overview['pending_orders']) ||
          data['recommendations'] is! Map ||
          data['saved_suggestions'] is! List) {
        throw const SellerApplicationException(
          'The seller workspace returned an unreadable response. Retry.',
        );
      }
      if (mounted && request == _request) {
        setState(() {
          _sectionLoading.clear();
          _data = {
            ...data,
            'recommendation_sections': {'live': data['recommendations']},
          };
        });
        unawaited(_refreshRecommendations('admin'));
        unawaited(_refreshRecommendations('synthetic'));
      }
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
    if (!{'day', '7', 'month'}.contains(value) ||
        (value == _period && _salesError == null)) {
      return;
    }
    _refreshSales(value);
  }

  Map<String, dynamic> _readAnalytics(Object? value, String period) {
    final revenue = value is Map ? num.tryParse('${value['revenue']}') : null;
    if (value is! Map ||
        value['period'] != period ||
        value['label'] is! String ||
        (value['label'] as String).trim().isEmpty ||
        revenue == null ||
        !revenue.isFinite ||
        revenue < 0 ||
        value['completed_orders'] is! int ||
        (value['completed_orders'] as int) < 0) {
      throw const SellerApplicationException(
        'The seller workspace returned an unreadable response. Retry.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  Future<void> _refreshSales(String period) async {
    if (_loading || !_approved || _data.isEmpty) return;
    final request = ++_salesRequest;
    final fullRequest = _request;
    final userId = widget.user.id;
    setState(() {
      _period = period;
      _salesLoading = true;
      _salesError = null;
    });
    bool current() =>
        mounted &&
        request == _salesRequest &&
        fullRequest == _request &&
        widget.user.id == userId;
    try {
      // This endpoint already authenticates and enforces active seller access.
      final response = await widget.service.workspace(
        period: period,
        ordersPage: _ordersPage,
      );
      if (!current()) return;
      final analytics = _readAnalytics(response['analytics'], period);
      setState(() => _data = {..._data, 'analytics': analytics});
    } catch (error) {
      if (!mounted || widget.user.id != userId) return;
      if (error is SellerApplicationException &&
          [401, 403].contains(error.statusCode)) {
        // Even a late authorization denial must not leave seller data visible.
        ++_request;
        ++_salesRequest;
        setState(() {
          _approved = false;
          _data = {};
          _loading = false;
          _salesLoading = false;
          _salesError = null;
          _error = error.message;
        });
      } else if (current()) {
        setState(
          () => _salesError = error is SellerApplicationException
              ? error.message
              : 'Unable to refresh sales. Check your connection and retry.',
        );
      }
    } finally {
      if (current()) setState(() => _salesLoading = false);
    }
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
    final actor = widget.user.id;
    final workspaceRequest = _request;
    final recommendationRequest = _recommendationRequest;
    if (pair['source'] == 'synthetic') {
      if (!_approved || !DemoBundleStore.validPair(pair)) return;
      final store = DemoBundleStore(actor);
      try {
        final saved = await store.find(pair);
        if (!mounted ||
            actor != widget.user.id ||
            workspaceRequest != _request ||
            recommendationRequest != _recommendationRequest) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SellerDemoBundlePage(
              pair: saved == null
                  ? pair
                  : Map<String, dynamic>.from(saved['recommendation']),
              store: store,
              saved: saved,
            ),
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to read demo storage. Please retry.'),
            ),
          );
        }
      }
      return;
    }
    Map<String, dynamic> verified;
    try {
      verified = await widget.service.recommendationAction(
        pair,
        pair['source'] == 'admin' && pair['status'] == 'pending'
            ? 'accept'
            : 'validate',
      );
    } catch (error) {
      if (mounted) {
        if (error is SellerApplicationException &&
            [401, 403].contains(error.statusCode)) {
          ++_request;
          ++_recommendationRequest;
          ++_salesRequest;
          setState(() {
            _approved = false;
            _data = {};
            _loading = false;
            _error = error.message;
            _sectionLoading.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is SellerApplicationException
                    ? error.message
                    : 'Unable to verify these products. Retry.',
              ),
            ),
          );
        }
      }
      return;
    }
    if (!mounted ||
        actor != widget.user.id ||
        workspaceRequest != _request ||
        recommendationRequest != _recommendationRequest) {
      return;
    }
    final products = (verified['products'] as List? ?? [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final ids = products.map((p) => '${p['id']}').toSet();
    if (pair['source'] == 'admin') {
      _updateAdminDecision(pair, '${verified['status'] ?? 'accepted'}');
    }
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
          pairId: '${verified['id']}',
          source: '${verified['source'] ?? 'live'}',
          revision: verified['revision'] as String?,
          products: products,
          service: widget.service,
        ),
      ),
    );
    if (submitted == true && mounted) {
      if (widget.homeSection) {
        widget.onOpenDestination?.call(SellerDestination.products);
      }
      setState(() => _selected = SellerDestination.products);
      await _load();
    }
  }

  Future<void> _refreshRecommendations(String source) async {
    if (!{'admin', 'live', 'synthetic'}.contains(source)) return;
    final generation = (_sectionRequests[source] ?? 0) + 1;
    _sectionRequests[source] = generation;
    final workspaceRequest = _request;
    setState(() {
      _sectionLoading.add(source);
    });
    try {
      final result = await widget.service.recommendations(source);
      if (result['rows'] is! List ||
          result['source'] != source ||
          result['error'] is! bool) {
        throw const SellerApplicationException(
          'Unreadable recommendations. Retry.',
        );
      }
      if (mounted &&
          generation == _sectionRequests[source] &&
          workspaceRequest == _request) {
        setState(
          () => _data = {
            ..._data,
            'recommendation_sections': {
              ...?_data['recommendation_sections'] as Map?,
              source: result,
            },
          },
        );
      }
    } catch (error) {
      if (mounted &&
          generation == _sectionRequests[source] &&
          workspaceRequest == _request) {
        if (error is SellerApplicationException &&
            [401, 403].contains(error.statusCode)) {
          ++_request;
          ++_recommendationRequest;
          ++_salesRequest;
          setState(() {
            _approved = false;
            _data = {};
            _loading = false;
            _error = error.message;
            _sectionLoading.clear();
          });
        } else {
          setState(
            () => _data = {
              ..._data,
              'recommendation_sections': {
                ...?_data['recommendation_sections'] as Map?,
                source: {'source': source, 'rows': [], 'error': true},
              },
            },
          );
        }
      }
    } finally {
      if (mounted &&
          generation == _sectionRequests[source] &&
          workspaceRequest == _request) {
        setState(() => _sectionLoading.remove(source));
      }
    }
  }

  Future<void> _dismissRecommendation(Map<String, dynamic> row) async {
    final workspaceRequest = _request;
    final recommendationRequest = _recommendationRequest;
    try {
      await widget.service.recommendationAction(row, 'dismiss');
    } on SellerApplicationException catch (error) {
      if ([401, 403].contains(error.statusCode) && mounted) await _load();
      rethrow;
    }
    if (!mounted ||
        workspaceRequest != _request ||
        recommendationRequest != _recommendationRequest) {
      return;
    }
    final source = '${row['source'] ?? 'live'}';
    final sections = Map<String, dynamic>.from(
      _data['recommendation_sections'] as Map? ?? {},
    );
    final recommendations = Map<String, dynamic>.from(
      sections[source] as Map? ?? _data['recommendations'] as Map,
    );
    recommendations['rows'] = (recommendations['rows'] as List)
        .where((item) => item['id'] != row['id'])
        .toList();
    sections[source] = recommendations;
    setState(() => _data = {..._data, 'recommendation_sections': sections});
  }

  void _updateAdminDecision(Map<String, dynamic> pair, String status) {
    _sectionRequests['admin'] = (_sectionRequests['admin'] ?? 0) + 1;
    _sectionLoading.remove('admin');
    final sections = Map<String, dynamic>.from(
      _data['recommendation_sections'] as Map? ?? {},
    );
    final admin = Map<String, dynamic>.from(sections['admin'] as Map? ?? {});
    admin['rows'] = [
      for (final row in admin['rows'] as List? ?? [])
        if (row['id'] == pair['id'])
          {...row as Map, 'status': status, 'can_create': status == 'accepted'}
        else
          row,
    ];
    sections['admin'] = admin;
    setState(() => _data = {..._data, 'recommendation_sections': sections});
  }

  Future<void> _declineRecommendation(Map<String, dynamic> pair) async {
    final request = _request;
    try {
      final result = await widget.service.recommendationAction(pair, 'decline');
      if (mounted && request == _request) {
        _updateAdminDecision(pair, '${result['status']}');
      }
    } on SellerApplicationException catch (error) {
      if ([401, 403].contains(error.statusCode) && mounted) await _load();
      rethrow;
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
                  onDismissRecommendation: _dismissRecommendation,
                  onDeclineRecommendation: _declineRecommendation,
                  recommendationLoadingSources: _sectionLoading,
                  onRecommendationSource: _refreshRecommendations,
                  recommendationsLoading: _recommendationsLoading,
                  onAddProduct: () {},
                  onReload: _load,
                  onOrderProgress: widget.service.orderProgress,
                  onPeriod: _changePeriod,
                  salesRefreshing: _salesLoading,
                  salesError: _salesError,
                  onSalesRetry: () => _refreshSales(_period),
                  onOrdersPage: (_) {},
                  homeHighlightsOnly: true,
                  afterSalesTrend:
                      widget.afterSalesTrend ?? widget.afterInventoryAlerts,
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
                              onDismissRecommendation: _dismissRecommendation,
                              onDeclineRecommendation: _declineRecommendation,
                              recommendationLoadingSources: _sectionLoading,
                              onRecommendationSource: _refreshRecommendations,
                              recommendationsLoading: _recommendationsLoading,
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
                              salesRefreshing: _salesLoading,
                              salesError: _salesError,
                              onSalesRetry: () => _refreshSales(_period),
                              onOrdersPage: (value) {
                                _ordersPage = value;
                                _load();
                              },
                              afterSalesTrend:
                                  widget.afterSalesTrend ??
                                  widget.afterInventoryAlerts,
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
