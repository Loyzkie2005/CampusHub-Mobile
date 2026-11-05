import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'booking_schedule_calendar.dart';
import 'booking_widgets.dart';

const _selectionBg = Color(0xFFF2F4F7);

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
  late int _hourIndex = (widget.initialTime.hour + 11) % 12;
  late int _minuteIndex = widget.initialTime.minute;
  late int _periodIndex = widget.initialTime.period == DayPeriod.am ? 0 : 1;

  late final _hours = FixedExtentScrollController(initialItem: _hourIndex);
  late final _minutes = FixedExtentScrollController(initialItem: _minuteIndex);
  late final _periods = FixedExtentScrollController(initialItem: _periodIndex);

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _periods.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = (MediaQuery.textScalerOf(context).scale(22) + 18).clamp(
      40.0,
      56.0,
    );
    final wheelHeight = (extent * 3.6).clamp(150.0, 196.0);
    final selectedHour = _hours.hasClients ? _hours.selectedItem : _hourIndex;
    final selectedMinute = _minutes.hasClients
        ? _minutes.selectedItem
        : _minuteIndex;
    final selectedPeriod = _periods.hasClients
        ? _periods.selectedItem
        : _periodIndex;

    Widget wheel({
      required String semanticLabel,
      required Key wheelKey,
      required Key selectionKey,
      required int count,
      required FixedExtentScrollController controller,
      required int selectedIndex,
      required ValueChanged<int> onChanged,
      required String Function(int index) labelBuilder,
      Key Function(int index)? itemKeyBuilder,
    }) => Expanded(
      child: SizedBox(
        height: wheelHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Selection background placed BEHIND the numbers so text is completely visible.
            Positioned(
              left: 4,
              right: 4,
              height: extent,
              child: Container(
                key: selectionKey,
                decoration: BoxDecoration(
                  color: _selectionBg,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // The scrollable wheel rendered ON TOP of the selection background.
            Semantics(
              label: semanticLabel,
              child: CupertinoPicker(
                key: wheelKey,
                scrollController: controller,
                itemExtent: extent,
                diameterRatio: 1.15,
                squeeze: 1.0,
                selectionOverlay: null,
                onSelectedItemChanged: onChanged,
                children: [
                  for (var index = 0; index < count; index++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (controller.hasClients) {
                          controller.jumpToItem(index);
                        }
                        onChanged(index);
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labelBuilder(index),
                              key: itemKeyBuilder?.call(index),
                              style: TextStyle(
                                fontFamily: scheduleFont,
                                fontWeight: index == selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontVariations: [
                                  FontVariation(
                                    'wght',
                                    index == selectedIndex ? 600 : 500,
                                  ),
                                ],
                                fontSize: 22,
                                color: bookingNavy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          key: const ValueKey('booking-time-dialog'),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      key: const ValueKey('booking-time-drag-handle'),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: bookingOutline,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    key: const ValueKey('booking-time-title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: scheduleFont,
                      fontWeight: FontWeight.w600,
                      fontVariations: [FontVariation('wght', 600)],
                      fontSize: 16,
                      color: bookingNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      wheel(
                        semanticLabel: 'Hour',
                        wheelKey: const ValueKey('booking-time-hour-wheel'),
                        selectionKey: const ValueKey(
                          'booking-time-hour-selection',
                        ),
                        count: 12,
                        controller: _hours,
                        selectedIndex: selectedHour,
                        onChanged: (index) =>
                            setState(() => _hourIndex = index),
                        labelBuilder: (index) =>
                            (index + 1).toString().padLeft(2, '0'),
                      ),
                      const SizedBox(width: 8),
                      wheel(
                        semanticLabel: 'Minute',
                        wheelKey: const ValueKey('booking-time-minute-wheel'),
                        selectionKey: const ValueKey(
                          'booking-time-minute-selection',
                        ),
                        count: 60,
                        controller: _minutes,
                        selectedIndex: selectedMinute,
                        onChanged: (index) =>
                            setState(() => _minuteIndex = index),
                        labelBuilder: (index) =>
                            index.toString().padLeft(2, '0'),
                      ),
                      const SizedBox(width: 8),
                      wheel(
                        semanticLabel: 'AM/PM',
                        wheelKey: const ValueKey('booking-time-period'),
                        selectionKey: const ValueKey(
                          'booking-time-period-selection',
                        ),
                        count: 2,
                        controller: _periods,
                        selectedIndex: selectedPeriod,
                        onChanged: (index) =>
                            setState(() => _periodIndex = index),
                        labelBuilder: (index) => index == 0 ? 'AM' : 'PM',
                        itemKeyBuilder: (index) => ValueKey(
                          index == 0 ? 'booking-time-am' : 'booking-time-pm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('booking-time-cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: bookingNavy,
                            backgroundColor: Colors.white,
                            overlayColor: scheduleGold.withValues(alpha: 0.14),
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: const BorderSide(color: bookingOutline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: scheduleFont,
                              fontWeight: FontWeight.w600,
                              fontVariations: [FontVariation('wght', 600)],
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('booking-time-ok'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: bookingNavy,
                            overlayColor: scheduleGold.withValues(alpha: 0.18),
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: scheduleFont,
                              fontWeight: FontWeight.w600,
                              fontVariations: [FontVariation('wght', 600)],
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () {
                            final hourIndex = _hours.hasClients
                                ? _hours.selectedItem
                                : _hourIndex;
                            final minuteIndex = _minutes.hasClients
                                ? _minutes.selectedItem
                                : _minuteIndex;
                            final periodIndex = _periods.hasClients
                                ? _periods.selectedItem
                                : _periodIndex;
                            final hour =
                                (hourIndex + 1) % 12 +
                                (periodIndex == 1 ? 12 : 0);
                            Navigator.of(
                              context,
                            ).pop(TimeOfDay(hour: hour, minute: minuteIndex));
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('OK'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
