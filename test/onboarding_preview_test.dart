import 'dart:convert';
import 'package:campushub/module_app/screens/profile_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../tool/qa/onboarding_preview.dart';

void main() {
  testWidgets(
    'preview opens real Additional Information without login and finishes entirely in memory',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'real-session-fixture': 'preserve',
      });
      final previousStore = await SharedPreferences.getInstance();
      final backend = OnboardingPreviewBackend()..initializeMemoryOnly();
      await http.runWithClient(() async {
        await tester.pumpWidget(OnboardingPreviewApp(backend: backend));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(find.text('LOCAL PREVIEW — nothing is saved'), findsOneWidget);
        expect(find.text('Additional Information'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guest / Visitor').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '09170000000');
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        expect(find.text('Personalize'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Skip for Now'), 180);
        await tester.tap(find.text('Skip for Now'));
        await tester.pumpAndSettle();
        expect(find.text('Welcome to CampusHub! 🎉'), findsOneWidget);
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.text('Preview complete'), findsOneWidget);
        expect(
          backend.requests.any(
            (path) => path.contains('/login/') || path.contains('/signup/'),
          ),
          isFalse,
        );
        expect(previousStore.getString('real-session-fixture'), 'preserve');
        await tester.tap(find.text('Preview Additional Information Again'));
        await tester.pumpAndSettle();
        expect(find.text('Additional Information'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => backend.client());
    },
  );

  test(
    'unexpected network requests are blocked rather than forwarded',
    () async {
      final backend = OnboardingPreviewBackend()..initializeMemoryOnly();
      final client = backend.client();
      final response = await client.post(
        Uri.parse('https://example.test/api/mobile/signup/'),
        body: jsonEncode({}),
      );
      expect(response.statusCode, 403);
      final deleted = await client.delete(
        Uri.parse('https://example.test/api/mobile/profile/preferences/'),
      );
      expect(deleted.statusCode, 403);
      client.close();
    },
  );
}
