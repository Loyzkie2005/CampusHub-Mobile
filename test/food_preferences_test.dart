import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:campushub/module_app/routes/app_routes.dart';
import 'package:campushub/module_app/screens/food_preferences_screen.dart';
import 'package:campushub/module_app/screens/profile_setup_screen.dart';
import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/services/food_preferences_service.dart';
import 'package:campushub/module_app/session/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const categories = [
  'Rice Meals',
  'Snacks',
  'Desserts',
  'Beverages',
  'Combo Meals',
  'Breakfast',
];
Map<String, dynamic> userJson({
  String stage = 'preferences',
  List<String> ids = const [],
}) => {
  'id': 7,
  'username': 'onboarding-test',
  'email': 'onboarding@example.test',
  'first_name': 'Test',
  'last_name': 'Owner',
  'full_name': 'Test Owner',
  'role': 'User',
  'user_type': 'guest',
  'profile_completed': true,
  'contact_number': '09171234567',
  'onboarding_stage': stage,
  'preferred_category_ids': ids,
};

class MemoryPreferences extends FoodPreferencesService {
  String stage = 'preferences';
  List<String> ids = [];
  bool failLoad = false;
  int saves = 0, skips = 0;
  FoodPreferenceState get state => FoodPreferenceState(
    AuthUser.fromJson(userJson(stage: stage, ids: ids)),
    categories.map((name) => FoodCategory(name, name)).toList(),
  );
  @override
  Future<FoodPreferenceState> load() async {
    if (failLoad) {
      throw const FoodPreferenceException('Connection unavailable.');
    }
    return state;
  }

  @override
  Future<FoodPreferenceState> save(List<String> selections) async {
    ids = [...selections];
    saves++;
    if (stage == 'preferences') stage = 'welcome';
    return state;
  }

  @override
  Future<FoodPreferenceState> skip() async {
    skips++;
    stage = 'welcome';
    return state;
  }

  @override
  Future<FoodPreferenceState> finish() async {
    stage = 'complete';
    return state;
  }
}

