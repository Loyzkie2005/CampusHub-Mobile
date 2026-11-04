import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../session/session_service.dart';

class OrderSubmission {
  const OrderSubmission({
    this.confirmed = false,
    this.uncertain = false,
    this.message = '',
    this.order,
  });
  final bool confirmed, uncertain;
  final String message;
  final Map<String, dynamic>? order;
}

class OrderService {
  OrderService._();

  static const String _historyKey = 'campushub_order_history';
  static String requestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<bool> placeOrder({
    required Map<String, dynamic> order,
    String? operationKey,
  }) async {
    return (await submitOrder(
      order: order,
      operationKey: operationKey,
    )).confirmed;
  }

  static Future<List<Map<String, dynamic>>> quote(
    List<Map<String, dynamic>> items,
  ) async {
    final token = await SessionService.loadChatToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sign in before checkout.');
    }
    final response = await http
        .post(
          Uri.parse('${ApiConfig.effectiveBaseUrl}/api/orders/quote/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'items': items}),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['items'] is! List) {
      throw Exception(
        data is Map
            ? data['error'] ?? 'Unable to check checkout.'
            : 'Unable to check checkout.',
      );
    }
    final rows = (data['items'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (rows.length != items.length) {
      throw Exception('Incomplete checkout pricing. Retry.');
    }
    for (var i = 0; i < rows.length; i++) {
      final price = double.tryParse('${rows[i]['unit_price']}');
      final total = double.tryParse('${rows[i]['total']}');
      final subtotal = double.tryParse('${rows[i]['subtotal']}');
      if (rows[i]['product_id'] != items[i]['product_id'] ||
          rows[i]['quantity'] != items[i]['quantity'] ||
          price == null ||
          !price.isFinite ||
          price < 0 ||
          total == null ||
          !total.isFinite ||
          total < 0 ||
          subtotal == null ||
          !subtotal.isFinite ||
          subtotal < 0 ||
          (subtotal - price * (items[i]['quantity'] as int)).abs() > .005 ||
          (total - subtotal).abs() > .005 ||
          double.tryParse('${rows[i]['delivery_fee']}') != 0) {
        throw Exception('Unable to verify the final payable amount.');
      }
    }
    return rows;
  }

  static Future<OrderSubmission> submitOrder({
    required Map<String, dynamic> order,
    String? operationKey,
  }) async {
    final key = operationKey ?? requestKey();
    final token = await SessionService.loadChatToken();
    // A POST timeout may follow a committed order; retry only explicitly with the same key.
    for (final baseUrl in [ApiConfig.effectiveBaseUrl]) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/orders/'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Idempotency-Key': key,
                if (token != null && token.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
              body: jsonEncode(order),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map ||
              decoded['order'] is! Map ||
              decoded['order']['id'] == null) {
            return const OrderSubmission(
              uncertain: true,
              message:
                  'Unable to confirm the response. Retry the same submission.',
            );
          }
          ApiConfig.recordWorkingBaseUrl(baseUrl);
          final saved = Map<String, dynamic>.from(decoded['order'] as Map);
          try {
            await saveOrderHistory(saved);
          } catch (_) {
            /* API already confirmed creation. */
          }
          return OrderSubmission(confirmed: true, order: saved);
        }
        final data = jsonDecode(response.body);
        return OrderSubmission(
          uncertain:
              response.statusCode >= 500 ||
              response.statusCode == 408 ||
              response.statusCode == 429,
          message: data is Map
              ? '${data['error'] ?? 'Unable to place this order.'}'
              : 'Unable to place this order.',
        );
      } catch (_) {}
    }
    return const OrderSubmission(
      uncertain: true,
      message:
          'Connection interrupted. Retry to check the same submission; your original details are preserved.',
    );
  }

  static Future<void> saveOrderHistory(Map<String, dynamic> order) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadOrderHistory();
    history.insert(0, {
      ...order,
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_historyKey, jsonEncode(history.take(30).toList()));
  }

  static Future<List<Map<String, dynamic>>> loadOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((row) => row.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }
}
