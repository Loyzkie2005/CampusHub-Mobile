import 'facility_item.dart';

/// Read-only presentation of saved configuration. Django calculates all quotes.
class FacilityDetailInformation {
  const FacilityDetailInformation(this.facility);
  final FacilityItem facility;

  Map<String, dynamic> get config => facility.workflowConfig;
  Map get pricing => config['pricing'] is Map ? config['pricing'] as Map : {};

  String get primaryRate => facility.cardPriceLabel
      .replaceFirst(RegExp(r'\bhrs\b'), 'hours')
      .replaceFirst(RegExp(r'\bhr\b'), 'hour');

  String get capacity {
    if (facility.capacityLabel.trim().isNotEmpty) return facility.capacityLabel;
    final maximum = int.tryParse(facility.capacity);
    if (maximum == null || maximum <= 0) return '';
    final minimum = int.tryParse('${config['capacity_min']}');
    return minimum != null && minimum > 0 && minimum <= maximum
        ? '$minimum–$maximum persons'
        : '$maximum persons';
  }

  String get reviewSummary {
    final rating = double.tryParse(facility.rating);
    final count = int.tryParse(facility.reviews);
    if (rating == null ||
        !rating.isFinite ||
        rating < 1 ||
        rating > 5 ||
        count == null ||
        count <= 0) {
      return 'No reviews yet';
    }
    return '${rating.toStringAsFixed(1)} ($count ${count == 1 ? 'review' : 'reviews'})';
  }

  List<({String label, String value})> get rateOptions {
    final rows = <({String label, String value})>[];
    if (facility.priceType == 'base_hour') {
      final extra = money(pricing['additional_hour_rate']);
      final hourly = money(pricing['hourly_rate']);
      if (extra != null) {
        rows.add((label: 'Additional hour', value: '$extra / hour'));
      }
      if (hourly != null) {
        rows.add((label: 'Alternative hourly rate', value: '$hourly / hour'));
      }
    }
    if (facility.priceType == 'person_night') {
      final shared = money(pricing['partner_rate']);
      final guests = int.tryParse('${pricing['partner_occupancy_required']}');
      if (shared != null && guests != null && guests >= 2) {
        rows.add((
          label: 'Shared room · $guests guests in one room',
          value: '$shared / person / night',
        ));
      }
    }
    return rows;
  }

  String get customPricing =>
      facility.priceType == 'custom' ? _text(pricing['notes']) : '';

