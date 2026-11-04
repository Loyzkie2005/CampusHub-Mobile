import 'package:campushub/module_app/theme/app_typography.dart';
// Standalone visual QA only; never imported by the normal app entry point.
// HTTP and preferences are memory-only: no real login, account writes or APIs.
import 'dart:convert';
import 'package:campushub/module_app/routes/app_routes.dart';
import 'package:campushub/module_app/screens/food_preferences_screen.dart';
import 'package:campushub/module_app/screens/profile_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> runOnboardingPreview() async {
  final backend = OnboardingPreviewBackend();
  await http.runWithClient(() async {
    // Binding and runApp share this zone so every widget request stays mocked.
    WidgetsFlutterBinding.ensureInitialized();
    backend.initializeMemoryOnly();
    runApp(OnboardingPreviewApp(backend: backend));
  }, () => backend.client());
}

class OnboardingPreviewBackend {
  static const token = 'preview-only-not-a-valid-login-token';
  static const food = [
    'Rice Meals',
    'Snacks',
    'Desserts',
    'Beverages',
    'Combo Meals',
    'Breakfast',
  ];
  final requests = <String>[];
  Map<String, dynamic> user = {};

  void initializeMemoryOnly() {
    user = {
      'id': -1,
      'username': 'preview-only',
      'email': 'preview@example.test',
      'first_name': 'Preview',
      'last_name': 'Only',
      'full_name': 'Preview Only',
      'role': 'User',
      'user_type': '',
      'profile_completed': false,
      'onboarding_stage': 'preferences',
      'preferred_category_ids': <String>[],
    };
    // Deliberately redirects the standalone QA isolate to an in-memory store.
    // It never reads/overwrites the device's real preferences or session.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'campushub_logged_user': jsonEncode(user),
      'campushub_chat_token': token,
    });
  }

  http.Client client() => MockClient((request) async {
    requests.add('${request.method} ${request.url.path}');
    Map<String, dynamic> result;
    if (request.method == 'GET' &&
        request.url.path.endsWith('/academic-options/')) {
      result = {
        'programs': [
          {
            'id': -101,
            'code': 'BSIT',
            'name': 'Information Technology (preview)',
          },
          {
            'id': -102,
            'code': 'BTLED',
            'name': 'Technology and Livelihood Education (preview)',
          },
          {
            'id': -103,
            'code': 'BFPT',
            'name': 'Food Processing Technology (preview)',
          },
        ],
        'majors': [
          {'id': -201, 'program_id': -102, 'name': 'Home Economics (preview)'},
          {'id': -202, 'program_id': -102, 'name': 'ICT (preview)'},
        ],
      };
    } else if (request.method == 'POST' &&
        request.url.path.endsWith('/profile/complete/')) {
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      user = {...user, ...data, 'profile_completed': true};
      result = {'user': user, 'chat_token': token};
    } else if ((request.method == 'GET' || request.method == 'POST') &&
        request.url.path.endsWith('/profile/preferences/')) {
      if (request.method == 'POST') {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        switch (data['action']) {
          case 'save':
            user['preferred_category_ids'] = data['category_ids'];
            if (user['onboarding_stage'] == 'preferences') {
              user['onboarding_stage'] = 'welcome';
            }
          case 'skip':
            user['onboarding_stage'] = 'welcome';
          case 'finish':
            user['onboarding_stage'] = 'complete';
        }
      }
      result = {
        'user': user,
        'categories': food.map((id) => {'id': id, 'name': id}).toList(),
      };
    } else {
      // No passthrough, even if a widget unexpectedly requests another endpoint.
      return http.Response(
        '{"error":"This action is unavailable in local preview."}',
        403,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

class OnboardingPreviewApp extends StatelessWidget {
  const OnboardingPreviewApp({super.key, required this.backend});
  final OnboardingPreviewBackend backend;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTypography.theme(
      ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.family,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1851)),
      ),
    ),
    builder: (context, child) => Column(
      children: [
        ColoredBox(
          color: const Color(0xFF1A1851),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'LOCAL PREVIEW — nothing is saved',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
    initialRoute: AppRoutes.profileSetup,
    routes: {
      AppRoutes.profileSetup: (_) => const ProfileSetupScreen(),
      AppRoutes.foodPreferences: (_) => const FoodPreferencesScreen(),
      AppRoutes.welcome: (_) => const CampusWelcomeScreen(),
      AppRoutes.dashboard: (_) =>
          _PreviewEnd(backend: backend, title: 'Preview complete'),
      AppRoutes.login: (_) =>
          _PreviewEnd(backend: backend, title: 'Preview restarted'),
    },
  );
}

class _PreviewEnd extends StatelessWidget {
  const _PreviewEnd({required this.backend, required this.title});
  final OnboardingPreviewBackend backend;
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'No account was created. No data was sent to Django.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                backend.initializeMemoryOnly();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (_) => false);
              },
              child: const Text('Preview Additional Information Again'),
            ),
          ],
        ),
      ),
    ),
  );
}
