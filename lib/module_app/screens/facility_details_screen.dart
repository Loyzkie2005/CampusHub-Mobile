import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/facility_detail_information.dart';
import '../models/facility_item.dart';
import '../services/facility_booking_service.dart';
import '../services/facility_service.dart';
import '../widgets/facilities/booking_widgets.dart';
import '../widgets/facilities/facility_status_badge.dart';
import '../widgets/product_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'facilities/facility_booking_screen.dart';

// Saved-photo carousel and continuous facility information with the original
// request action. Django remains the authority for all quotes.
// Scoped to Details: preserve the rest of the app's current typography/palette.
const _facilityDetailFont = 'Montserrat';
const _facilityDetailGold = Color(0xFFFCB316);
const _facilityControlSurface = Color(0xFFF5F6FA);
const _facilityMuted = Color(0xFF50596D);
const _facilityOutline = Color(0xFFE3E5ED);

/// Saved facility information and the existing request-booking destination.
class FacilityDetailsScreen extends StatefulWidget {
  const FacilityDetailsScreen({
    super.key,
    required this.facility,
    this.service = const FacilityBookingService(),
    this.loadFacilities = FacilityService.fetchFacilities,
  });
  final FacilityItem facility;
  final FacilityBookingService service;
  final Future<FacilityServiceResult> Function() loadFacilities;

  @override
  State<FacilityDetailsScreen> createState() => _FacilityDetailsScreenState();
}

class _FacilityDetailsScreenState extends State<FacilityDetailsScreen> {
  bool _favorite = false;
  int _currentImageIndex = 0;
  bool _ratesExpanded = false;
  final PageController _pageController = PageController();
  late FacilityItem _facility = widget.facility;
  FacilityItem get facility => _facility;
  bool _refreshing = false;
  String? _refreshError;

