import 'package:flutter/foundation.dart';
import '../session/session_service.dart';
import 'order_service.dart';

/// A quote never reserves stock. Django checks again inside the order transaction.
class CheckoutValidation extends ChangeNotifier {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> quotes = [];
  int _generation = 0;
  bool _disposed = false;
  bool get ready => !loading && error == null && quotes.isNotEmpty;
  bool get deliverySupported =>
      ready && quotes.every((row) => row['delivery_supported'] == true);
  double get subtotal =>
      quotes.fold(0, (sum, row) => sum + double.parse('${row['subtotal']}'));

  Future<void> refresh(List<Map<String, dynamic>> items) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (await SessionService.loadUser() == null) {
        throw Exception('Sign in before checkout.');
      }
      final result = await OrderService.quote(items);
      if (_disposed || generation != _generation) return;
      quotes = result;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure.toString().replaceFirst('Exception: ', '');
      quotes = [];
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    notifyListeners();
  }

  static bool validLocation(String value) =>
      value.trim().length >= 5 &&
      value.trim().length <= 500 &&
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value);
  bool canSubmit(String method, String location) =>
      ready &&
      (method == 'pickup' ||
          (method == 'seller_delivery' &&
              deliverySupported &&
              validLocation(location)));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
