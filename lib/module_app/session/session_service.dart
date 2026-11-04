import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/push_device_api.dart';
import '../services/push_notification_service.dart';

/// Persists the logged-in user across app restarts.
class SessionService {
  SessionService._();

  static const String _userKey = 'campushub_logged_user';
  static const String _chatTokenKey = 'campushub_chat_token';
  static const String _rememberKey = 'campushub_remember_login';
  static Future<void>? _writes;
  static int _generation = 0;

  // Keep the profile/token/remember writes together when asynchronous account
  // operations overlap. A failed write must not stall later logout/login.
  static Future<T> _write<T>(Future<T> Function() operation) {
    final previous = _writes;
    final completed = Completer<void>();
    _writes = completed.future;
    return () async {
      try {
        if (previous != null) await previous;
        return await operation();
      } finally {
        if (identical(_writes, completed.future)) _writes = null;
        completed.complete();
      }
    }();
  }

  static String _encodeUser(AuthUser user) {
    return jsonEncode({
      'id': user.id,
      'username': user.studentId,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'full_name': user.fullName,
      'role': user.role,
      'user_type': user.userType,
      'program_id': user.programId,
      'major_id': user.majorId,
      'program': user.program,
      'major': user.major,
      'student_id': user.profileStudentId,
      'institutional_id': user.institutionalId,
      'contact_number': user.contactNumber,
      'year_section': user.yearSection,
      'profile_photo_url': user.profilePhotoUrl,
      'profile_completed': user.profileCompleted,
      'onboarding_stage': user.onboardingStage,
      'preferred_category_ids': user.preferredCategoryIds,
      'email_verified': user.emailVerified,
    });
  }

  /// Save the user after successful login.
  static Future<void> saveUser(
    AuthUser user, {
    String? chatToken,
    bool remember = true,
  }) {
    _generation++;
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      // An interrupted save must not leave an older login restorable.
      await prefs.setBool(_rememberKey, false);
      await prefs.remove(_chatTokenKey);
      await prefs.setString(_userKey, _encodeUser(user));
      if (chatToken != null && chatToken.isNotEmpty) {
        await prefs.setString(_chatTokenKey, chatToken);
      }
      await prefs.setBool(_rememberKey, remember);
      _syncPushSession(user, prefs.getString(_chatTokenKey));
    });
  }

  static Future<String?> loadChatToken() async {
    final pending = _writes;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chatTokenKey);
  }

  static Future<bool> updateUser(
    AuthUser user, {
    String? chatToken,
    String? expectedToken,
  }) {
    final generation = _generation;
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation ||
          _readUser(prefs)?.id != user.id ||
          (expectedToken != null &&
              prefs.getString(_chatTokenKey) != expectedToken)) {
        return false;
      }
      await prefs.setString(_userKey, _encodeUser(user));
      if (chatToken != null && chatToken.isNotEmpty) {
        await prefs.setString(_chatTokenKey, chatToken);
      }
      _syncPushSession(user, prefs.getString(_chatTokenKey));
      return true;
    });
  }

  /// Load the user (returns null if not logged in).
  static Future<AuthUser?> loadUser() async {
    final pending = _writes;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    return _readUser(prefs);
  }

  static AuthUser? _readUser(SharedPreferences prefs) {
    final data = prefs.getString(_userKey);
    if (data == null) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear the user session (logout).
  static Future<void> clearUser() {
    _generation++;
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await _clearStoredSession(prefs);
    });
  }

  static Future<void> _clearStoredSession(SharedPreferences prefs) async {
    await prefs.setBool(_rememberKey, false);
    await prefs.remove(_userKey);
    await prefs.remove(_chatTokenKey);
    await prefs.remove(_rememberKey);
    await PushNotificationService.instance.clearSession();
  }

  /// Restore only a complete saved login that Django confirms still belongs to
  /// the cached account. Offline failures preserve storage but open Login.
  static Future<AuthUser?> restoreUser() async {
    final pending = _writes;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    final generation = _generation;
    final cached = _readUser(prefs);
    final token = prefs.getString(_chatTokenKey);
    final remember = prefs.getBool(_rememberKey);
    final complete =
        remember == true &&
        cached != null &&
        cached.id > 0 &&
        token != null &&
        token.isNotEmpty;
    final validation = complete
        ? await AuthService.restoreSession(token)
        : (user: null, rejected: true, baseUrl: null);
    return _write(() async {
      // Logout or another login wins over an older startup request.
      if (generation != _generation ||
          _readUser(prefs)?.id != cached?.id ||
          prefs.getString(_chatTokenKey) != token ||
          prefs.getBool(_rememberKey) != remember) {
        return null;
      }
      final user = validation.user;
      if (validation.rejected || (user != null && user.id != cached?.id)) {
        _generation++;
        await _clearStoredSession(prefs);
        return null;
      }
      if (user == null) {
        _syncPushSession(null, null);
        return null;
      }
      await prefs.setString(_userKey, _encodeUser(user));
      if (validation.baseUrl != null) {
        ApiConfig.recordWorkingBaseUrl(validation.baseUrl!);
      }
      _syncPushSession(user, token);
      return user;
    });
  }

  static Future<bool> isLoggedIn() async => await restoreUser() != null;

  static void _syncPushSession(AuthUser? user, String? token) {
    PushNotificationService.instance.setSession(
      user != null && token != null && token.isNotEmpty
          ? PushSession(userId: user.id, token: token)
          : null,
    );
  }
}