  @override
  void didUpdateWidget(covariant FacilityDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.facility != oldWidget.facility) {
      _facility = widget.facility;
      _refreshError = null;
    }
  }

  Future<void> _refreshFacility() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    FacilityItem? updated;
    String? error;
    try {
      final result = await widget.loadFacilities();
      if (result.success) {
        final row = result.facilities
            .where((item) => item['id'].toString() == facility.id)
            .firstOrNull;
        if (row != null) {
          updated = FacilityItem.fromJson(row);
        } else {
          error = 'This facility is no longer listed. Booking is unavailable.';
        }
      } else {
        error =
            result.message ??
            'Could not refresh facility status. Pull down to retry.';
      }
    } catch (_) {
      error = 'Could not refresh facility status. Pull down to retry.';
    }
    if (!mounted) return;
    setState(() {
      if (updated != null) _facility = updated;
      _refreshError = error;
      _refreshing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorite() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _favorite =
            preferences.getBool('facility_favorite_${facility.id}') ?? false,
      );
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favorite = !_favorite);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('facility_favorite_${facility.id}', _favorite);
  }

  Future<void> _book() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FacilityBookingScreen(facility: facility, service: widget.service),
      ),
    );
  }

  VoidCallback? get _requestAction =>
      _refreshing || _refreshError != null || !facility.isOpenForBooking
      ? null
      : facility.supportsSlotBooking
      ? _book
      : () => messageFacilitiesAdmin(context, facility.id);

  @override
  Widget build(BuildContext context) {
    final information = FacilityDetailInformation(facility);
    final base = Theme.of(context);
    final images = facility.allImageUrls;
    final operatingDayLabels = information.operatingDays
        .map((day) => day.label)
        .toSet();
    final theme = base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      textTheme: base.textTheme.apply(
        fontFamily: _facilityDetailFont,
        bodyColor: bookingNavy,
        displayColor: bookingNavy,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: _facilityDetailFont,
      ),
      colorScheme: const ColorScheme.light(
        primary: bookingNavy,
        secondary: _facilityDetailGold,
        surface: Colors.white,
        onSurface: bookingNavy,
        onSurfaceVariant: _facilityMuted,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: bookingNavy,
          minimumSize: const Size(48, 48),
          textStyle: _detailText(13, weight: FontWeight.w600),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: _refreshFacility,
            child: ListView(
              key: const ValueKey('facility-details-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _FacilityHeroGallery(
                  images: images,
                  currentIndex: _currentImageIndex,
                  controller: _pageController,
                  fallbackIcon: facility.icon,
                  favorite: _favorite,
                  onFavorite: _toggleFavorite,
                  onPageChanged: (index) =>
                      setState(() => _currentImageIndex = index),
                ),
                _FacilityInformationSurface(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _overview(information),
                            if (_refreshError != null ||
                                !facility.isOpenForBooking)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _refreshError ??
                                      facility.bookingStatusExplanation,
                                  key: const ValueKey(
                                    'facility-booking-status-explanation',
                                  ),
                                  style: _detailText(13),
                                ),
                              ),
                            const SizedBox(height: 24),
                            _rentalRates(information),
                            if (facility.amenities.any(
                              (item) => item.trim().isNotEmpty,
                            ))
                              _DetailSection(
                                key: const ValueKey('facility-amenities-card'),
                                title: 'Features & Amenities',
                                child: _Amenities(
                                  amenities: facility.amenities
                                      .where((item) => item.trim().isNotEmpty)
                                      .toList(),
                                ),
                              ),
                            if (facility.description.trim().isNotEmpty)
                              _DetailSection(
                                key: const ValueKey('facility-about-card'),
                                title: 'About This Facility',
                                child: _ExpandableDetailText(
                                  text: facility.description,
                                ),
                              ),
                            _DetailSection(
                              key: const ValueKey('facility-availability-card'),
                              title: 'Operating Schedule',
                              titleIcon: Icons.calendar_today_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _OperatingScheduleCard(
                                    information: information,
                                  ),
                                  for (final row in information.schedule.where(
                                    (row) => [
                                      'Operating hours',
                                      'Check-in',
                                      'Check-out',
                                    ].contains(row.label),
                                  ))
                                    _DetailLine(
                                      label: row.label,
                                      value: row.value,
                                    ),
                                ],
                              ),
                            ),
                            if (facility.requirements.trim().isNotEmpty ||
                                information.schedule.any(
                                  (row) =>
                                      !operatingDayLabels.contains(row.label) &&
                                      ![
                                        'Operating hours',
                                        'Check-in',
                                        'Check-out',
                                      ].contains(row.label),
                                ))
                              _DetailSection(
                                key: const ValueKey(
                                  'facility-guidelines-section',
                                ),
                                title: 'Booking Guidelines',
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (facility.requirements.trim().isNotEmpty)
                                      _ExpandableDetailText(
                                        text: facility.requirements,
                                      ),
                                    for (final row
                                        in information.schedule.where(
                                          (row) =>
                                              !operatingDayLabels.contains(
                                                row.label,
                                              ) &&
                                              ![
                                                'Operating hours',
                                                'Check-in',
                                                'Check-out',
                                              ].contains(row.label),
                                        ))
                                      _DetailLine(
                                        label: row.label,
                                        value: row.value,
                                      ),
                                  ],
                                ),
                              ),
                            if (facility.termsConditions.trim().isNotEmpty)
                              _DetailSection(
                                key: const ValueKey('facility-rules-card'),
                                title: 'Terms & Conditions',
                                child: _ExpandableDetailText(
                                  text: facility.termsConditions,
                                  disclosureLabel: 'terms and conditions',
                                ),
                              ),
                            _DetailSection(
                              key: const ValueKey('facility-reviews-section'),
                              title: 'Reviews & Ratings',
                              child:
                                  information.reviewSummary == 'No reviews yet'
                                  ? _IconDetail(
                                      icon: Icons.star_outline_rounded,
                                      text: 'No reviews yet',
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _IconDetail(
                                          icon: Icons.star_outline_rounded,
                                          text: information.reviewSummary,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Customer feedback is not available.',
                                          style: _detailText(
                                            14,
                                            color: _facilityMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _FacilityBookingBar(
            onChat: () => messageFacilitiesAdmin(context, facility.id),
            showBookingAction: facility.supportsSlotBooking,
            onPressed: _requestAction,
          ),
        ),
      ),
    );
  }

  Widget _rentalRates(FacilityDetailInformation information) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final details = _ratesExpanded
        ? _rateDetails(information)
        : const SizedBox.shrink();
    return Padding(
      key: const ValueKey('facility-rates-section'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Material(
        color: _facilityControlSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _facilityOutline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Rental rates',
              expanded: _ratesExpanded,
              child: InkWell(
                key: const ValueKey('facility-rates-toggle'),
                onTap: () => setState(() => _ratesExpanded = !_ratesExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RentalPrice(
                          key: const ValueKey('facility-primary-rate'),
                          price: information.primaryRate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      AnimatedRotation(
                        turns: _ratesExpanded ? .5 : 0,
                        duration: duration,
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: bookingNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // A direct update also avoids zero-duration layout animation work.
            if (reduceMotion)
              details
            else
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: details,
              ),
          ],
        ),
      ),
    );
  }

  Widget _rateDetails(FacilityDetailInformation information) => Padding(
    key: const ValueKey('facility-rate-details'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailLine(label: 'Rental rate', value: information.primaryRate),
        for (final row in information.rateOptions)
          _DetailLine(label: row.label, value: row.value),
        if (information.customPricing.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ExpandableDetailText(text: information.customPricing),
        ],
        if (facility.priceType == 'base_hour' &&
            information.rateOptions.any(
              (row) => row.label == 'Alternative hourly rate',
            ))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'The hourly option is an alternative to the base package.',
              style: _detailText(12, color: _facilityMuted),
            ),
          ),
      ],
    ),
  );
  Widget _overview(FacilityDetailInformation information) {
    return Padding(
      key: const ValueKey('facility-main-info-card'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                facility.name,
                key: const ValueKey('facility-name'),
                style: _detailText(
                  26,
                  weight: FontWeight.w700,
                ).copyWith(height: 1.15, letterSpacing: -.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FacilityStatusBadge(
            key: const ValueKey('facility-status-badge'),
            status: facility.status,
            fontFamily: _facilityDetailFont,
          ),
          if (facility.location.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _IconDetail(
              icon: Icons.location_on_outlined,
              text: facility.location,
              iconColor: bookingNavy,
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final review = _IconDetail(
                key: const ValueKey('facility-header-review'),
                icon: Icons.star_outline_rounded,
                text: information.reviewSummary,
                iconColor: _facilityDetailGold,
              );
              final capacity = _IconDetail(
                icon: Icons.people_outline_rounded,
                text: information.capacity,
                iconColor: bookingNavy,
              );
              if (information.capacity.isEmpty) return review;
              if (constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [review, const SizedBox(height: 10), capacity],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: review),
                  const SizedBox(width: 16),
                  Expanded(child: capacity),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

TextStyle _detailText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = bookingNavy,
}) => TextStyle(
  fontFamily: _facilityDetailFont,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  height: 1.45,
  color: color,
);

/// Opaque white keeps the information clear in either parent theme.
class _FacilityInformationSurface extends StatelessWidget {
  const _FacilityInformationSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('facility-information-surface'),
    color: Colors.white,
    child: child,
  );
}

class _FacilityHeroGallery extends StatelessWidget {
  const _FacilityHeroGallery({
    required this.images,
    required this.currentIndex,
    required this.controller,
    required this.fallbackIcon,
    required this.favorite,
    required this.onFavorite,
    required this.onPageChanged,
  });
  final List<String> images;
  final int currentIndex;
  final PageController controller;
  final IconData fallbackIcon;
  final bool favorite;
  final VoidCallback onFavorite;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final topInset = MediaQuery.paddingOf(context).top;
      final photoHeight = constraints.maxWidth.clamp(300.0, 420.0) + topInset;
      final dotCount = images.length.clamp(0, 5);
      final firstDot = (currentIndex - 2).clamp(0, images.length - dotCount);
      return SizedBox(
        key: const ValueKey('facility-hero-gallery'),
        height: photoHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.isEmpty ? 1 : images.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) => Semantics(
                image: true,
                label: images.isEmpty
                    ? 'No facility photo provided'
                    : 'Facility photo ${index + 1} of ${images.length}',
                child: ProductImage(
                  imageUrl: images.isEmpty ? '' : images[index],
                  fallbackIcon: fallbackIcon,
                  fallbackColor: _facilityMuted,
                  fallbackSize: 44,
                  backgroundColor: _facilityControlSurface,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (
                        var index = firstDot;
                        index < firstDot + dotCount;
                        index++
                      )
                        AnimatedContainer(
                          key: ValueKey('facility-carousel-dot-$index'),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          width: index == currentIndex ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == currentIndex
                                ? _facilityDetailGold
                                : Colors.white.withValues(alpha: .38),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: topInset + 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GalleryButton(
                    tooltip: 'Back',
                    icon: Icons.chevron_left_rounded,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  _GalleryButton(
                    key: const ValueKey('facility-bookmark-button'),
                    tooltip: favorite
                        ? 'Remove saved facility'
                        : 'Save facility',
                    icon: Icons.bookmark_border_rounded,
                    selectedIcon: Icons.bookmark_rounded,
                    selected: favorite,
                    onPressed: onFavorite,
                  ),
                ],
              ),
            ),
            if (images.length > 1) ...[
              Positioned(
                left: 12,
                top: (photoHeight - 48) / 2,
                child: _GalleryButton(
                  tooltip: 'Previous facility photo',
                  icon: Icons.chevron_left_rounded,
                  onPressed: currentIndex > 0
                      ? () => controller.jumpToPage(currentIndex - 1)
                      : null,
                ),
              ),
              Positioned(
                right: 12,
                top: (photoHeight - 48) / 2,
                child: _GalleryButton(
                  tooltip: 'Next facility photo',
                  icon: Icons.chevron_right_rounded,
                  onPressed: currentIndex < images.length - 1
                      ? () => controller.jumpToPage(currentIndex + 1)
                      : null,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Neutral, opaque backing keeps photo controls readable without blur.
class _PhotoControlSurface extends StatelessWidget {
  const _PhotoControlSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: shape,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _facilityControlSurface,
          borderRadius: shape,
        ),
        child: child,
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selectedIcon,
    this.selected = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final IconData? selectedIcon;
  final bool selected;

  @override
  Widget build(BuildContext context) => _PhotoControlSurface(
    child: IconButton(
      tooltip: tooltip,
      isSelected: selectedIcon != null ? selected : null,
      selectedIcon: selectedIcon != null ? Icon(selectedIcon) : null,
      icon: Icon(icon),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: bookingNavy,
        disabledForegroundColor: _facilityMuted,
        minimumSize: const Size(48, 48),
        shape: const CircleBorder(),
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.titleIcon,
  });
  final String title;
  final Widget child;
  final IconData? titleIcon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (titleIcon != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ExcludeSemantics(
                            child: Icon(
                              titleIcon,
                              size: 18,
                              color: bookingNavy,
                            ),
                          ),
                        ),
                      ),
                    TextSpan(text: title),
                  ],
                ),
                style: _detailText(
                  16,
                  weight: FontWeight.w600,
                  color: bookingNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// Saved operating days; markers and grouped rows repeat the same actual hours.
class _OperatingScheduleCard extends StatelessWidget {
  const _OperatingScheduleCard({required this.information});
  final FacilityDetailInformation information;

  @override
  Widget build(BuildContext context) {
    final days = information.operatingDays;
    if (days.isEmpty) {
      return Text(
        'Operating days are not configured.',
        style: _detailText(13, color: _facilityMuted),
      );
    }
    final groups = <({String label, String value})>[];
    for (var i = 0; i < days.length; i++) {
      final first = i;
      // Group matching consecutive weekdays; keep Saturday/Sunday distinct.
      while (i < 4 && days[i + 1].value == days[first].value) {
        i++;
      }
      groups.add((
        label: first == i
            ? days[first].label
            : '${days[first].label} – ${days[i].label}',
        value: days[first].value,
      ));
    }
    return Container(
      key: const ValueKey('facility-operating-days'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _facilityOutline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Operating Days',
                style: _detailText(13, weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Semantics(
                    label: '${day.label}: ${day.value}',
                    child: ExcludeSemantics(
                      child: Container(
                        key: ValueKey(
                          'facility-operating-${day.label.toLowerCase()}',
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: day.isOpen == true
                              ? _facilityControlSurface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.label[0],
                          textAlign: TextAlign.center,
                          style: _detailText(
                            12,
                            color: day.isOpen == true
                                ? bookingNavy
                                : _facilityMuted,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final group in groups)
            _DetailLine(label: group.label, value: group.value),
        ],
      ),
    );
  }
}

/// One spoken rate; weight and scale separate the amount from its billing basis.
class _RentalPrice extends StatelessWidget {
  const _RentalPrice({super.key, required this.price});
  final String price;

  @override
  Widget build(BuildContext context) {
    final separator = price.startsWith('₱') ? price.indexOf(' / ') : -1;
    final amount = separator < 0 ? price : price.substring(0, separator);
    final basis = separator < 0 ? '' : price.substring(separator + 1);
    return Semantics(
      label: price,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amount,
            style: _detailText(
              30,
              weight: FontWeight.w700,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(basis, style: _detailText(13, color: _facilityMuted)),
          ],
        ],
      ),
    );
  }
}

class _IconDetail extends StatelessWidget {
  const _IconDetail({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = _facilityMuted,
  });
  final IconData icon;
  final String text;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: ExcludeSemantics(child: Icon(icon, size: 18, color: iconColor)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: _detailText(14, color: _facilityMuted)),
      ),
    ],
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: _detailText(
            13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
        final stacked =
            constraints.maxWidth < 250 ||
            value.length > 54 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final valueWidget = Text(
          value,
          textAlign: stacked ? TextAlign.start : TextAlign.end,
          style: _detailText(
            13,
            weight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 3), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: 16),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}

class _ExpandableDetailText extends StatefulWidget {
  const _ExpandableDetailText({required this.text, this.disclosureLabel});
  final String text;
  final String? disclosureLabel;
  @override
  State<_ExpandableDetailText> createState() => _ExpandableDetailTextState();
}

class _ExpandableDetailTextState extends State<_ExpandableDetailText> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = _detailText(
        14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 4,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: expanded ? null : 4,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          if (overflows)
            Semantics(
              expanded: expanded,
              child: TextButton(
                onPressed: () => setState(() => expanded = !expanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        expanded
                            ? 'Read Less'
                            : widget.disclosureLabel != null
                            ? 'Read Full Terms'
                            : 'Read More',
                      ),
                    ),
                    if (widget.disclosureLabel == null) ...[
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Amenities extends StatelessWidget {
  const _Amenities({required this.amenities});
  final List<String> amenities;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final width = amenities.length <= 4 && scale <= 1.3
          ? constraints.maxWidth / amenities.length
          : 104.0 * scale.clamp(1.0, 1.5);
      return SingleChildScrollView(
        key: const ValueKey('facility-amenities-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final amenity in amenities)
              SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _facilityControlSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _facilityOutline),
                        ),
                        child: ExcludeSemantics(
                          child: Icon(
                            iconForAmenity(amenity),
                            size: 23,
                            color: bookingNavy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        amenity,
                        textAlign: TextAlign.center,
                        style: _detailText(12, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _FacilityBookingBar extends StatelessWidget {
  const _FacilityBookingBar({
    required this.onChat,
    required this.showBookingAction,
    this.onPressed,
  });
  final VoidCallback onChat;
  final bool showBookingAction;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBookingAction) ...[
                    Expanded(
                      child: Tooltip(
                        message: 'Chat with Facilities Admin',
                        child: OutlinedButton(
                          key: const ValueKey('facility-chat-button'),
                          onPressed: onChat,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: bookingNavy,
                            elevation: 0,
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            side: const BorderSide(color: bookingNavy, width: 1.2),
                            shape: const StadiumBorder(),
                            textStyle: _detailText(14, weight: FontWeight.w600),
                          ),
                          child:
                              MediaQuery.sizeOf(context).width < 340 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.messageCircle, size: 19),
                                    SizedBox(height: 4),
                                    Text('Chat'),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.messageCircle, size: 19),
                                    SizedBox(width: 8),
                                    Text('Chat'),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('facility-request-booking-button'),
                      // Non-slot requests already use office messaging. Keep
                      // the former header Chat access when booking is closed.
                      onPressed: showBookingAction ? onPressed : onChat,
                      style: FilledButton.styleFrom(
                        backgroundColor: _facilityDetailGold,
                        foregroundColor: bookingNavy,
                        disabledBackgroundColor: _facilityControlSurface,
                        disabledForegroundColor: _facilityMuted,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: _detailText(
                          14,
                          weight: FontWeight.w600,
                          color: bookingNavy,
                        ),
                      ),
                      child: showBookingAction
                          ? const Text(
                              'Request Booking',
                              textAlign: TextAlign.center,
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.messageCircle, size: 19),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Message Admin',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