  /// Seven display days; missing/invalid hours never imply an open schedule.
  List<({String label, String value, bool? isOpen})> get operatingDays {
    if (config['operating_hours'] is! Map) return const [];
    final saved = {for (final row in schedule) row.label: row.value};
    return [
      for (final label in const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ])
        if (config['weekend_only'] == true &&
            label != 'Saturday' &&
            label != 'Sunday')
          (label: label, value: 'Unavailable', isOpen: false)
        else
          (
            label: label,
            value: saved[label] ?? 'Not configured',
            isOpen: saved[label] == 'Closed'
                ? false
                : saved[label] == null ||
                      saved[label] == 'Schedule needs review'
                ? null
                : true,
          ),
    ];
  }

  List<({String label, String value})> get schedule {
    final rows = <({String label, String value})>[];
    final mode = switch (facility.bookingMode) {
      'slot' => 'Scheduled time slots',
      'assessment' => 'Assessment schedule',
      'room' => 'Room-based request',
      'lease' => 'Lease application',
      _ => '',
    };
    if (mode.isNotEmpty) rows.add((label: 'Booking mode', value: mode));
    final hours = config['operating_hours'];
    if (hours is Map) {
      for (final day in const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ]) {
        if (!hours.containsKey(day)) continue;
        final period = hours[day];
        final String value;
        if (period == null) {
          value = 'Closed';
        } else if (period is Map &&
            _time(period['open']) != null &&
            _time(period['close']) != null &&
            '${period['open']}'.compareTo('${period['close']}') < 0) {
          value = '${_time(period['open'])} – ${_time(period['close'])}';
        } else {
          value = 'Schedule needs review';
        }
        rows.add((
          label: '${day[0].toUpperCase()}${day.substring(1)}',
          value: value,
        ));
      }
    } else if (_text(hours).isNotEmpty) {
      rows.add((label: 'Operating hours', value: _text(hours)));
    }
    if (config['weekend_only'] == true) {
      rows.add((label: 'Restriction', value: 'Weekends only'));
    }
    final minimum = _number(config['minimum_booking_duration']);
    if (minimum != null && minimum > 0) {
      rows.add((
        label: 'Minimum duration',
        value: '${_decimal(minimum)} ${minimum == 1 ? 'hour' : 'hours'}',
      ));
    }
    for (final (key, label) in [
      ('check_in_time', 'Check-in'),
      ('check_out_time', 'Check-out'),
    ]) {
      final time = _time(config[key]);
      if (time != null) rows.add((label: label, value: time));
    }
    final days = int.tryParse('${config['advance_payment_days']}');
    if (days != null && days > 0) {
      rows.add((
        label: 'Advance payment',
        value: '$days ${days == 1 ? 'day' : 'days'} before use',
      ));
    }
    final clients = switch (config['eligible_clients']) {
      'internal' => 'Internal clients only',
      'external' => 'External clients only',
      'both' => 'Internal and external clients',
      _ => '',
    };
    if (clients.isNotEmpty) {
      rows.add((label: 'Eligible clients', value: clients));
    }
    return rows;
  }

  List<({String label, String value})> get charges {
    final rows = <({String label, String value})>[];
    final fees = config['additional_fees'];
    if (fees is List) {
      for (final fee in fees.whereType<Map>()) {
        if (fee['active'] != true || _text(fee['name']).isEmpty) continue;
        final amount = money(fee['amount']);
        final unit = switch (fee['unit']) {
          'item' || 'unit' => 'item',
          'hour' => 'hour',
          'day' => 'day',
          'night' => 'night',
          'person' => 'person',
          'booking' || 'fixed' => 'booking',
          'custom' => _text(fee['custom_basis']),
          _ => '',
        };
        if (amount != null && unit.isNotEmpty) {
          rows.add((label: _text(fee['name']), value: '$amount / $unit'));
        }
      }
    }
    final deposit = config['damage_deposit'];
    if (config['damage_deposit_applicable'] == true && deposit is Map) {
      final value = _number(deposit['value']);
      final fixed = money(deposit['value']);
      if (deposit['type'] == 'fixed' && fixed != null) {
        rows.add((
          label: 'Damage deposit',
          value: '$fixed · refundable subject to inspection',
        ));
      } else if (deposit['type'] == 'percentage' &&
          value != null &&
          value <= 100) {
        rows.add((
          label: 'Damage deposit',
          value:
              '${_decimal(value)}% of rental fee · refundable subject to inspection',
        ));
      }
    }
    final discounts = config['discount_rules'];
    if (discounts is List) {
      for (final discount in discounts.whereType<Map>()) {
        if (discount['active'] != true) continue;
        final client = switch (discount['eligible_client_type']) {
          'internal' => 'Internal client',
          'immediate_family' => 'Immediate family',
          'student' => 'USTP student',
          'other' => 'Other eligible clients',
          _ => '',
        };
        final scope = switch (discount['applies_to']) {
          'rental_fee' => 'rental fee',
          'base_rate' => 'base rate',
          'additional_hour_rate' => 'additional-hour rate',
          'individual_rate' => 'individual rate',
          'partner_rate' => 'shared-room rate',
          'entire_rental_rate' => 'entire rental rate',
          'custom' => _text(discount['custom_scope']),
          _ => '',
        };
        final value = _number(discount['discount_value']);
        if (client.isEmpty || scope.isEmpty || value == null) continue;
        final String? amount;
        if (discount['discount_type'] == 'percentage' && value <= 100) {
          amount = '${_decimal(value)}%';
        } else if (discount['discount_type'] == 'fixed') {
          amount = money(value);
        } else {
          amount = null;
        }
        if (amount != null) {
          rows.add((
            label: '$client discount',
            value: '$amount on $scope · eligibility verification required',
          ));
        }
      }
    }
    return rows;
  }

  static String _text(dynamic value) => value is String ? value.trim() : '';
  static double? _number(dynamic value) {
    final number = double.tryParse('$value');
    return number != null &&
            number.isFinite &&
            number >= 0 &&
            number <= 99999999.99
        ? number
        : null;
  }

  static String _decimal(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  static String? money(dynamic raw) {
    final value = _number(raw);
    if (value == null) return null;
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '₱$whole${parts[1] == '00' ? '' : '.${parts[1]}'}';
  }

  static String? _time(dynamic raw) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('$raw');
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return '${hour % 12 == 0 ? 12 : hour % 12}:${match[2]} ${hour < 12 ? 'AM' : 'PM'}';
  }
}
