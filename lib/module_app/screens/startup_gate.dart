import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../session/session_service.dart';
import 'splash_screen.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  /// Resolved destination route — null while still loading.
  String? _destinationRoute;

  /// Whether the splash animation has finished playing.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _resolveDestination();
  }

  /// Determines login / dashboard / profile-setup and stores result.
  /// If the splash already finished, navigates immediately.
  Future<void> _resolveDestination() async {
    final user = await SessionService.restoreUser();

    if (!mounted) return;

    final route = user == null ? AppRoutes.login : AppRoutes.forUser(user);

    _destinationRoute = route;

    // If the splash animation already completed while we were loading,
    // navigate straight away; otherwise wait for the splash callback.
    if (_splashDone) {
      _navigate();
    }
  }

  /// Called by the splash screen when its animation finishes.
  void _onSplashFinished() {
    _splashDone = true;

    // Navigate only if the session check has already resolved.
    if (_destinationRoute != null) {
      _navigate();
    }
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(_destinationRoute!);
  }

  @override
  Widget build(BuildContext context) {
    return CampusHubIntroScreen(onFinished: _onSplashFinished);
  }
}
