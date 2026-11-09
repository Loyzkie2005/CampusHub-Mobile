import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local SUS samples. Deliberately has no marketplace/API dependency.
class DemoBundleStore {
  const DemoBundleStore(this.sellerId);
  final int sellerId;
  String get storageKey => 'campushub_demo_bundles_v1_seller_$sellerId';
  static Future<void>? _pending;

  static bool validPair(Map pair) {
    final products = pair['products'];
    if (pair['source'] != 'synthetic' ||
        '${pair['id'] ?? ''}'.trim().isEmpty ||
        '${pair['revision'] ?? ''}'.trim().isEmpty ||
        products is! List ||
        products.length != 2) {
      return false;
    }
    final identities = <String>{};
    for (final product in products) {
      if (product is! Map || '${product['name'] ?? ''}'.trim().isEmpty) {
        return false;
      }
      final identity = '${product['source_id'] ?? product['id'] ?? ''}';
      if (identity.isEmpty) return false;
      identities.add(identity);
    }
    return identities.length == 2;
  }

  static String identity(Map pair) =>
      jsonEncode([pair['source'], pair['revision'], pair['id']]);

  Future<List<Map<String, dynamic>>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>?> find(Map pair) async {
    for (final record in await list()) {
      if (record['id'] == identity(pair)) return record;
    }
    return null;
  }

  // Serialize read-modify-write operations, including callers on other routes.
  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _pending == null
        ? action()
        : _pending!.then((_) => action());
    late final Future<void> completion;
    void clear() {
      if (identical(_pending, completion)) _pending = null;
    }

    completion = result.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    _pending = completion;
    return result;
  }

  Future<Map<String, dynamic>> save({
    required Map<String, dynamic> pair,
    required String name,
    required List<int> quantities,
    required String price,
    bool editing = false,
  }) => _mutate(() async {
    final amount = double.tryParse(price);
    if (!validPair(pair) ||
        name.trim().isEmpty ||
        name.trim().length > 150 ||
        quantities.length != 2 ||
        quantities.any((q) => q < 1) ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(price)) {
      throw const FormatException(
        'Enter a name, positive quantities and a valid demo price.',
      );
    }
    final records = await list();
    final id = identity(pair);
    final index = records.indexWhere((record) => record['id'] == id);
    if (index >= 0 && !editing) return records[index]; // Idempotent create.
    if (index < 0 && editing) {
      throw StateError('This demo was deleted. Return to suggestions.');
    }
    final record = <String, dynamic>{
      'id': id,
      'source': 'synthetic',
      'demo_only': true,
      'recommendation': jsonDecode(
        jsonEncode(pair),
      ), // Preserve source snapshot.
      'name': name.trim(),
      'quantities': quantities.toList(),
      'price': amount.toStringAsFixed(2),
      'created_at': index < 0
          ? DateTime.now().toUtc().toIso8601String()
          : records[index]['created_at'],
    };
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await _write(records);
    return record;
  });

  Future<void> delete(String id) => _mutate(() async {
    final records = await list();
    records.removeWhere((record) => record['id'] == id);
    await _write(records);
  });

  Future<void> _write(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(storageKey, jsonEncode(records))) {
        throw StateError('Demo storage did not confirm saving. Please retry.');
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform confirms writes.
      // Reload prevents a failed write from being mistaken for a saved sample.
      await prefs.reload();
      rethrow;
    }
  }
}
