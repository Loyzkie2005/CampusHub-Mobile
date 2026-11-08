import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import '../../models/facility_item.dart';
import '../../services/facility_booking_service.dart';
import '../../session/session_service.dart';
import '../../widgets/facilities/booking_widgets.dart';
import '../../widgets/facilities/booking_review_summary.dart';
import '../../widgets/facilities/booking_time_dialog.dart';
import '../../widgets/facilities/chairs_quantity_sheet.dart';
import '../../widgets/facilities/booking_schedule_calendar.dart';
import '../../theme/app_typography.dart';
import '../../widgets/seller/product_inventory_fields.dart'
    show ProductFieldLabel, ProductFormStyle;
import 'facility_booking_status_screen.dart';
import 'facility_booking_history_screen.dart';

class FacilityBookingScreen extends StatefulWidget {
  const FacilityBookingScreen({
    super.key,
    required this.facility,
    this.service = const FacilityBookingService(),
  });
  final FacilityItem facility;
  final FacilityBookingService service;
  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _fields = {
    for (final key in [
      'full_name',
      'organization',
      'contact_number',
      'email',
      'event_name',
      'purpose',
      'attendees',
      'other_requirements',
      'notes',
    ])
      key: TextEditingController(),
  };
  final _requirements = <String>{};
  final _feeFields = <String, TextEditingController>{};
  List<Map<String, dynamic>> _itemFees = [];
  late List<String> _requirementOptions;
  Map<String, dynamic>? _submittedPayload;
  final _requestKey = FacilityBookingService.newRequestKey();
  DateTime? _date;
  late DateTime _month;
  Map<DateTime, List<Map<String, dynamic>>> _days = {};
  int _monthVersion = 0;
  bool _calendarLoading = true;
  String? _calendarError;
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic>? _slot, _window, _quote, _booking;
  String? _customStart, _customEnd;
  bool _hasExplicitTimeSelection = false;
  String? _error;
  int _step = 0;
  int _loadVersion = 0;
  bool _loading = false, _busy = false;
  bool _openingChairs = false;
  Timer? _refreshTimer;
  bool _refreshing = false, _pickingTime = false, _wasCurrent = true;

