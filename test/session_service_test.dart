import 'dart:async';
import 'dart:convert';

import 'package:campushub/module_app/config/api_config.dart';
import 'package:campushub/module_app/routes/app_routes.dart';
import 'package:campushub/module_app/screens/startup_gate.dart';
import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/session/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> identity(int id, {String? name}) => {
  'id': id,
  'username': 'account-$id',
  'email': 'account-$id@example.test',
  'first_name': name ?? 'Account $id',
  'full_name': name ?? 'Account $id',
  'user_type': 'student',
  'profile_completed': true,
};

AuthUser user(int id, {String? name}) =>
    AuthUser.fromJson(identity(id, name: name));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.clearUser();
    ApiConfig.recordWorkingBaseUrl('http://localhost:8000');
  });

  Future<void> save(int id, {String? token, bool remember = true}) =>
      SessionService.saveUser(
        user(id),
        chatToken: token ?? 'token-$id',
        remember: remember,
      );

  test(
    'latest login replaces the previous saved account across startup',
    () async {
      await save(1);
      await save(2);
      var requests = 0;
      await http.runWithClient(
        () async {
          final restored = await SessionService.restoreUser();
          expect(restored?.id, 2);
          expect(restored?.email, 'account-2@example.test');
          expect((await SessionService.loadUser())?.id, 2);
          expect(await SessionService.loadChatToken(), 'token-2');
        },
        () => MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          expect(request.url.path, '/api/mobile/profile/photo/');
          expect(request.headers['Authorization'], 'Bearer token-2');
          return http.Response(jsonEncode({'user': identity(2)}), 200);
        }),
      );
      expect(requests, 1);
    },
  );

  test(
    'startup refreshes profile only for the authenticated same account',
    () async {
      await save(1);
      await http.runWithClient(
        () async {
          expect(await SessionService.isLoggedIn(), isTrue);
          expect((await SessionService.loadUser())?.fullName, 'Updated name');
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'user': identity(1, name: 'Updated name')}),
            200,
          ),
        ),
      );
    },
  );

  for (final status in [401, 403, 404]) {
    test(
      'startup rejects HTTP $status without trying another server',
      () async {
        await save(1);
        var requests = 0;
        await http.runWithClient(
          () async {
            expect(await SessionService.restoreUser(), isNull);
            expect(await SessionService.loadUser(), isNull);
            expect(await SessionService.loadChatToken(), isNull);
          },
          () => MockClient((_) async {
            requests++;
            return http.Response('{"error":"User account not found."}', status);
          }),
        );
        expect(requests, 1);
      },
    );
  }

  test(
    'cached account and bearer account mismatch returns Login, not either identity',
    () async {
      await save(1, token: 'token-2');
      await http.runWithClient(
        () async {
          expect(await SessionService.restoreUser(), isNull);
          expect(await SessionService.loadUser(), isNull);
          expect(await SessionService.loadChatToken(), isNull);
        },
        () => MockClient(
          (_) async => http.Response(jsonEncode({'user': identity(2)}), 200),
        ),
      );
    },
  );

  for (final fixture in [
    {
      'campushub_logged_user': jsonEncode(identity(1)),
      'campushub_remember_login': true,
    },
    {
      'campushub_logged_user': '{broken',
      'campushub_chat_token': 'token-1',
      'campushub_remember_login': true,
    },
    {
      'campushub_logged_user': jsonEncode(identity(0)),
      'campushub_chat_token': 'token-0',
      'campushub_remember_login': true,
    },
    {
      'campushub_logged_user': jsonEncode(identity(1)),
      'campushub_chat_token': 'token-1',
      'campushub_remember_login': false,
    },
  ]) {
    test(
      'incomplete or non-remembered session cannot restore: $fixture',
      () async {
        SharedPreferences.setMockInitialValues(fixture);
        await http.runWithClient(
          () async {
            expect(await SessionService.restoreUser(), isNull);
            expect(await SessionService.loadUser(), isNull);
            expect(await SessionService.loadChatToken(), isNull);
          },
          () => MockClient(
            (_) async => fail('Incomplete sessions must not call the server'),
          ),
        );
      },
    );
  }

  for (final failure in ['offline', 'invalid-json', 'server-error']) {
    test(
      '$failure cannot authenticate cache and preserves it for retry',
      () async {
        await save(1);
        await http.runWithClient(
          () async {
            expect(await SessionService.restoreUser(), isNull);
            expect((await SessionService.loadUser())?.id, 1);
            expect(await SessionService.loadChatToken(), 'token-1');
          },
          () => MockClient((_) async {
            if (failure == 'offline') throw http.ClientException('offline');
            return http.Response(
              failure == 'invalid-json' ? '<html>' : '{}',
              failure == 'server-error' ? 503 : 200,
            );
          }),
        );
      },
    );
  }

  for (final status in [200, 401]) {
    test(
      'late startup HTTP $status cannot overwrite or clear a new login',
      () async {
        await save(1);
        final started = Completer<void>();
        final response = Completer<http.Response>();
        await http.runWithClient(
          () async {
            final restore = SessionService.restoreUser();
            await started.future;
            await save(2);
            response.complete(
              http.Response(jsonEncode({'user': identity(1)}), status),
            );
            expect(await restore, isNull);
            expect((await SessionService.loadUser())?.id, 2);
            expect(await SessionService.loadChatToken(), 'token-2');
          },
          () => MockClient((_) {
            started.complete();
            return response.future;
          }),
        );
      },
    );
  }

  test('logout wins over an in-flight startup response', () async {
    await save(1);
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final restore = SessionService.restoreUser();
        await started.future;
        await SessionService.clearUser();
        response.complete(
          http.Response(jsonEncode({'user': identity(1)}), 200),
        );
        expect(await restore, isNull);
        expect(await SessionService.loadUser(), isNull);
      },
      () => MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
  });

  test(
    'a changed stored snapshot wins over an in-flight startup response',
    () async {
      await save(1);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      await http.runWithClient(
        () async {
          final restore = SessionService.restoreUser();
          await started.future;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'campushub_logged_user',
            jsonEncode(identity(2)),
          );
          await prefs.setString('campushub_chat_token', 'token-2');
          ApiConfig.recordWorkingBaseUrl('http://new-login-server:8000');
          response.complete(
            http.Response(jsonEncode({'user': identity(1)}), 200),
          );
          expect(await restore, isNull);
          expect((await SessionService.loadUser())?.id, 2);
          expect(await SessionService.loadChatToken(), 'token-2');
          expect(ApiConfig.effectiveBaseUrl, 'http://new-login-server:8000');
        },
        () => MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
    },
  );

  test('a missing route is not treated as a deleted account', () async {
    await save(1);
    await http.runWithClient(
      () async {
        expect(await SessionService.restoreUser(), isNull);
        expect((await SessionService.loadUser())?.id, 1);
        expect(await SessionService.loadChatToken(), 'token-1');
      },
      () =>
          MockClient((_) async => http.Response('<html>Not found</html>', 404)),
    );
  });

  test(
    'late old-account profile update cannot replace the new account',
    () async {
      await save(1);
      await save(2);
      expect(await SessionService.updateUser(user(1)), isFalse);
      expect((await SessionService.loadUser())?.id, 2);
      expect(await SessionService.loadChatToken(), 'token-2');
    },
  );

  test('old token cannot update a newer login for the same account', () async {
    await save(1, token: 'old-token');
    await save(1, token: 'new-token');
    expect(
      await SessionService.updateUser(
        user(1, name: 'Stale'),
        expectedToken: 'old-token',
      ),
      isFalse,
    );
    expect((await SessionService.loadUser())?.fullName, 'Account 1');
    expect(await SessionService.loadChatToken(), 'new-token');
    expect(
      await SessionService.updateUser(
        user(1, name: 'Current'),
        expectedToken: 'new-token',
      ),
      isTrue,
    );
    expect((await SessionService.loadUser())?.fullName, 'Current');
  });

  test('profile update cannot recreate a logged-out session', () async {
    await save(1);
    await SessionService.clearUser();
    expect(await SessionService.updateUser(user(1)), isFalse);
    expect(await SessionService.loadUser(), isNull);
  });

  test(
    'overlapping logins persist one coherent final profile and token',
    () async {
      final first = save(1);
      final second = save(2);
      await Future.wait([first, second]);
      expect((await SessionService.loadUser())?.id, 2);
      expect(await SessionService.loadChatToken(), 'token-2');
    },
  );

  test('new login without token cannot inherit the previous bearer', () async {
    await save(1);
    await SessionService.saveUser(user(2));
    expect(await SessionService.loadChatToken(), isNull);
    expect(await SessionService.restoreUser(), isNull);
  });

  for (final matches in [true, false]) {
    testWidgets(
      'cold startup routes only a verified matching account: $matches',
      (tester) async {
        await save(1);
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: const StartupGate(),
                routes: {
                  AppRoutes.dashboard: (_) =>
                      const Scaffold(body: Text('Verified Home')),
                  AppRoutes.login: (_) =>
                      const Scaffold(body: Text('Sign in again')),
                },
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(matches ? 'Verified Home' : 'Sign in again'),
              findsOneWidget,
            );
            expect(
              find.text(matches ? 'Sign in again' : 'Verified Home'),
              findsNothing,
            );
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({'user': identity(matches ? 1 : 2)}),
              200,
            ),
          ),
        );
      },
    );
  }
}
