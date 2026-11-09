import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../session/session_service.dart';

class SellerApplicationException implements Exception {
  const SellerApplicationException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

/// Uses the existing Django seller request contract; never activates access.
class SellerApplicationService {
  const SellerApplicationService();

  Future<Map<String, String>> _headers() async {
    final token = await SessionService.loadChatToken();
    if (token == null || token.isEmpty) {
      throw const SellerApplicationException(
        'Sign in again to manage your seller application.',
        statusCode: 401,
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> status([String? ignoredLegacyId]) async {
    for (final base in ApiConfig.serverBaseUrls) {
      try {
        final uri = Uri.parse('$base/api/seller/access-status/');
        final response = await http
            .get(uri, headers: await _headers())
            .timeout(const Duration(seconds: 5));
        final data = _decode(response);
        ApiConfig.recordWorkingBaseUrl(base);
        return data;
      } on SellerApplicationException {
        rethrow;
      } catch (_) {
        // Only a read request may fail over to another configured address.
      }
    }
    throw const SellerApplicationException(
      'Unable to load your application status. Check your connection and retry.',
    );
  }

  Future<Map<String, dynamic>> submit(Map<String, dynamic> fields) async {
    try {
      // Do not automatically retry a POST: a timeout may follow a saved request.
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.effectiveBaseUrl}/api/seller/access-request/',
            ),
            headers: await _headers(),
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } on SellerApplicationException {
      rethrow;
    } catch (_) {
      throw const SellerApplicationException(
        'Unable to confirm submission. Check your application status before trying again.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> products() async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/seller/products/submit/',
          ),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    return (data['products'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> workspace({
    String period = '30',
    int ordersPage = 1,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/workspace/',
          ).replace(
            queryParameters: {'period': period, 'orders_page': '$ordersPage'},
          ),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<void> suggestionChoice(String pairId, String action) async {
    // As with product submission, a POST must never be automatically retried.
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/suggestions/${Uri.encodeComponent(pairId)}/',
          ),
          headers: await _headers(),
          body: jsonEncode({'action': action}),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  Future<Map<String, dynamic>> recommendations(String source) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/recommendations/',
          ).replace(queryParameters: {'source': source}),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> recommendationAction(
    Map<String, dynamic> row,
    String action,
  ) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/recommendations/action/',
          ),
          headers: await _headers(),
          body: jsonEncode({
            'id': row['id'],
            'source': row['source'] ?? 'live',
            if (row.containsKey('revision')) 'revision': row['revision'],
            'action': action,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<bool> setSellerDelivery(bool enabled) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/delivery-setting/',
          ),
          headers: await _headers(),
          body: jsonEncode({'seller_delivery_enabled': enabled}),
        )
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    if (data['seller_delivery_enabled'] is! bool) {
      throw const SellerApplicationException(
        'Unable to confirm delivery settings. Refresh and retry.',
      );
    }
    return data['seller_delivery_enabled'] as bool;
  }

  Future<String> _receiptStorageKey(Object sku) async {
    final user = await SessionService.loadUser();
    if (user == null) {
      throw const SellerApplicationException('Sign in to receive stock.');
    }
    return 'campushub.receipt.${user.id}.$sku';
  }

  Future<Map<String, dynamic>?> pendingReceipt(Object sku) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(await _receiptStorageKey(sku));
    if (stored == null) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode(jsonDecode(stored)['details']) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> receiveStock(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _receiptStorageKey(payload['sku']);
    final details = jsonEncode(payload);
    Map<String, dynamic>? old;
    try {
      old = jsonDecode(prefs.getString(storageKey) ?? 'null');
    } catch (_) {
      /* New draft. */
    }
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final key = old?['details'] == details
        ? old!['key']
        : '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final draft = jsonEncode({'details': details, 'key': key});
    if (!await prefs.setString(storageKey, draft)) {
      throw const SellerApplicationException(
        'Unable to save a safe receipt retry. Please retry.',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/inventory/receive/',
            ),
            headers: await _headers(),
            body: jsonEncode({...payload, 'key': key}),
          )
          .timeout(const Duration(seconds: 20));
      _decode(response);
      if (prefs.getString(storageKey) == draft) await prefs.remove(storageKey);
    } on SellerApplicationException {
      rethrow;
    } catch (_) {
      throw const SellerApplicationException(
        'Unable to confirm the receipt. Retry this same draft safely; it will not add stock twice.',
      );
    }
  }

  Future<void> orderProgress(int orderId, String action) async {
    final response = await http
        .post(
          Uri.parse(
            '${ApiConfig.effectiveBaseUrl}/api/mobile/seller/orders/$orderId/progress/',
          ),
          headers: await _headers(),
          body: jsonEncode({'action': action}),
        )
        .timeout(const Duration(seconds: 15));
    _decode(response);
  }

  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> fields,
  ) async {
    try {
      if (fields.containsKey('initial_batches')) {
        // Older servers ignore unknown fields. Check support before any write
        // so separate receipts cannot silently become one undated quantity.
        final support = _decode(
          await http
              .get(
                Uri.parse(
                  '${ApiConfig.effectiveBaseUrl}/api/seller/products/submit/',
                ),
                headers: await _headers(),
              )
              .timeout(const Duration(seconds: 15)),
        );
        if (support['capabilities'] is! Map ||
            support['capabilities']['initial_batches'] != true) {
          throw const SellerApplicationException(
            'This server does not yet support initial batches. Your draft is preserved. Contact your administrator.',
          );
        }
        final batches = fields['initial_batches'];
        final hasExpiry =
            batches is List &&
            batches.any((row) => row is Map && row['expiry_date'] != null);
        if (hasExpiry &&
            support['capabilities']['initial_batch_expiry'] != true) {
          throw const SellerApplicationException(
            'This server does not yet support batch expiry dates. Your draft is preserved. Contact your administrator.',
          );
        }
      }
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.effectiveBaseUrl}/api/seller/products/submit/',
            ),
            headers: await _headers(),
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } on SellerApplicationException {
      rethrow;
    } catch (_) {
      throw const SellerApplicationException(
        'Unable to confirm product submission. Refresh My Products before trying again.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw const SellerApplicationException(
        'The server returned an unreadable response. Retry the status check.',
      );
    }
    if (data is! Map<String, dynamic>) {
      throw const SellerApplicationException(
        'The server returned an unreadable response. Retry the status check.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SellerApplicationException(
        data['error'] is String
            ? data['error'] as String
            : 'Unable to process the application. Please retry.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
