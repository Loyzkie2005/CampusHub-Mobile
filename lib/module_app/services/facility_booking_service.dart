import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../session/session_service.dart';

class BookingException implements Exception {
  const BookingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FacilityBookingService {
  const FacilityBookingService();

  static String newRequestKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await SessionService.loadChatToken();
    if (token == null) throw const BookingException('Sign in to continue.');
    final uri = Uri.parse('${ApiConfig.effectiveBaseUrl}/api/mobile/$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      final response =
          await (body == null
                  ? http.get(uri, headers: headers)
                  : http.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BookingException(
          decoded['error']?.toString() ?? 'Unable to complete the request.',
        );
      }
      return decoded;
    } on BookingException {
      rethrow;
    } catch (_) {
      throw const BookingException(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> slots(
    String facilityId,
    DateTime date,
  ) async {
    final result = await request(
      'facilities/${Uri.encodeComponent(facilityId)}/availability/?date=${dateKey(date)}',
    );
    return (result['slots'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// A calendar date is a Manila civil date, independent of phone timezone.
  static DateTime manilaNow([DateTime? instant]) =>
      (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 8));

  /// Fetch a coherent month through the existing availability endpoint.
  /// Missing/malformed days fail closed as an API error, never a closed month.
  Future<Map<DateTime, List<Map<String, dynamic>>>> monthSlots(
    String facilityId,
    DateTime month, {
    bool Function()? isCurrent,
  }) async {
    final today = manilaNow();
    final firstDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(today.year + 2);
    final dates = <DateTime>[
      for (var i = 1; i <= DateTime(month.year, month.month + 1, 0).day; i++)
        if (!DateTime(month.year, month.month, i).isBefore(firstDate) &&
            !DateTime(month.year, month.month, i).isAfter(lastDate))
          DateTime(month.year, month.month, i),
    ];
    final result = <DateTime, List<Map<String, dynamic>>>{};
    if (dates.isEmpty || !(isCurrent?.call() ?? true)) return result;
    final monthKey = dateKey(DateTime(month.year, month.month)).substring(0, 7);
    final payload = await request(
      'facilities/${Uri.encodeComponent(facilityId)}/availability/?month=$monthKey',
    );
    if (!(isCurrent?.call() ?? true)) return result;
    try {
      if (payload['month'] != monthKey || payload['days'] is! List) {
        throw const FormatException();
      }
      final rows = <String, Map<String, dynamic>>{};
      for (final raw in payload['days'] as List) {
        final row = Map<String, dynamic>.from(raw);
        if (rows.containsKey(row['date'])) throw const FormatException();
        rows[row['date'] as String] = row;
      }
      for (final date in dates) {
        final row = rows[dateKey(date)];
        if (row == null || row['slots'] is! List) throw const FormatException();
        result[date] = (row['slots'] as List)
            .map((slot) => Map<String, dynamic>.from(slot))
            .toList();
        if (row['status'] != dayStatus(result[date])) {
          throw const FormatException();
        }
      }
    } catch (_) {
      throw const BookingException('Unable to read availability. Try again.');
    }
    return result;
  }

  static bool isAvailableSlot(Map<String, dynamic> slot) {
    if (slot['status'] != 'available') return false;
    int? minutes(dynamic value) {
      final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('$value');
      if (match == null) return null;
      final hour = int.parse(match[1]!);
      final minute = int.parse(match[2]!);
      return hour < 24 && minute < 60 ? hour * 60 + minute : null;
    }

    final start = minutes(slot['start']), end = minutes(slot['end']);
    return start != null && end != null && start < end;
  }

  /// A partly occupied day is bookable only through its remaining open slots.
  static String dayStatus(List<Map<String, dynamic>>? slots) {
    if (slots == null) return 'unknown';
    if (slots.any(isAvailableSlot)) return 'available';
    for (final status in ['maintenance', 'class', 'blocked', 'reserved']) {
      if (slots.any((slot) => slot['status'] == status)) return status;
    }
    return 'not_bookable';
  }

  /// Choose only a date whose loaded server response has a valid open period.
  static DateTime? firstAvailableDate(
    Map<DateTime, List<Map<String, dynamic>>> days, {
    required DateTime onOrAfter,
  }) {
    final earliest = DateTime(onOrAfter.year, onOrAfter.month, onOrAfter.day);
    final available =
        days.entries
            .where(
              (entry) =>
                  !entry.key.isBefore(earliest) &&
                  entry.value.any(isAvailableSlot),
            )
            .map((entry) => entry.key)
            .toList()
          ..sort();
    return available.isEmpty ? null : available.first;
  }

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