Widget app(
  MemoryPreferences service, {
  bool editing = false,
  double textScale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  routes: {
    AppRoutes.welcome: (_) => CampusWelcomeScreen(service: service),
    AppRoutes.dashboard: (_) => const Scaffold(body: Text('Home destination')),
    AppRoutes.foodPreferences: (_) => FoodPreferencesScreen(service: service),
  },
  home: RepaintBoundary(
    key: const ValueKey('preference-render'),
    child: FoodPreferencesScreen(service: service, editing: editing),
  ),
);

Future<void> seedSession() async {
  SharedPreferences.setMockInitialValues({
    'campushub_logged_user': jsonEncode(userJson()),
    'campushub_chat_token': 'isolated-token',
    'campushub_remember_login': true,
  });
}

void main() {
  test(
    'routing distinguishes required profile, preferences, welcome and returning users',
    () {
      expect(
        AppRoutes.forUser(
          AuthUser.fromJson({...userJson(), 'profile_completed': false}),
        ),
        AppRoutes.profileSetup,
      );
      expect(
        AppRoutes.forUser(AuthUser.fromJson(userJson())),
        AppRoutes.foodPreferences,
      );
      expect(
        AppRoutes.forUser(AuthUser.fromJson(userJson(stage: 'welcome'))),
        AppRoutes.welcome,
      );
      expect(
        AppRoutes.forUser(AuthUser.fromJson(userJson(stage: 'complete'))),
        AppRoutes.dashboard,
      );
      expect(
        AppRoutes.forUser(AuthUser.fromJson({'profile_completed': true})),
        AppRoutes.dashboard,
      );
    },
  );

  test(
    'real service saves backend IDs and preserves per-account session metadata',
    () async {
      await seedSession();
      await http.runWithClient(
        () async {
          final result = await const FoodPreferencesService().save(categories);
          expect(result.user.preferredCategoryIds, categories);
          final cached = await SessionService.loadUser();
          expect(cached!.onboardingStage, 'welcome');
          expect(cached.preferredCategoryIds, categories);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer isolated-token');
          expect(request.url.path, '/api/mobile/profile/preferences/');
          expect(jsonDecode(request.body)['category_ids'], categories);
          return http.Response(
            jsonEncode({
              'user': userJson(stage: 'welcome', ids: categories),
              'categories': categories
                  .map((name) => {'id': name, 'name': name})
                  .toList(),
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'service rejects cross-account responses without replacing session',
    () async {
      await seedSession();
      await http.runWithClient(
        () async {
          await expectLater(
            const FoodPreferencesService().load(),
            throwsA(isA<FoodPreferenceException>()),
          );
          expect((await SessionService.loadUser())!.id, 7);
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'user': {...userJson(), 'id': 99},
              'categories': [],
            }),
            200,
          ),
        ),
      );
    },
  );

  testWidgets('all six can be selected, continued and welcomed before Home', (
    tester,
  ) async {
    final service = MemoryPreferences();
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    for (final name in categories) {
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.check), findsNWidgets(6));
    expect(find.textContaining('Choose up to'), findsNothing);
    await tester.scrollUntilVisible(find.text('Continue'), 180);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(service.ids.toSet(), categories.toSet());
    expect(find.text('Welcome to CampusHub! 🎉'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(service.stage, 'complete');
  });

  testWidgets(
    'skip discards unsaved choices and remains optional after a load error',
    (tester) async {
      final service = MemoryPreferences();
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snacks'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Skip for Now'), 180);
      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();
      expect(service.ids, isEmpty);
      expect(service.saves, 0);
      expect(service.skips, 1);
      expect(find.text('Welcome to CampusHub! 🎉'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final unavailable = MemoryPreferences()..failLoad = true;
      await tester.pumpWidget(app(unavailable));
      await tester.pumpAndSettle();
      expect(find.text('Connection unavailable.'), findsOneWidget);
      await seedSession();
      await http.runWithClient(
        () async {
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byType(ProfileSetupScreen), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        },
        () => MockClient(
          (_) async => http.Response('{"programs":[],"majors":[]}', 200),
        ),
      );
      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();
      expect(unavailable.skips, 1);
    },
  );

  testWidgets(
    'onboarding back edits existing profile without losing selections',
    (tester) async {
      final service = MemoryPreferences();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(app(service));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Snacks'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byType(ProfileSetupScreen), findsOneWidget);
          expect(find.text('Edit Profile'), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.check), findsOneWidget);
          expect(service.stage, 'preferences');
        },
        () => MockClient(
          (_) async => http.Response('{"programs":[],"majors":[]}', 200),
        ),
      );
    },
  );

  testWidgets(
    'completed users are not re-onboarded and Profile edit stays in editor',
    (tester) async {
      final service = MemoryPreferences()
        ..stage = 'complete'
        ..ids = ['Snacks'];
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(service, editing: true));
      await tester.pumpAndSettle();
      expect(find.text('Personalize'), findsOneWidget);
      expect(find.text('Skip for Now'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    },
  );

  testWidgets(
    'first login completes required information before food preferences',
    (tester) async {
      await seedSession();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: const ProfileSetupScreen(),
              routes: {
                AppRoutes.foodPreferences: (_) =>
                    FoodPreferencesScreen(service: MemoryPreferences()),
              },
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Guest / Visitor').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), '09171234567');
          await tester.tap(find.text('Finish'));
          await tester.pumpAndSettle();
          expect(find.text('Personalize'), findsOneWidget);
          expect(
            (await SessionService.loadUser())!.onboardingStage,
            'preferences',
          );
        },
        () => MockClient((request) async {
          if (request.url.path.contains('academic-options')) {
            return http.Response('{"programs":[],"majors":[]}', 200);
          }
          expect(request.url.path.endsWith('/profile/complete/'), isTrue);
          expect(jsonDecode(request.body)['user_type'], 'guest');
          return http.Response(
            jsonEncode({
              'user': userJson(),
              'chat_token': 'updated-test-token',
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets(
    'contact validation clears and stays reachable above a small-screen keyboard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: const EdgeInsets.only(bottom: 220)),
                child: child!,
              ),
              home: ProfileSetupScreen(
                editingUser: AuthUser.fromJson(userJson()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), '123');
          await tester.ensureVisible(find.text('Save Changes'));
          await tester.tap(find.text('Save Changes'));
          await tester.pumpAndSettle();
          expect(
            find.text('Enter a valid Philippine mobile number.'),
            findsOneWidget,
          );
          await tester.enterText(find.byType(TextFormField), '09171234567');
          await tester.pumpAndSettle();
          expect(
            find.text('Enter a valid Philippine mobile number.'),
            findsNothing,
          );
          await tester.ensureVisible(find.text('Save Changes'));
          await tester.pumpAndSettle();
          expect(find.text('Save Changes').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => http.Response('{"programs":[],"majors":[]}', 200),
        ),
      );
    },
  );

  testWidgets(
    'Welcome back opens Preferences for editing without resetting completion',
    (tester) async {
      final service = MemoryPreferences()
        ..stage = 'welcome'
        ..ids = ['Snacks'];
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Personalize'), findsOneWidget);
      await tester.tap(find.text('Beverages'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Save Preferences'), 180);
      await tester.tap(find.text('Save Preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to CampusHub! 🎉'), findsOneWidget);
      expect(service.stage, 'welcome');
      expect(service.ids.toSet(), {'Snacks', 'Beverages'});
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('two-column cards fit a small screen at text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(MemoryPreferences(), textScale: scale));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Rice Meals'), 160);
      final rice = tester.getRect(find.text('Rice Meals'));
      final snacks = tester.getRect(find.text('Snacks'));
      expect(snacks.left, greaterThan(rice.right));
      final emoji = tester.getRect(find.text('🍚'));
      expect(emoji.right, lessThanOrEqualTo(rice.left));
      expect((emoji.center.dy - rice.center.dy).abs(), lessThan(1));
      if (scale == 1) {
        final card = find
            .ancestor(
              of: find.text('Rice Meals'),
              matching: find.byType(AnimatedContainer),
            )
            .first;
        expect(tester.getSize(card).height, lessThan(112));
        expect(
          (tester.getCenter(find.text('Personalize')).dx - 160).abs(),
          lessThan(1),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Continue'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
    });
  }

  testWidgets(
    'render real selectable cards with bundled Montserrat for visual review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final font = FontLoader('Montserrat')
        ..addFont(
          rootBundle.load('assets/fonts/Montserrat-VariableFont_wght.ttf'),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      await tester.pumpWidget(app(MemoryPreferences()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice Meals'));
      await tester.tap(find.text('Beverages'));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preference-render')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../scratch/personalized-onboarding-20261027/preferences-390.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    },
  );
}
