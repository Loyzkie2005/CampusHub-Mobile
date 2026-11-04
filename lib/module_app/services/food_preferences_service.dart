import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../session/session_service.dart';
import 'auth_service.dart';

class FoodPreferenceException implements Exception {
  const FoodPreferenceException(this.message);
  final String message;
}

class FoodCategory {
  const FoodCategory(this.id, this.name);
  final String id, name;
}

class FoodPreferenceState {
  const FoodPreferenceState(this.user, this.categories);
  final AuthUser user;
  final List<FoodCategory> categories;
}

class FoodPreferencesService {
  const FoodPreferencesService();
  Future<FoodPreferenceState> load() => _request();
  Future<FoodPreferenceState> save(List<String> ids) =>
      _request({'action': 'save', 'category_ids': ids});
  Future<FoodPreferenceState> skip() => _request({'action': 'skip'});
  Future<FoodPreferenceState> finish() => _request({'action': 'finish'});

  Future<FoodPreferenceState> _request([Map<String, dynamic>? body]) async {
    final owner = await SessionService.loadUser();
    final token = await SessionService.loadChatToken();
    if (owner == null || token == null || token.isEmpty) {
      throw const FoodPreferenceException(
        'Please sign in again to save your preferences.',
      );
    }
    try {
      final uri = Uri.parse('${ApiConfig.mobileApi}/profile/preferences/');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? http.get(uri, headers: headers)
                  : http.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw FoodPreferenceException(
          data['error'] as String? ?? 'Unable to save preferences. Retry.',
        );
      }
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final current = await SessionService.loadUser();
      final currentToken = await SessionService.loadChatToken();
      if (user.id != owner.id ||
          current?.id != owner.id ||
          currentToken != token) {
        throw const FoodPreferenceException(
          'Your session changed. Reopen Preferences.',
        );
      }
      if (!await SessionService.updateUser(user, expectedToken: token)) {
        throw const FoodPreferenceException(
          'Your session changed. Reopen Preferences.',
        );
      }
      return FoodPreferenceState(
        user,
        (data['categories'] as List)
            .map(
              (item) =>
                  FoodCategory(item['id'] as String, item['name'] as String),
            )
            .toList(),
      );
    } on FoodPreferenceException {
      rethrow;
    } catch (_) {
      throw const FoodPreferenceException(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }
}
