import '../services/auth_service.dart';

abstract final class AppRoutes {
  static const String startup = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profileSetup = '/profile-setup';
  static const String foodPreferences = '/food-preferences';
  static const String welcome = '/welcome';
  static const String dashboard = '/dashboard';
  static const String sellerDashboard = '/seller-dashboard';
  static const String services = '/services';
  static const String serviceDetails = '/services/details';
  static const String notificationProduct = '/notifications/product';

  static String forUser(AuthUser user) {
    if (!user.profileCompleted) return profileSetup;
    return switch (user.onboardingStage) {
      'preferences' => foodPreferences,
      'welcome' => welcome,
      _ => dashboard,
    };
  }
}
