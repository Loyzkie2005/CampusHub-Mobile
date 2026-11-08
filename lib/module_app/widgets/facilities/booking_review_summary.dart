import 'package:flutter/material.dart';

import '../../models/facility_item.dart' show iconForAmenity;
import '../../theme/app_typography.dart';
import 'booking_widgets.dart';

/// Presentation only: the form owns the draft and Django owns every amount.
class BookingReviewSummary extends StatelessWidget {
  const BookingReviewSummary({
    super.key,
    required this.date,
    required this.start,
    required this.end,
    required this.details,
    required this.quote,
    this.termsConditions = '',
  });

  final DateTime date;
  final String start, end, termsConditions;
  final Map<String, dynamic> details, quote;

  String _detail(String key) => '${details[key] ?? ''}'.trim();

  Widget _heading(String title, IconData icon, {double fontSize = 16}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: bookingNavy),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: AppTypography.cardTitle.copyWith(
            fontSize: fontSize,
            color: bookingNavy,
          ),
        ),
      ),
    ],
  );

  Widget _card(
    String key,
    String title,
    IconData icon,
    List<Widget> children, {
    bool compact = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: BookingCard(
      key: ValueKey(key),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(title, icon, fontSize: compact ? 15 : 16),
          SizedBox(height: compact ? 12 : 14),
          ...children,
        ],
      ),
    ),
  );

  Widget _stackedValue(
    String label,
    String value, {
    String? supporting,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.helper.copyWith(color: bookingMuted)),
      const SizedBox(height: 4),
      Text(value, style: AppTypography.fieldLabel.copyWith(color: bookingNavy)),
      if (supporting != null) ...[
        const SizedBox(height: 4),
        Text(
          supporting,
          style: AppTypography.helper.copyWith(color: bookingMuted),
        ),
      ],
    ],
  );

  Widget _schedule(BuildContext context) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dateColumn = _stackedValue(
      'Booking Date',
      bookingDate(date.toIso8601String()),
      supporting: weekdays[date.weekday - 1],
    );
    final duration = _stackedValue(
      'Duration',
      '${quote['hours']} ${num.tryParse('${quote['hours']}') == 1 ? 'hour' : 'hours'}',
      supporting: '${bookingTime(start)} – ${bookingTime(end)}',
    );
    return _card(
      'review-schedule',
      'Booking Schedule',
      Icons.calendar_month_outlined,
      [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateColumn,
                      const SizedBox(height: 14),
                      duration,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dateColumn),
                      const SizedBox(width: 16),
                      Expanded(child: duration),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _requestor() =>
      _card('review-requestor', 'Requestor Information', Icons.person_outline, [
        _stackedValue('Full Name', _detail('full_name')),
        if (_detail('organization').isNotEmpty) ...[
          const SizedBox(height: 14),
          _stackedValue('Organization', _detail('organization')),
        ],
        const SizedBox(height: 14),
        _stackedValue('Contact Number', _detail('contact_number')),
        const SizedBox(height: 14),
        _stackedValue('Email Address', _detail('email')),
      ]);

  Widget _event() => _card(
    'review-event',
    'Event Information',
    Icons.event_available_outlined,
    [
      BookingValue('Event / Activity', _detail('event_name')),
      BookingValue('Purpose', _detail('purpose')),
      BookingValue('Attendees', '${_detail('attendees')} persons'),
    ],
  );

  Widget _requirementsAndNotes(List<String> requirements) {
    final notes = _detail('notes');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BookingCard(
        key: const ValueKey('review-requirements-notes'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requirements.isNotEmpty) ...[
              _heading('Additional Requirements', Icons.checklist_outlined),
              const SizedBox(height: 12),
              for (final label in requirements)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(iconForAmenity(label), size: 18, color: bookingNavy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.fieldLabel.copyWith(
                            color: bookingNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (requirements.contains('Others') &&
                  _detail('other_requirements').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _detail('other_requirements'),
                  style: AppTypography.helper.copyWith(color: bookingMuted),
                ),
              ],
            ],
            if (notes.isNotEmpty) ...[
              if (requirements.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: bookingOutline),
                ),
              _heading('Additional Notes', Icons.note_alt_outlined),
              const SizedBox(height: 12),
              Text(
                notes,
                style: AppTypography.helper.copyWith(color: bookingMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _positive(String key) => (num.tryParse('${quote[key]}') ?? 0) > 0;

  Widget _costRow(String label, String value, {bool total = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: total ? 4 : 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelText = Text(
          label,
          style: AppTypography.helper.copyWith(
            fontSize: 12,
            fontWeight: total ? FontWeight.w600 : FontWeight.w400,
            color: total ? bookingNavy : bookingMuted,
          ),
        );
        final amount = Text(
          value,
          textAlign: TextAlign.right,
          style: AppTypography.fieldLabel.copyWith(
            fontSize: total ? 15 : 13,
            fontWeight: total ? FontWeight.w600 : FontWeight.w500,
            color: bookingNavy,
            height: 1.45,
          ),
        );
        if (MediaQuery.textScalerOf(context).scale(12) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelText, const SizedBox(height: 4), amount],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: labelText),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: amount),
          ],
        );
      },
    ),
  );

  Widget _cost() => _card(
    'review-cost',
    'Estimated Cost Breakdown',
    Icons.receipt_long_outlined,
    [
      _costRow(
        'Base Rental Fee',
        bookingMoney(quote['base_rental_amount'] ?? quote['base_amount']),
      ),
      if (_positive('additional_hour_amount'))
        _costRow(
          'Additional Hours',
          bookingMoney(quote['additional_hour_amount']),
        ),
      if (_positive('discount_amount'))
        _costRow(
          '${quote['discount_label'] ?? 'Eligible discount'}',
          '-${bookingMoney(quote['discount_amount'])}',
        ),
      for (final fee in (quote['fees'] as List? ?? const []).whereType<Map>())
        if ((num.tryParse('${fee['quantity']}') ?? 0) > 0)
          _costRow(
            '${fee['name']} × ${fee['quantity']}',
            bookingMoney(fee['amount']),
          ),
      if (_positive('deposit_amount'))
        _costRow(
          'Refundable damage deposit',
          bookingMoney(quote['deposit_amount']),
        ),
      for (final key in ['discount_note', 'additional_requirements_note'])
        if ('${quote[key] ?? ''}'.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${quote[key]}',
              style: AppTypography.helper.copyWith(
                fontSize: 12,
                color: bookingMuted,
              ),
            ),
          ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: bookingOutline),
      ),
      _costRow(
        'Estimated Total',
        bookingMoney(quote['total_amount']),
        total: true,
      ),
    ],
    compact: true,
  );

  @override
  Widget build(BuildContext context) {
    final requirements =
        (details['additional_requirements'] as List? ?? const [])
            .whereType<String>()
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _schedule(context),
        _requestor(),
        _event(),
        if (requirements.isNotEmpty || _detail('notes').isNotEmpty)
          _requirementsAndNotes(requirements),
        _cost(),
        if (termsConditions.isNotEmpty)
          _card('review-rules', 'Rules & Guidelines', Icons.rule_outlined, [
            Text(
              termsConditions,
              style: AppTypography.helper.copyWith(color: bookingNavy),
            ),
          ]),
      ],
    );
  }
}
