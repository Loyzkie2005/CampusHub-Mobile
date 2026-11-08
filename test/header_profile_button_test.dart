import 'package:campushub/module_app/services/auth_service.dart';
import 'package:campushub/module_app/widgets/navigation/header_profile_button.dart';
import 'package:campushub/module_app/widgets/navigation/campushub_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [280.0, 320.0, 414.0, 768.0]) {
    testWidgets(
      'profile identity preserves actions with long names at $width and 2x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final user = AuthUser.fromJson({
          'id': 1,
          'full_name':
              'A very long authenticated account name that must fit the header',
          'profile_photo_url': '',
        });
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: Row(
                  children: [
                    const SizedBox(width: 48, child: Icon(Icons.menu)),
                    Expanded(
                      child: HeaderProfileButton(
                        user: user,
                        onPressed: () => taps++,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: () {},
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {},
                      icon: const Icon(Icons.notifications),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(user.fullName), findsOneWidget);
        expect(find.byType(CampusHubBrand), findsNothing);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(HeaderProfileButton)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byType(HeaderProfileButton));
        expect(taps, 1);
      },
    );
  }

  for (final showGreeting in [false, true]) {
    testWidgets(
      'actual profile image and fallback are preserved; greeting=$showGreeting',
      (tester) async {
        final user = AuthUser.fromJson({
          'id': 1,
          'full_name': 'Test Buyer',
          'profile_photo_url': 'http://localhost:8000/media/test-profile.jpg',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                child: HeaderProfileButton(
                  user: user,
                  onPressed: () {},
                  greeting: showGreeting ? 'Welcome Back,' : null,
                  outlinedAvatar: showGreeting,
                  onDarkSurface: showGreeting,
                  actionLabel: showGreeting ? 'Open menu' : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(
          (avatar.foregroundImage as NetworkImage).url,
          user.resolvedProfilePhotoUrl,
        );
        expect(avatar.onForegroundImageError, isNotNull);
        expect(
          tester.widget<Text>(find.text(user.fullName)).style!.color,
          showGreeting ? Colors.white : const Color(0xFF1A1851),
        );
        final outline = find.byKey(const ValueKey('header-profile-outline'));
        expect(outline, showGreeting ? findsOneWidget : findsNothing);
        if (showGreeting) {
          final decoration =
              tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
          expect(decoration.shape, BoxShape.circle);
          expect(decoration.gradient!.colors, [
            const Color(0xFF1A1851),
            const Color(0xFFFCB315),
            const Color(0xFF1A1851),
          ]);
          expect(tester.getSize(outline), const Size(44, 44));
        }
        expect(find.text('T'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing full name uses real name parts and missing account uses Profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: HeaderProfileButton(
                user: AuthUser.fromJson({
                  'first_name': 'Actual',
                  'last_name': 'Name',
                }),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Actual Name'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: HeaderProfileButton(onPressed: () {}),
            ),
          ),
        ),
      );
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Actual Name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