  @override
  void initState() {
    super.initState();
    _requirementOptions = _cleanRequirementOptions(widget.facility.amenities);
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refreshAvailability());
      }
    });
    final now = FacilityBookingService.manilaNow();
    _date = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _loadMonth(initialDate: _date);
    _prefill();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refreshAvailability());
      });
    }
    _wasCurrent = current;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAvailability());
  }

  /// Refresh from Django without moving the month or losing requestor fields.
  Future<void> _refreshAvailability() async {
    if (!mounted ||
        _busy ||
        _submittedPayload != null ||
        _pickingTime ||
        _refreshing ||
        _calendarLoading ||
        _loading ||
        _step == 3 ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _refreshing = true;
    final version = _monthVersion, loadVersion = _loadVersion;
    try {
      final days = await widget.service.monthSlots(
        widget.facility.id,
        _month,
        isCurrent: () => mounted && version == _monthVersion,
      );
      if (!mounted ||
          version != _monthVersion ||
          loadVersion != _loadVersion ||
          _busy ||
          _pickingTime ||
          _step == 3) {
        return;
      }
      setState(() {
        _days = days;
        _calendarError = null;
        if (_date != null) {
          _slots = days[_date] ?? [];
          final open = _slots
              .where(FacilityBookingService.isAvailableSlot)
              .toList();
          Map<String, dynamic>? matching;
          for (final row in open) {
            if (_slot == null) break;
            final start = '${_slot!['start']}', end = '${_slot!['end']}';
            final hours =
                _clock(end).hour * 60 +
                _clock(end).minute -
                _clock(start).hour * 60 -
                _clock(start).minute;
            final fits = row['time_selection'] == 'custom'
                ? start.compareTo('${row['start']}') >= 0 &&
                      end.compareTo('${row['end']}') <= 0 &&
                      hours >= (row['minimum_duration_minutes'] as num? ?? 0)
                : row['start'] == start && row['end'] == end;
            if (fits) {
              matching = row;
              break;
            }
          }
          final invalid = _slot != null && matching == null;
          if (matching != null) _window = matching;
          if (invalid || open.isEmpty) {
            _slot = _window = _quote = null;
            _customStart = _customEnd = null;
            _hasExplicitTimeSelection = false;
            if (open.isEmpty) {
              _date = null;
              _slots = [];
            }
            _step = 0;
            _error =
                'Availability changed. Select an available date and time again.';
          } else if (_slot == null) {
            // A draft can have a window before any interval is confirmed.
            // Keep an explicitly chosen unchanged window; clear stale choices.
            final currentWindow = open
                .where(
                  (row) =>
                      row['start'] == _window?['start'] &&
                      row['end'] == _window?['end'] &&
                      row['time_selection'] == _window?['time_selection'] &&
                      row['minimum_duration_minutes'] ==
                          _window?['minimum_duration_minutes'],
                )
                .firstOrNull;
            if (currentWindow != null) {
              _window = currentWindow;
            } else {
              _resetTimeSelection();
            }
          }
        }
      });
    } catch (error) {
      if (mounted &&
          version == _monthVersion &&
          loadVersion == _loadVersion &&
          !_busy &&
          !_pickingTime &&
          _step != 3) {
        setState(() {
          _days = {};
          _slots = [];
          _slot = _window = _quote = null;
          _customStart = _customEnd = null;
          _hasExplicitTimeSelection = false;
          _step = 0;
          _calendarError = '$error';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _prefill() async {
    final user = await SessionService.loadUser();
    if (!mounted || user == null) return;
    for (final item in {
      'full_name': user.fullName,
      'contact_number': user.contactNumber,
      'email': user.email,
    }.entries) {
      if (_fields[item.key]!.text.isEmpty) _fields[item.key]!.text = item.value;
    }
  }

  @override
  void dispose() {
    for (final controller in _feeFields.values) {
      controller.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _monthVersion++;
    _loadVersion++;
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMonth({DateTime? initialDate}) async {
    final version = ++_monthVersion;
    _loadVersion++;
    setState(() {
      _calendarLoading = true;
      _calendarError = null;
      _loading = false;
      _date = null;
      _slot = null;
      _window = null;
      _customStart = null;
      _customEnd = null;
      _hasExplicitTimeSelection = false;
      _quote = null;
      _slots = [];
      _days = {};
      _error = null;
    });
    try {
      final days = await widget.service.monthSlots(
        widget.facility.id,
        _month,
        isCurrent: () => mounted && version == _monthVersion,
      );
      if (!mounted || version != _monthVersion) return;
      final initialSelection = initialDate == null
          ? null
          : FacilityBookingService.firstAvailableDate(
              days,
              onOrAfter: initialDate,
            );
      setState(() {
        _days = days;
        if (initialSelection != null) {
          _date = initialSelection;
          _slots = days[initialSelection]!;
          _resetTimeSelection();
        }
      });
    } catch (error) {
      if (mounted && version == _monthVersion) {
        setState(() => _calendarError = '$error');
      }
    } finally {
      if (mounted && version == _monthVersion) {
        setState(() => _calendarLoading = false);
      }
    }
  }

  void _changeMonth(int delta) {
    if (_busy) return;
    _month = DateTime(_month.year, _month.month + delta);
    _loadMonth();
  }

  Future<void> _loadSlots({bool preserveError = false}) async {
    final date = _date;
    if (date == null) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _slot = null;
      _window = null;
      _customStart = null;
      _customEnd = null;
      _hasExplicitTimeSelection = false;
      _slots = [];
      if (!preserveError) _error = null;
    });
    try {
      final slots = await widget.service.slots(widget.facility.id, date);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _days[date] = slots;
        _slots = slots;
        if (!slots.any(FacilityBookingService.isAvailableSlot)) {
          _date = null;
          _slots = [];
          _error = 'This date is no longer available. Select another date.';
        } else {
          _resetTimeSelection();
        }
      });
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _days.remove(date);
          _error = '$error';
        });
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _schedule => {
    'date': FacilityBookingService.dateKey(_date!),
    'start': _slot!['start'],
    'end': _slot!['end'],
  };

  TimeOfDay _clock(dynamic value) {
    final parts = '$value'.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _durationLabel(int minutes) => minutes % 60 == 0
      ? '${minutes ~/ 60} ${minutes == 60 ? 'hour' : 'hours'}'
      : '$minutes minutes';

  bool get _hasCustomHours =>
      _slots.any((slot) => slot['time_selection'] == 'custom') ||
      (_slots.isEmpty &&
          widget.facility.workflowConfig['operating_hours'] is Map);

  int _minutesBetween(String start, String end) {
    final first = _clock(start), last = _clock(end);
    return (last.hour - first.hour) * 60 + last.minute - first.minute;
  }

  int _slotDurationMinutes(Map<String, dynamic> slot) =>
      _minutesBetween('${slot['start']}', '${slot['end']}');

  void _resetTimeSelection() {
    // Loading a date's availability never chooses a booking window for the user.
    _window = null;
    _customStart = null;
    _customEnd = null;
    _hasExplicitTimeSelection = false;
    _slot = null;
  }

  Future<void> _pickTime(bool start) async {
    final window = _window, date = _date;
    if (_busy || window?['time_selection'] != 'custom') return;
    final initialValue = start
        ? (_customStart ?? '${window!['start']}')
        : (_customEnd ?? '${window!['end']}');
    _pickingTime = true;
    final picked = await showModalBottomSheet<TimeOfDay>(
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (_) => BookingTimeDialog(
        title: start ? 'Start Time' : 'End Time',
        initialTime: _clock(initialValue),
      ),
    );
    _pickingTime = false;
    if (!mounted ||
        picked == null ||
        _date != date ||
        !identical(_window, window)) {
      return;
    }
    _applyTime(start, picked, window!);
  }

  void _applyTime(bool start, TimeOfDay picked, Map<String, dynamic> window) {
    String key(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final first = start ? key(picked) : (_customStart ?? '${window['start']}');
    final last = start ? (_customEnd ?? '${window['end']}') : key(picked);
    final minimum = window['minimum_duration_minutes'];
    final minutes = _minutesBetween(first, last);
    setState(() {
      _customStart = first;
      _customEnd = last;
      _hasExplicitTimeSelection = true;
      _quote = null;
      if (first.compareTo('${window['start']}') < 0 ||
          last.compareTo('${window['end']}') > 0 ||
          first.compareTo(last) >= 0) {
        _slot = null;
        _error = 'Choose a start before the end, within ${window['label']}.';
      } else if (minimum is num && minutes < minimum) {
        _slot = null;
        _error =
            'Minimum booking duration is ${_durationLabel(minimum.toInt())}.';
      } else {
        _slot = {
          ...window,
          'start': first,
          'end': last,
          'label': '${bookingTime(first)} - ${bookingTime(last)}',
        };
        _error = null;
      }
    });
  }

  Widget _timeChoices() {
    final startVal = _customStart ?? '${_window!['start']}';
    final endVal = _customEnd ?? '${_window!['end']}';
    final minutes = _hasExplicitTimeSelection
        ? _minutesBetween(startVal, endVal)
        : 0;
    final hasInvalidDuration = _hasExplicitTimeSelection && _error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Select Booking Time',
          style: TextStyle(
            fontFamily: scheduleFont,
            fontVariations: [FontVariation('wght', 600)],
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: bookingNavy,
          ),
        ),
        if (_window?['minimum_duration_minutes'] is num &&
            (_window!['minimum_duration_minutes'] as num) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Minimum booking duration: ${_durationLabel((_window!['minimum_duration_minutes'] as num).toInt())}.',
              style: const TextStyle(
                fontFamily: scheduleFont,
                fontVariations: [FontVariation('wght', 400)],
                fontSize: 12,
                color: bookingMuted,
              ),
            ),
          ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackFields =
                constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            final width = stackFields
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final start in [true, false])
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          start ? 'Start Time' : 'End Time',
                          style: const TextStyle(
                            fontFamily: scheduleFont,
                            fontVariations: [FontVariation('wght', 500)],
                            fontSize: 12,
                            color: bookingMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          label: start ? 'Start Time' : 'End Time',
                          child: OutlinedButton(
                            key: ValueKey(
                              start ? 'booking-start-time' : 'booking-end-time',
                            ),
                            onPressed: _busy ? null : () => _pickTime(start),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: bookingNavy,
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              side: BorderSide(
                                color: hasInvalidDuration
                                    ? bookingRed.withValues(alpha: 0.5)
                                    : bookingOutline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    start
                                        ? bookingTime(startVal)
                                        : (_hasExplicitTimeSelection
                                              ? bookingTime(endVal)
                                              : 'Select time'),
                                    style: TextStyle(
                                      fontFamily: scheduleFont,
                                      fontVariations: const [
                                        FontVariation('wght', 600),
                                      ],
                                      fontSize: 14,
                                      color: hasInvalidDuration
                                          ? bookingRed
                                          : !start && !_hasExplicitTimeSelection
                                          ? bookingMuted
                                          : bookingNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: bookingMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          key: const ValueKey('booking-selected-duration'),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Selected Duration',
              style: TextStyle(
                fontFamily: scheduleFont,
                fontVariations: [FontVariation('wght', 500)],
                fontSize: 12,
                color: bookingMuted,
              ),
            ),
            Text(
              !_hasExplicitTimeSelection
                  ? 'Select start and end time'
                  : (minutes > 0
                        ? _durationLabel(minutes)
                        : 'Invalid time range'),
              style: TextStyle(
                fontFamily: scheduleFont,
                fontVariations: const [FontVariation('wght', 600)],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: !_hasExplicitTimeSelection
                    ? bookingMuted
                    : (hasInvalidDuration || minutes <= 0
                          ? bookingRed
                          : bookingNavy),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectionSummary() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      key: const ValueKey('schedule-selection-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bookingSurfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bookingOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in [
            (
              'Selected Date',
              bookingDate(FacilityBookingService.dateKey(_date!)),
            ),
            ('Start Time', bookingTime(_slot!['start'])),
            ('End Time', bookingTime(_slot!['end'])),
            ('Total Duration', _durationLabel(_slotDurationMinutes(_slot!))),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        fontFamily: scheduleFont,
                        fontVariations: [FontVariation('wght', 400)],
                        fontSize: 12,
                        color: bookingMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: scheduleFont,
                        fontVariations: [FontVariation('wght', 600)],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: bookingNavy,
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

  void _go(int step) {
    if (_submittedPayload != null && step != 3) return;
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _next() async {
    if (_busy ||
        _date == null ||
        _slot == null ||
        !FacilityBookingService.isAvailableSlot(_slot!)) {
      return;
    }
    if (_step == 1 && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step < 2) {
        final quote = await widget.service.request(
          'facilities/${widget.facility.id}/quote/',
          body: {
            ..._schedule,
            if (_step == 0) 'availability_only': true,
            if (_step == 1) ..._bookingInputs,
          },
        );
        if (!mounted) return;
        setState(() {
          _quote = quote;
          _loadPricingOptions(quote);
        });
        _go(_step + 1);
      } else {
        _submittedPayload ??= {
          ..._schedule,
          'facility_id': widget.facility.id,
          'request_key': _requestKey,
          'quoted_amount': _quote!['total_amount'],
          if (_quote!['quote_token'] != null)
            'quote_token': _quote!['quote_token'],
          ..._bookingInputs,
        };
        final response = await widget.service.request(
          'bookings/',
          body: _submittedPayload,
        );
        if (!mounted) return;
        setState(
          () => _booking = Map<String, dynamic>.from(response['booking']),
        );
        _go(3);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          if (_step == 2 && error is BookingException && !error.uncertain) {
            _submittedPayload = null;
            _quote = null;
            _step = 1;
          }
        });
        if (_step == 0) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
          await _loadSlots(preserveError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _bookingInputs => {
    for (final item in _fields.entries) item.key: item.value.text.trim(),
    'additional_requirements': _requirements.toList(),
    'fee_quantities': {
      for (final item in _feeFields.entries)
        item.key: item.value.text.trim().isEmpty ? '0' : item.value.text.trim(),
    },
  };

  List<String> _cleanRequirementOptions(List<dynamic> values) => values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  void _loadPricingOptions(Map<String, dynamic> response) {
    final options = response['pricing_options'];
    if (options is! Map) return;
    if (options['requirement_options'] is List) {
      _requirementOptions = _cleanRequirementOptions(
        options['requirement_options'] as List,
      );
      _requirements.removeWhere(
        (label) => !_requirementOptions.contains(label),
      );
      if (!_requirementOptions.contains('Others')) {
        _fields['other_requirements']!.clear();
      }
    }
    if (options['item_fees'] is! List) return;
    final fees = (options['item_fees'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final ids = fees.map((row) => '${row['index']}').toSet();
    for (final id in _feeFields.keys.toList()) {
      if (!ids.contains(id)) _feeFields.remove(id)?.dispose();
    }
    for (final row in fees) {
      final id = '${row['index']}';
      final previous = _itemFees.where((fee) => '${fee['index']}' == id);
      if (previous.isNotEmpty && previous.first['name'] != row['name']) {
        _feeFields[id]?.text = '0';
      }
      _feeFields.putIfAbsent(id, () => TextEditingController(text: '0'));
    }
    _itemFees = fees;
    if (!_requirementOptions.contains('Chairs')) {
      for (final fee in _itemFees.where(_chairFee)) {
        _feeFields['${fee['index']}']?.text = '0';
      }
    }
  }

  bool _chairFee(Map<String, dynamic> fee) => const [
    'chair',
    'chairs',
    'chair rental',
  ].contains('${fee['name']}'.trim().toLowerCase());

  // Ambiguous or unpriced configurations retain the existing quantity fields.
  Map<String, dynamic>? get _chairRentalFee {
    if (!_requirementOptions.contains('Chairs')) return null;
    final fees = _itemFees.where(_chairFee).toList();
    return fees.length == 1 &&
            chairUnitCentavos(fees.single['unit_amount']) != null
        ? fees.single
        : null;
  }

  Future<void> _editChairs() async {
    final fee = _chairRentalFee;
    if (_openingChairs || _busy || fee == null) return;
    final id = '${fee['index']}';
    final controller = _feeFields[id];
    if (controller == null) return;
    final unit = chairUnitCentavos(fee['unit_amount'])!;
    _openingChairs = true;
    try {
      final quantity = await showChairsQuantitySheet(
        context: context,
        currentQuantity: int.tryParse(controller.text) ?? 0,
        unitCentavos: unit,
      );
      if (!mounted || quantity == null || _step != 1) return;
      final currentFee = _chairRentalFee;
      if (!identical(_feeFields[id], controller) ||
          currentFee == null ||
          '${currentFee['index']}' != id ||
          chairUnitCentavos(currentFee['unit_amount']) != unit) {
        setState(
          () => _error =
              'Chair pricing changed. Review the current requirements.',
        );
        return;
      }
      setState(() {
        controller.text = '$quantity';
        if (quantity > 0) {
          _requirements.add('Chairs');
        } else {
          _requirements.remove('Chairs');
        }
      });
    } finally {
      _openingChairs = false;
    }
  }

  void _tapRequirement(String label) {
    if (label == 'Chairs' && _chairRentalFee != null) {
      unawaited(_editChairs());
    } else {
      _toggleRequirement(label);
    }
  }

  Widget _feeQuantity(Map<String, dynamic> fee) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 8),
    child: TextFormField(
      key: ValueKey('booking-fee-${fee['index']}'),
      controller: _feeFields['${fee['index']}'],
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, color: bookingNavy),
      decoration: InputDecoration(
        labelText: '${fee['name']} quantity',
        helperText:
            '${bookingMoney(fee['unit_amount'])} per item; enter 0 if not needed.',
        helperMaxLines: 2,
      ),
      validator: (value) {
        final count = int.tryParse(value?.trim() ?? '') ?? -1;
        if (count < 0 || count > chairQuantityLimit) {
          return 'Enter a whole number from 0 to 100000.';
        }
        if (_chairFee(fee) && _requirements.contains('Chairs') && count == 0) {
          return 'Enter the number of chairs required.';
        }
        return null;
      },
      onChanged: (value) {
        if (_chairFee(fee) && (int.tryParse(value) ?? 0) > 0) {
          setState(() => _requirements.add('Chairs'));
        }
      },
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool required = true,
    int lines = 1,
    TextInputType? keyboard,
    String? suffix,
    bool productStyle = false,
    bool showLabel = true,
    String? hintText,
  }) {
    final field = TextFormField(
      key: ValueKey('booking-field-$key'),
      controller: _fields[key],
      maxLines: lines,
      keyboardType: keyboard,
      style: productStyle
          ? AppTypography.input.copyWith(color: bookingNavy)
          : const TextStyle(fontSize: 14, color: bookingNavy),
      decoration: productStyle
          ? InputDecoration(
              hintText: hintText ?? 'Enter ${label.toLowerCase()}',
              suffixText: suffix,
              suffixStyle: AppTypography.helper.copyWith(color: bookingMuted),
              hintStyle: AppTypography.placeholder.copyWith(
                color: bookingMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(ProductFormStyle.radius),
                ),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(ProductFormStyle.radius),
                ),
                borderSide: BorderSide(color: ProductFormStyle.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(ProductFormStyle.radius),
                ),
                borderSide: BorderSide(color: bookingNavy, width: 1.8),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(ProductFormStyle.radius),
                ),
                borderSide: BorderSide(color: ProductFormStyle.error),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(ProductFormStyle.radius),
                ),
                borderSide: BorderSide(
                  color: ProductFormStyle.error,
                  width: 1.8,
                ),
              ),
              errorStyle: AppTypography.error.copyWith(
                color: ProductFormStyle.error,
              ),
              errorMaxLines: 3,
            )
          : InputDecoration(
              labelText: showLabel ? label : null,
              hintText: hintText,
              alignLabelWithHint: true,
              suffixText: suffix,
              suffixStyle: const TextStyle(color: bookingMuted, fontSize: 13),
            ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Enter ${label.toLowerCase()}.';
        if (key == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Enter a valid email address.';
        }
        if (key == 'attendees') {
          final count = int.tryParse(text) ?? 0;
          final capacity = int.tryParse(widget.facility.capacity) ?? 0;
          if (count < 1 || (capacity > 0 && count > capacity)) {
            return capacity > 0
                ? 'Enter 1 to $capacity attendees.'
                : 'Enter at least one attendee.';
          }
        }
        if (key == 'other_requirements' &&
            _requirements.contains('Others') &&
            text.isEmpty) {
          return 'Specify your requirements.';
        }
        return null;
      },
    );
    return Padding(
      padding: EdgeInsets.only(bottom: productStyle ? 16 : 14),
      child: productStyle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLabel) ...[
                  ProductFieldLabel('$label${required ? ' *' : ''}'),
                  const SizedBox(height: 8),
                ],
                Semantics(label: label, child: field),
              ],
            )
          : field,
    );
  }

  Widget _informationCard(String title, IconData icon, List<Widget> fields) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: BookingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: bookingNavy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.sectionTitle.copyWith(
                        color: bookingNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...fields,
            ],
          ),
        ),
      );

  Widget _requestorInformation() =>
      _informationCard('Requestor Information', Icons.person_outline, [
        _field('full_name', 'Full Name', productStyle: true),
        _field(
          'organization',
          'Organization / Office',
          required: false,
          productStyle: true,
        ),
        _field(
          'contact_number',
          'Contact Number',
          keyboard: TextInputType.phone,
          productStyle: true,
        ),
        _field(
          'email',
          'Email Address',
          keyboard: TextInputType.emailAddress,
          productStyle: true,
        ),
      ]);

  Widget _eventInformation() =>
      _informationCard('Event Information', Icons.event_outlined, [
        _field('event_name', 'Event / Activity Name', productStyle: true),
        _field('purpose', 'Purpose', productStyle: true),
        _field(
          'attendees',
          'Expected Number of Attendees',
          keyboard: TextInputType.number,
          suffix: 'persons',
          productStyle: true,
        ),
      ]);

  void _toggleRequirement(String label) => setState(() {
    if (_requirements.contains(label)) {
      _requirements.remove(label);
      if (label == 'Chairs') {
        for (final fee in _itemFees.where(_chairFee)) {
          _feeFields['${fee['index']}']?.text = '0';
        }
      }
    } else {
      _requirements.add(label);
    }
  });

  Widget _requirementCard(String label, IconData icon) {
    final selected = _requirements.contains(label);
    final chairFee = label == 'Chairs' ? _chairRentalFee : null;
    final chairQuantity = chairFee == null
        ? 0
        : int.tryParse(_feeFields['${chairFee['index']}']?.text ?? '') ?? 0;
    final chairSummary = chairFee == null
        ? null
        : selected && chairQuantity > 0
        ? '$chairQuantity ${chairQuantity == 1 ? 'chair' : 'chairs'} \u00b7 ${chairMoney(chairQuantity * chairUnitCentavos(chairFee['unit_amount'])!)}'
        : '${chairMoney(chairUnitCentavos(chairFee['unit_amount'])!)} per chair';
    void toggleSelection() {
      if (selected && chairFee != null) {
        _toggleRequirement(label);
      } else {
        _tapRequirement(label);
      }
    }

    return Semantics(
      key: ValueKey('booking-requirement-$label'),
      label: label,
      checked: selected,
      value: chairSummary,
      onTap: toggleSelection,
      onTapHint: selected && chairFee != null ? 'Remove Chairs' : null,
      customSemanticsActions: selected && chairFee != null
          ? {CustomSemanticsAction(label: 'Edit chairs quantity'): _editChairs}
          : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProductFormStyle.radius),
            side: BorderSide(color: selected ? bookingNavy : bookingOutline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InkWell(
                onTap: () => _tapRequirement(label),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: bookingNavy),
                          const Spacer(),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: selected ? bookingNavy : Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: selected ? bookingNavy : bookingGreyDot,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        label,
                        style: AppTypography.fieldLabel.copyWith(
                          color: bookingNavy,
                        ),
                      ),
                      if (chairSummary != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          chairSummary,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            fontVariations: [FontVariation('wght', 500)],
                            fontSize: 12,
                            color: bookingMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (chairFee != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Tooltip(
                    message: selected ? 'Remove Chairs' : 'Select Chairs',
                    child: InkWell(
                      key: const ValueKey('booking-requirement-toggle-Chairs'),
                      onTap: toggleSelection,
                      borderRadius: BorderRadius.circular(
                        ProductFormStyle.radius,
                      ),
                      child: const SizedBox(width: 48, height: 48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirementChoices() => LayoutBuilder(
    builder: (context, constraints) {
      final choices = [
        for (final label in _requirementOptions) (label, iconForAmenity(label)),
      ];
      if (choices.isEmpty) {
        return const Text(
          'No additional requirements are configured for this facility.',
          style: TextStyle(fontSize: 14, color: bookingMuted),
        );
      }
      final minCardWidth =
          130 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= minCardWidth * 2 + 10 ? 2 : 1;
      return Column(
        children: [
          for (var start = 0; start < choices.length; start += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var offset = 0; offset < columns; offset++) ...[
                      if (offset > 0) const SizedBox(width: 10),
                      Expanded(
                        child: start + offset < choices.length
                            ? _requirementCard(
                                choices[start + offset].$1,
                                choices[start + offset].$2,
                              )
                            : const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _step == 0 || _step == 3,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) _go(_step - 1);
    },
    child: BookingScaffold(
      schedulePresentation: _step == 0,
      flatAppBar: _step == 1 || _step == 2,
      title: [
        'Select Schedule',
        'Booking Details',
        'Review Booking',
        'Booking Submitted',
      ][_step],
      bottom: _step == 3
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BookingButton(
                  label: 'View Booking Details',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => FacilityBookingStatusScreen(
                          booking: _booking!,
                          service: widget.service,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                BookingButton(
                  label: 'Message Admin',
                  outlined: true,
                  onPressed: () =>
                      messageFacilitiesAdmin(context, widget.facility.id),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Facilities'),
                ),
              ],
            )
          : BookingButton(
              label: [
                'Next: Booking Details',
                'Next: Review Booking',
                'Submit Booking Request',
              ][_step],
              busy: _busy,
              fontFamily: _step == 0 ? scheduleFont : AppTypography.family,
              onPressed:
                  !widget.facility.isOpenForBooking ||
                      _loading ||
                      _date == null ||
                      _slot == null ||
                      (_step == 0 && (_calendarLoading || _error != null))
                  ? null
                  : _next,
            ),
      child: RefreshIndicator(
        onRefresh: _refreshAvailability,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (!widget.facility.isOpenForBooking)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(widget.facility.bookingStatusExplanation),
              ),
            BookingSteps(
              _step,
              connected: _step != 0,
              fontFamily: _step == 0 ? scheduleFont : AppTypography.family,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bookingRedBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bookingRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: bookingRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: bookingRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontVariations: _step == 0
                                ? const [FontVariation('wght', 600)]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_submittedPayload != null && _step == 2)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FacilityBookingHistoryScreen(service: widget.service),
                  ),
                ),
                child: const Text('Check My Bookings'),
              ),
            if (_step == 0) ...[
              const Text(
                'Select Date',
                style: TextStyle(
                  fontFamily: scheduleFont,
                  fontVariations: [FontVariation('wght', 600)],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: bookingNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose an available date for your booking.',
                style: TextStyle(
                  fontFamily: scheduleFont,
                  fontVariations: [FontVariation('wght', 400)],
                  fontSize: 12,
                  color: bookingMuted,
                ),
              ),
              const SizedBox(height: 8),
              if (_calendarLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Loading availability...',
                          style: TextStyle(
                            fontFamily: scheduleFont,
                            fontVariations: [FontVariation('wght', 400)],
                            fontSize: 12,
                            color: bookingMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              BookingScheduleCalendar(
                month: _month,
                selected: _date,
                days: _days,
                busy: _busy,
                onMonth: _changeMonth,
                onDate: (date) {
                  if (_busy ||
                      FacilityBookingService.dayStatus(_days[date]) !=
                          'available') {
                    return;
                  }
                  _date = date;
                  _loadSlots();
                },
              ),
              if (_calendarError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _calendarError!,
                  style: const TextStyle(
                    fontFamily: scheduleFont,
                    fontVariations: [FontVariation('wght', 400)],
                    color: bookingRed,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: () => _loadMonth(
                    initialDate: DateUtils.dateOnly(
                      FacilityBookingService.manilaNow(),
                    ),
                  ),
                  child: const Text(
                    'Retry Schedule',
                    style: TextStyle(
                      fontFamily: scheduleFont,
                      fontVariations: [FontVariation('wght', 500)],
                    ),
                  ),
                ),
              ],
              if (!_calendarLoading &&
                  _calendarError == null &&
                  !_days.values.any(
                    (slots) =>
                        slots.any(FacilityBookingService.isAvailableSlot),
                  ))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'No available dates in this month. Try another month.',
                    style: TextStyle(
                      fontFamily: scheduleFont,
                      fontVariations: [FontVariation('wght', 400)],
                      fontSize: 12,
                      color: bookingMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _hasCustomHours ? 'Available Hours' : 'Available Time Slots',
                style: const TextStyle(
                  fontFamily: scheduleFont,
                  fontVariations: [FontVariation('wght', 600)],
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: bookingNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _date == null
                    ? 'Choose an available date.'
                    : bookingDate(
                        FacilityBookingService.dateKey(_date!),
                        withWeekday: true,
                      ),
                key: const ValueKey('schedule-chosen-date'),
                style: const TextStyle(
                  fontFamily: scheduleFont,
                  fontVariations: [FontVariation('wght', 400)],
                  fontSize: 12,
                  color: bookingMuted,
                ),
              ),
              if (_date != null &&
                  !_loading &&
                  _slots.any(FacilityBookingService.isAvailableSlot) &&
                  _slots.any((s) => !FacilityBookingService.isAvailableSlot(s)))
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Remaining available hours for this date.',
                    style: TextStyle(
                      fontFamily: scheduleFont,
                      fontVariations: [FontVariation('wght', 400)],
                      fontSize: 11,
                      color: bookingMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null && _date != null && _slots.isEmpty)
                BookingButton(
                  label: 'Retry Schedule',
                  outlined: true,
                  fontFamily: scheduleFont,
                  onPressed: _loadSlots,
                )
              else if (_date != null && _slots.isEmpty)
                const Text(
                  'No time slots have been configured. Contact Facilities Admin.',
                  style: TextStyle(
                    fontFamily: scheduleFont,
                    fontVariations: [FontVariation('wght', 400)],
                    color: bookingMuted,
                  ),
                )
              else if (_date != null)
                ..._slots.where(FacilityBookingService.isAvailableSlot).map((
                  slot,
                ) {
                  final isCustom = slot['time_selection'] == 'custom';
                  final selected = _window == slot || _slot == slot;
                  final available = FacilityBookingService.isAvailableSlot(
                    slot,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: available && !_busy
                          ? () => setState(() {
                              _window = slot;
                              if (isCustom) {
                                _customStart = '${slot['start']}';
                                _customEnd = '${slot['end']}';
                                _hasExplicitTimeSelection = false;
                                _slot = null;
                              } else {
                                _slot = slot;
                                _customStart = null;
                                _customEnd = null;
                                _hasExplicitTimeSelection = false;
                              }
                              _quote = null;
                              _error = null;
                            })
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected ? bookingNavy : bookingOutline,
                          width: selected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isCustom) ...[
                            const Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: bookingNavy,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${slot['label']}',
                                  style: TextStyle(
                                    fontFamily: scheduleFont,
                                    fontVariations: [
                                      FontVariation(
                                        'wght',
                                        isCustom ? 600 : 500,
                                      ),
                                    ],
                                    fontSize: 13,
                                    fontWeight: isCustom
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: available
                                        ? bookingNavy
                                        : bookingMuted,
                                  ),
                                ),
                                if (isCustom) ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Available booking window',
                                    style: TextStyle(
                                      fontFamily: scheduleFont,
                                      fontVariations: [
                                        FontVariation('wght', 400),
                                      ],
                                      fontSize: 11,
                                      color: bookingMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!available)
                            Flexible(
                              child: Text(
                                bookingStatus(slot['status']?.toString() ?? ''),
                                style: const TextStyle(
                                  fontFamily: scheduleFont,
                                  fontVariations: [FontVariation('wght', 400)],
                                  fontSize: 11,
                                  color: bookingMuted,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (!available)
                            const Icon(
                              Icons.block,
                              size: 19,
                              color: bookingGreyDot,
                            )
                          else
                            Container(
                              key: const ValueKey('available-hours-circle-dot'),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? bookingNavy
                                      : bookingGreyDot,
                                  width: selected ? 2.0 : 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: selected
                                  ? Container(
                                      key: const ValueKey(
                                        'available-hours-inner-dot',
                                      ),
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: bookingNavy,
                                      ),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              if (_date != null && _window?['time_selection'] == 'custom')
                _timeChoices(),
              if (_date != null && _slot != null && _error == null)
                _selectionSummary(),
            ],
            if (_step == 1)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _requestorInformation(),
                    _eventInformation(),
                    BookingSection(
                      'Additional Requirements',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '(Select if needed)',
                            style: TextStyle(fontSize: 12, color: bookingMuted),
                          ),
                          const SizedBox(height: 10),
                          _requirementChoices(),
                          if (_requirements.contains('Others'))
                            _field(
                              'other_requirements',
                              'Please specify',
                              required: false,
                              productStyle: true,
                            ),
                          for (final fee in _itemFees)
                            if (!identical(fee, _chairRentalFee) &&
                                (!_chairFee(fee) ||
                                    _requirementOptions.contains('Chairs')))
                              _feeQuantity(fee),
                        ],
                      ),
                    ),
                    BookingSection(
                      'Additional Notes',
                      child: _field(
                        'notes',
                        'Additional Notes',
                        required: false,
                        lines: 3,
                        productStyle: true,
                        showLabel: false,
                        hintText:
                            'Add any details or instructions for your booking.',
                      ),
                    ),
                  ],
                ),
              ),
            if (_step == 2)
              BookingReviewSummary(
                date: _date!,
                start: _slot!['start'],
                end: _slot!['end'],
                details: _bookingInputs,
                quote: _quote!,
                termsConditions: widget.facility.termsConditions,
              ),
            if (_step == 3) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 54,
                      color: bookingNavy,
                    ),
                  ),
                ),
              ),
              const Text(
                'Booking Request Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: bookingNavy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your booking request has been successfully submitted. Please wait for the admin to review and approve your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: bookingMuted,
                ),
              ),
              const SizedBox(height: 22),
              BookingCard(
                child: Column(
                  children: [
                    BookingValue('Booking ID', _booking!['id'], bold: true),
                    BookingValue('Facility', widget.facility.name),
                    BookingValue('Date', bookingDate(_booking!['date'])),
                    BookingValue(
                      'Time',
                      '${bookingTime(_booking!['start'])} - ${bookingTime(_booking!['end'])}',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontSize: 12, color: bookingMuted),
                          ),
                          BookingStatusBadge(_booking!['status']),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
