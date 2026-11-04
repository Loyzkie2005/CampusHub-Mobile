import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/facility_booking_service.dart';
import 'booking_widgets.dart';

// This screen's explicitly approved brand/status treatments.
const scheduleFont = 'Montserrat';
const scheduleGold = Color(0xFFFCB316);
const scheduleMaintenance = Color(0xFF9333EA);

/// Only presents server slot statuses; never generates or saves availability.
class BookingScheduleCalendar extends StatelessWidget {
  const BookingScheduleCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.days,
    required this.onMonth,
    required this.onDate,
    this.busy = false,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, List<Map<String, dynamic>>> days;
  final ValueChanged<int> onMonth;
  final ValueChanged<DateTime> onDate;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(FacilityBookingService.manilaNow());
    final firstMonth = DateTime(today.year, today.month);
    final lastDate = DateTime(today.year + 2);
    final offset = month.weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = (offset + count + 6) ~/ 7;
    return Column(
      key: const ValueKey('booking-schedule-calendar'),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('schedule-previous-month'),
              tooltip: 'Previous month',
              color: bookingNavy,
              onPressed: !busy && month.isAfter(firstMonth)
                  ? () => onMonth(-1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                header: true,
                child: Text(
                  localizations.formatMonthYear(month),
                  key: const ValueKey('schedule-month-title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: scheduleFont,
                    fontVariations: [FontVariation('wght', 600)],
                    color: bookingNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('schedule-next-month'),
              tooltip: 'Next month',
              color: bookingNavy,
              onPressed: !busy && month.isBefore(lastDate)
                  ? () => onMonth(1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final day in localizations.narrowWeekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontFamily: scheduleFont,
                      fontVariations: [FontVariation('wght', 400)],
                      fontSize: 11,
                      color: bookingMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final diameter = math.min(
              constraints.maxWidth / 7 - 2,
              math.max(32.0, MediaQuery.textScalerOf(context).scale(12) + 12),
            );
            final height = math.max(48.0, diameter + 14);
            return Column(
              children: [
                for (var row = 0; row < rows; row++)
                  Row(
                    children: [
                      for (var column = 0; column < 7; column++)
                        Expanded(
                          child: SizedBox(
                            height: height,
                            child:
                                row * 7 + column < offset ||
                                    row * 7 + column - offset >= count
                                ? null
                                : _date(
                                    context,
                                    DateTime(
                                      month.year,
                                      month.month,
                                      row * 7 + column - offset + 1,
                                    ),
                                    today,
                                    lastDate,
                                    diameter,
                                  ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              key: const ValueKey('schedule-legend'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legend('Available', bookingGreen),
                _legend('Closed', bookingGreyDot),
                _legend('Unavailable', bookingRed, prohibited: true),
                _legend('Reserved', bookingBlueDot, last: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _date(
    BuildContext context,
    DateTime date,
    DateTime today,
    DateTime lastDate,
    double diameter,
  ) {
    final past = date.isBefore(today);
    final status = past || date.isAfter(lastDate)
        ? 'past'
        : FacilityBookingService.dayStatus(days[date]);
    final enabled = !busy && status == 'available';
    final isSelected = selected == date && status == 'available';
    final key = FacilityBookingService.dateKey(date);
    final color = switch (status) {
      'available' => bookingGreen,
      'reserved' => bookingBlueDot,
      'maintenance' => scheduleMaintenance,
      'class' => bookingGoldText,
      _ => null,
    };
    final label = switch (status) {
      'past' => 'Past or outside booking range',
      'unknown' => 'Availability not loaded',
      'not_bookable' => 'Not bookable under the facility rules',
      'blocked' => 'Blocked by a facility schedule',
      _ => bookingStatus(status),
    };
    Widget number = SizedBox(
      key: ValueKey('schedule-number-$key'),
      width: diameter,
      height: diameter,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontFamily: scheduleFont,
                fontVariations: [FontVariation('wght', isSelected ? 700 : 500)],
                fontSize: 12,
                height: 1,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : status == 'available' || status == 'blocked'
                    ? bookingNavy
                    : bookingMuted,
              ),
            ),
          ),
        ),
      ),
    );
    if (status == 'blocked') {
      number = CustomPaint(
        key: ValueKey('schedule-prohibited-$key'),
        foregroundPainter: const ScheduleProhibitionPainter(),
        child: number,
      );
    }
    return Semantics(
      label:
          '${MaterialLocalizations.of(context).formatFullDate(date)}, $label',
      button: true,
      enabled: enabled,
      selected: isSelected,
      child: ExcludeSemantics(
        child: InkResponse(
          key: ValueKey('schedule-day-$key'),
          onTap: enabled ? () => onDate(date) : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? bookingNavy : Colors.transparent,
                  ),
                  child: number,
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: Center(
                    child: !isSelected && color != null
                        ? _StatusDot(color)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(
    String label,
    Color color, {
    bool prohibited = false,
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(right: last ? 0 : 14),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prohibited)
          const CustomPaint(
            size: Size(11, 11),
            painter: ScheduleProhibitionPainter(),
          )
        else
          _StatusDot(color),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontFamily: scheduleFont,
            fontVariations: [FontVariation('wght', 400)],
            fontSize: 11,
            color: bookingMuted,
          ),
        ),
      ],
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: const SizedBox(width: 5, height: 5),
  );
}

/// Circle/slash over unavailable date numbers, also used in the legend.
class ScheduleProhibitionPainter extends CustomPainter {
  const ScheduleProhibitionPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.max(0.0, size.shortestSide / 2 - 2);
    final paint = Paint()
      ..color = bookingRed
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    final diagonal = radius / math.sqrt2;
    canvas.drawLine(
      center + Offset(-diagonal, diagonal),
      center + Offset(diagonal, -diagonal),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScheduleProhibitionPainter oldDelegate) => false;
}
