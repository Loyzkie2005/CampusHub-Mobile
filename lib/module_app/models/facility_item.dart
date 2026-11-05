import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_config.dart';

export 'amenity_icon.dart' show iconForAmenity;

class FacilityItem {
  const FacilityItem({
    required this.id,
    required this.name,
    required this.facilityType,
    required this.facilityTypeLabel,
    required this.status,
    required this.capacity,
    required this.rate,
    required this.priceType,
    required this.bookingMode,
    required this.roomType,
    required this.slots,
    required this.rating,
    required this.reviews,
    required this.icon,
    required this.imageUrl,
    this.images = const [],
    this.capacityLabel = '',
    this.description = '',
    this.amenities = const [],
    this.requirements = '',
    this.termsConditions = '',
    this.location = '',
    this.jobOrderService = '',
    this.catalogPriceLabel = '',
    this.baseDurationHours,
    this.workflowConfig = const {},
    this.customFacilityType = '',
  });

  factory FacilityItem.fromJson(Map<String, dynamic> json) {
    final statusKey = (json['status'] as String? ?? '').trim().toLowerCase();
    final statusLabel = switch (statusKey) {
      'available' => 'Open for Booking',
      'unavailable' || 'reserved' || 'occupied' => 'Temporarily Unavailable',
      'maintenance' => 'Under Maintenance',
      'inactive' => 'Inactive',
      _ => 'Status unavailable',
    };

    final rawAmenities = json['amenities'];
    final amenities = rawAmenities is List
        ? rawAmenities.map((e) => e.toString()).toList()
        : <String>[];

    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    final name = json['name'] as String? ?? 'Untitled Facility';
    final facilityType = (json['facility_type'] as String? ?? 'other');
    final facilityTypeLabel =
        (json['facility_type_label'] as String?)?.trim().isNotEmpty == true
        ? (json['facility_type_label'] as String)
        : labelForFacilityType(facilityType);
    final workflow = json['workflow_config'];
    final pricing = workflow is Map ? workflow['pricing'] : null;

    return FacilityItem(
      id: (json['id'] as String? ?? ''),
      name: name,
      facilityType: facilityType,
      facilityTypeLabel: facilityTypeLabel,
      status: statusLabel,
      capacity: (json['capacity'] ?? 0).toString(),
      capacityLabel: (json['capacity_label'] ?? '').toString(),
      rate: (json['rate']?.toString() ?? '0'),
      priceType: (json['price_type'] as String? ?? 'hour'),
      bookingMode: (json['booking_mode'] as String? ?? 'room'),
      roomType: (json['room_type'] as String? ?? ''),
      slots: (json['slots'] as String? ?? ''),
      rating: (json['rating']?.toString() ?? ''),
      reviews: (json['reviews']?.toString() ?? ''),
      icon: iconForFacility(name, facilityType: facilityType),
      imageUrl: (json['image_url'] as String? ?? ''),
      images: images,
      description: (json['description'] as String?) ?? '',
      amenities: amenities,
      requirements: (json['requirements'] as String?) ?? '',
      termsConditions: (json['terms_conditions'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      jobOrderService: (json['job_order_service'] as String?)?.trim() ?? '',
      catalogPriceLabel: ['price_compact_label', 'price_label']
          .map((key) => '${json[key] ?? ''}'.trim())
          .firstWhere((label) => label.isNotEmpty, orElse: () => ''),
      baseDurationHours: pricing is Map
          ? double.tryParse('${pricing['base_duration'] ?? ''}')
          : null,
      workflowConfig: workflow is Map
          ? Map<String, dynamic>.unmodifiable(
              workflow.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const {},
      customFacilityType:
          (json['custom_facility_type'] as String?)?.trim() ?? '',
    );
  }

  final String id;
  final String name;
  final String facilityType;
  final String facilityTypeLabel;
  final String status;

  bool get isOpenForBooking => status == 'Open for Booking';

  String get bookingStatusExplanation => switch (status) {
    'Open for Booking' =>
      'Accepting requests during operating hours, subject to actual availability.',
    'Temporarily Unavailable' =>
      'Booking requests are temporarily paused for this facility.',
    'Under Maintenance' =>
      'This facility is under maintenance and cannot accept booking requests.',
    'Inactive' =>
      'This facility is inactive and is not accepting booking requests.',
    _ =>
      'Facility status could not be verified. Refresh before requesting a booking.',
  };
  final String capacity;
  final String capacityLabel;
  final String rate;
  final String priceType;
  final String bookingMode;
  final String roomType;
  final String slots;
  final String rating;
  final String reviews;
  final IconData icon;
  final String imageUrl;
  final List<String> images;
  final String description;
  final List<String> amenities;
  final String requirements;
  final String termsConditions;
  final String location;
  final String jobOrderService;

  /// Already formatted by Django, including the configured billing basis.
  final String catalogPriceLabel;

  /// Saved initial package length; used for display, never to calculate a quote.
  final double? baseDurationHours;

  /// Existing Django configuration, retained for read-only facility information.
  final Map<String, dynamic> workflowConfig;
  final String customFacilityType;

  bool get supportsSlotBooking =>
      (bookingMode == 'slot' || bookingMode == 'assessment') &&
      !['hostel', 'food_analysis', 'lease_space'].contains(facilityType);

  static const String campusName = 'USTP Oroquieta Campus';

  /// Mobile card wording; server labels remain available for other consumers.
  String get cardPriceLabel {
    if (priceType == 'custom') return 'Price varies / See Rates';
    final unit = switch (priceType) {
      'hour' => 'hour',
      'day' => 'day',
      'person' => 'person',
      'person_night' => 'person / night',
      'night' => 'night',
      'session' => 'booking',
      'month' || 'monthly' => 'month',
      _ => null,
    };
    // Service-specific and unfamiliar methods retain the configured server text.
    if (unit == null && priceType != 'base_hour') {
      return catalogPriceLabel.isNotEmpty ? catalogPriceLabel : 'Contact Admin';
    }
    final amount = double.tryParse(rate);
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Contact Admin';
    }
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final money = '\u20b1$whole${parts[1] == '00' ? '' : '.${parts[1]}'}';
    if (priceType == 'base_hour') {
      final hours = baseDurationHours;
      if (hours == null || !hours.isFinite || hours <= 0 || hours > 24) {
        return 'Pricing needs review';
      }
      final duration = hours == hours.truncateToDouble()
          ? hours.toStringAsFixed(0)
          : hours.toString();
      return '$money / first $duration ${hours == 1 ? 'hr' : 'hrs'}';
    }
    return '$money / $unit';
  }

  String get priceLabel {
    if (catalogPriceLabel.isNotEmpty) return catalogPriceLabel;
    if (rate.isEmpty || rate == '0') return 'Contact Admin';
    final priceNum = double.tryParse(rate);
    final formatted = priceNum != null
        ? '\u20b1${priceNum.toStringAsFixed(2)}'
        : '\u20b1$rate';
    return priceType == 'monthly'
        ? '$formatted monthly'
        : '$formatted per $priceType';
  }

  String get resolvedImageUrl {
    var url = imageUrl.trim();
    if (url.isEmpty && images.isNotEmpty) {
      url = images.first.trim();
    }
    if (url.isEmpty) return '';
    if (url.startsWith('[')) {
      try {
        final parsed = jsonDecode(url);
        if (parsed is List && parsed.isNotEmpty) {
          url = parsed.first.toString().trim();
        }
      } catch (_) {}
    }
    if (url.startsWith('http') || url.startsWith('data:image/')) return url;
    if (url.startsWith('/')) return '${ApiConfig.effectiveBaseUrl}$url';
    return url;
  }

  List<String> get allImageUrls {
    String resolveSingle(String rawUrl) {
      final s = rawUrl.trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http') || s.startsWith('data:image/')) return s;
      if (s.startsWith('/')) return '${ApiConfig.effectiveBaseUrl}$s';
      return s;
    }

    if (images.isNotEmpty) {
      final resolvedList = images
          .map(resolveSingle)
          .where((s) => s.isNotEmpty)
          .toList();
      if (resolvedList.isNotEmpty) return resolvedList;
    }

    final raw = imageUrl.trim();
    if (raw.isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          return parsed
              .map((e) => resolveSingle(e.toString()))
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    final single = resolvedImageUrl;
    return single.isNotEmpty ? [single] : const [];
  }

  /// Time ranges from admin `slots` field (comma/semicolon separated or single range).
  List<String> get timeSlotLabels {
    final raw = slots.trim();
    if (raw.isEmpty) return const [];

    final parts = raw
        .split(RegExp(r'[,;|\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts;

    return [raw];
  }

  bool get hasRating => rating.isNotEmpty && rating != '0';
  bool get hasReviews => reviews.isNotEmpty && reviews != '0';
}

String labelForFacilityType(String type) {
  return switch (type.toLowerCase()) {
    'covered_court' => 'Covered Court',
    'function_hall' => 'Function Hall',
    'hostel' => 'Hostel',
    'training_kitchen' => 'Training Kitchen',
    'food_analysis' => 'Food Analysis Lab',
    'lease_space' => 'Lease of Space',
    _ => 'Other',
  };
}

IconData iconForFacility(String name, {String facilityType = ''}) {
  final type = facilityType.toLowerCase();
  if (type == 'covered_court') return Icons.sports_basketball_outlined;
  if (type == 'function_hall') return Icons.account_balance_outlined;
  if (type == 'hostel') return Icons.hotel_outlined;
  if (type == 'training_kitchen') return Icons.local_fire_department_outlined;
  if (type == 'food_analysis') return Icons.science_outlined;
  if (type == 'lease_space') return Icons.business_outlined;

  final lower = name.toLowerCase();
  if (lower.contains('court')) return Icons.sports_basketball_outlined;
  if (lower.contains('hall')) return Icons.account_balance_outlined;
  if (lower.contains('hostel') ||
      lower.contains('dorm') ||
      lower.contains('hotel')) {
    return Icons.hotel_outlined;
  }
  if (lower.contains('lab') || lower.contains('analysis')) {
    return Icons.science_outlined;
  }
  if (lower.contains('kitchen')) return Icons.local_fire_department_outlined;
  if (lower.contains('assess')) return Icons.verified_outlined;
  return Icons.assignment_outlined;
}
