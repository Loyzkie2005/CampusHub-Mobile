import 'package:campushub/module_app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/food_preferences_service.dart';
import '../session/session_service.dart';
import 'profile_setup_screen.dart';

abstract final class _FoodStyle {
  static const navy = Color(0xFF1A1851);
  static const gold = Color(0xFFFCB316);
  static const border = Color(0xFFE8EAF0);
  static const radius = BorderRadius.all(Radius.circular(14));
  static const spacing = 16.0;
  static const motion = Duration(milliseconds: 160);
  static ThemeData theme(BuildContext context) => AppTypography.theme(
    ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.family,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontVariations: [FontVariation('wght', 400)]),
        bodyLarge: TextStyle(fontVariations: [FontVariation('wght', 400)]),
        labelLarge: TextStyle(fontVariations: [FontVariation('wght', 600)]),
      ),
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        surface: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
    ),
  );
  static String emoji(String name) => switch (name) {
    'Rice Meals' => '🍚',
    'Snacks' => '🍿',
    'Desserts' => '🍰',
    'Beverages' => '🥤',
    'Combo Meals' => '🍱',
    'Breakfast' => '🍳',
    _ => '',
  };
}

class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({
    super.key,
    this.editing = false,
    this.service = const FoodPreferencesService(),
  });
  final bool editing;
  final FoodPreferencesService service;
  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  FoodPreferenceState? _data;
  final Set<String> _selected = {};
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.load();
      if (!mounted) return;
      if (!widget.editing && data.user.onboardingStage != 'preferences') {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.forUser(data.user), (_) => false);
        return;
      }
      setState(() {
        _data = data;
        _selected.clear();
        _selected.addAll(data.user.preferredCategoryIds);
      });
    } on FoodPreferenceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool skip = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = skip
          ? await widget.service.skip()
          : await widget.service.save(_selected.toList());
      if (!mounted) return;
      if (widget.editing) {
        Navigator.of(context).pop(data.user);
      } else {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.forUser(data.user), (_) => false);
      }
    } on FoodPreferenceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    if (widget.editing) {
      Navigator.of(context).pop();
      return;
    }
    final user = _data?.user ?? await SessionService.loadUser();
    if (!mounted) return;
    if (user == null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupScreen(editingUser: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _FoodStyle.theme(context),
    child: Builder(
      builder: (context) => PopScope(
        canPop: widget.editing && !_saving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            toolbarHeight:
                56 *
                (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 2.5),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: _saving ? null : _back,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              'Personalize',
              maxLines: 2,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontVariations: [FontVariation('wght', 700)],
              ),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'What food and drinks do you like?',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select your favorites to personalize your CampusHub experience.',
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (_data != null)
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final category in _data!.categories)
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: _card(category),
                              ),
                          ],
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: _FoodStyle.spacing),
                      Semantics(liveRegion: true, child: Text(_error!)),
                      if (_data == null)
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Retry'),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading || _saving || _data == null
                          ? null
                          : () => _save(),
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : widget.editing
                            ? 'Save Preferences'
                            : 'Continue',
                      ),
                    ),
                    if (!widget.editing)
                      TextButton(
                        onPressed: _saving ? null : () => _save(skip: true),
                        child: const Text('Skip for Now'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _card(FoodCategory category) {
    final selected = _selected.contains(category.id);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      enabled: !_saving,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _FoodStyle.motion,
        decoration: BoxDecoration(
          color: selected
              ? _FoodStyle.navy.withValues(alpha: .05)
              : Colors.white,
          borderRadius: _FoodStyle.radius,
          border: Border.all(
            color: selected ? _FoodStyle.navy : _FoodStyle.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: _FoodStyle.radius,
          child: InkWell(
            borderRadius: _FoodStyle.radius,
            onTap: _saving
                ? null
                : () => setState(() {
                    if (!_selected.add(category.id)) {
                      _selected.remove(category.id);
                    }
                    _error = null;
                  }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: ExcludeSemantics(
                        child: Text(
                          _FoodStyle.emoji(category.id),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1,
                            fontFamilyFallback: [
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                              'Noto Color Emoji',
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          fontVariations: [FontVariation('wght', 600)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: selected
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                color: _FoodStyle.navy,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: _FoodStyle.gold,
                                size: 14,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CampusWelcomeScreen extends StatefulWidget {
  const CampusWelcomeScreen({
    super.key,
    this.service = const FoodPreferencesService(),
  });
  final FoodPreferencesService service;
  @override
  State<CampusWelcomeScreen> createState() => _CampusWelcomeScreenState();
}

class _CampusWelcomeScreenState extends State<CampusWelcomeScreen> {
  bool _busy = false;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await widget.service.load();
      if (!mounted) return;
      if (state.user.onboardingStage != 'welcome') {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.forUser(state.user), (_) => false);
      }
    } on FoodPreferenceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.service.finish();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.forUser(data.user), (_) => false);
      }
    } on FoodPreferenceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _back() async {
    if (!_busy) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.foodPreferences),
          builder: (_) =>
              FoodPreferencesScreen(editing: true, service: widget.service),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _FoodStyle.theme(context),
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: _busy ? null : _back,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome to CampusHub! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "You're all set! Explore campus products and discover your favorites.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_error!),
                        ),
                      ),
                    if (_error != null)
                      TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Retry'),
                      ),
                    FilledButton(
                      onPressed: _busy || _loading || _error != null
                          ? null
                          : _finish,
                      child: Text(_busy ? 'Saving...' : 'Get Started'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
