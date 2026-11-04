import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'booking_schedule_calendar.dart';
import 'booking_widgets.dart';

/// Keeps wheel changes local until OK; the booking screen validates the result.
class BookingTimeDialog extends StatefulWidget {
  const BookingTimeDialog({
    super.key,
    required this.title,
    required this.initialTime,
  });

  final String title;
  final TimeOfDay initialTime;

  @override
  State<BookingTimeDialog> createState() => _BookingTimeDialogState();
}

class _BookingTimeDialogState extends State<BookingTimeDialog> {
  late final _hours = FixedExtentScrollController(
    initialItem: (widget.initialTime.hour + 11) % 12,
  );
  late final _minutes = FixedExtentScrollController(
    initialItem: widget.initialTime.minute,
  );
  late DayPeriod _period = widget.initialTime.period;

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = MediaQuery.textScalerOf(context).scale(28) + 16;
    final actionStyle = TextButton.styleFrom(
      foregroundColor: bookingNavy,
      minimumSize: const Size(64, 48),
      textStyle: const TextStyle(
        fontFamily: scheduleFont,
        fontVariations: [FontVariation('wght', 500)],
        fontSize: 14,
      ),
    );
    Widget wheel(
      String label,
      int count,
      FixedExtentScrollController controller,
    ) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: extent * 3,
            child: Semantics(
              label: label,
              child: CupertinoPicker(
                key: ValueKey('booking-time-${label.toLowerCase()}-wheel'),
                scrollController: controller,
                itemExtent: extent,
                onSelectedItemChanged: (_) {},
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: bookingNavy.withValues(alpha: .06),
                ),
                children: [
                  for (var value = 0; value < count; value++)
                    Center(
                      child: Text(
                        (label == 'Hour' ? value + 1 : value)
                            .toString()
                            .padLeft(2, '0'),
                        style: const TextStyle(
                          fontFamily: scheduleFont,
                          fontVariations: [FontVariation('wght', 500)],
                          fontSize: 28,
                          color: bookingNavy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: scheduleFont,
              fontVariations: [FontVariation('wght', 400)],
              fontSize: 12,
              color: bookingMuted,
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      key: const ValueKey('booking-time-dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      title: Text(
        widget.title,
        style: const TextStyle(
          fontFamily: scheduleFont,
          fontVariations: [FontVariation('wght', 500)],
          fontSize: 14,
          color: bookingNavy,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                wheel('Hour', 12, _hours),
                SizedBox(
                  height: extent * 3,
                  child: const Center(
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontFamily: scheduleFont,
                        fontVariations: [FontVariation('wght', 500)],
                        fontSize: 28,
                        color: bookingNavy,
                      ),
                    ),
                  ),
                ),
                wheel('Minute', 60, _minutes),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<DayPeriod>(
              key: const ValueKey('booking-time-period'),
              showSelectedIcon: false,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(72, 48)),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : bookingNavy,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? bookingNavy
                      : Colors.white,
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: bookingOutline),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: scheduleFont,
                    fontVariations: [FontVariation('wght', 500)],
                    fontSize: 14,
                  ),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: DayPeriod.am,
                  label: Text('AM', key: ValueKey('booking-time-am')),
                ),
                ButtonSegment(
                  value: DayPeriod.pm,
                  label: Text('PM', key: ValueKey('booking-time-pm')),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (selected) =>
                  setState(() => _period = selected.single),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('booking-time-cancel'),
          style: actionStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('booking-time-ok'),
          style: actionStyle,
          onPressed: () => Navigator.of(context).pop(
            TimeOfDay(
              hour:
                  (_hours.selectedItem + 1) % 12 +
                  (_period == DayPeriod.pm ? 12 : 0),
              minute: _minutes.selectedItem,
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
