import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../session/session_service.dart';
import '../home/home_preview_cards.dart';
import '../profile/profile_widgets.dart';

abstract final class _DrawerStyle {
  static const rowHeight = 48.0;
  static const iconSize = 20.0;
  static const chevronSize = 16.0;
  static const radius = 8.0;
  // Grouped-card layout (Design B): white rounded cards with subtle gray borders.
  static const cardRadius = 16.0;
  static const indicatorWidth = 3.5;
  // Exact design token colors from the design specification.
  static const ink = Color(0xFF0B1F3A);
  static const gold = Color(0xFFFCB316);
  static const muted = HomeAppColors.mutedText;
  static const border = Color(0xFFE3E7EF);
  static const selectedSurface = Color(0xFFF4F5F9);
  static const chevronColor = Color(0xFFA8B1BF);

  static TextStyle text(double size, Color color, {int weight = 500}) =>
      InterTypography.sized(size, weight: weight, color: color);
}

// Keep workspace destinations intact: Home still links to saved suggestions.
// Visible labels and section headers match the Design B reference screen.
enum SellerDestination {
  overview('Home', 'MAIN', Iconsax.home_2_copy),
  purchases('My Purchases', 'MAIN', Iconsax.bag_2_copy),
  bookings('My Bookings', 'MAIN', Iconsax.calendar_tick_copy),
  products('My Products', 'SELLER TOOLS', Iconsax.box_copy),
  inventory('Inventory', 'SELLER TOOLS', Iconsax.category_2_copy),
  orders('Orders Received', 'SELLER TOOLS', Iconsax.shopping_cart_copy),
  bundles('My Bundles', 'SELLER TOOLS', Iconsax.box_add_copy),
  analytics('Sales Analytics', 'SELLER TOOLS', Iconsax.chart_21_copy),
  recommendations(
    'Suggested Product Bundles',
    'RECOMMENDATIONS',
    Iconsax.lamp_on_copy,
  ),
  messages('Messages', 'MESSAGES', Iconsax.message_copy),
  settings('Account Settings', 'ACCOUNT', Iconsax.setting_2_copy);

  const SellerDestination(this.label, this.section, this.icon);
  final String label, section;
  final IconData icon;
}

/// One drawer for both roles. Approval is supplied by the existing API check.
class CampusHubDrawer extends StatelessWidget {
  const CampusHubDrawer({
    super.key,
    required this.user,
    required this.sellerApproved,
    required this.onSelected,
    this.selected,
    this.onProfile,
  });

  final AuthUser? user;
  final bool sellerApproved;
  final SellerDestination? selected;
  final ValueChanged<SellerDestination> onSelected;
  final VoidCallback? onProfile;

  static const sellerDestinations = [
    SellerDestination.products,
    SellerDestination.inventory,
    SellerDestination.orders,
    SellerDestination.bundles,
    SellerDestination.analytics,
  ];

  // Sections: MAIN, SELLER TOOLS (approved sellers only), MESSAGES.
  // Account Settings is accessed through Profile > Account & Security.
  List<SellerDestination> get destinations => [
    SellerDestination.overview,
    SellerDestination.purchases,
    SellerDestination.bookings,
    if (sellerApproved) ...sellerDestinations,
    SellerDestination.messages,
  ];

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !navigator.mounted) return;
    // Same existing logout sequence as Profile; no new authentication behavior.
    await ChatService.instance.disconnect();
    await SessionService.clearUser();
    if (navigator.mounted) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  /// White rounded container with a subtle border grouping section menu items.
  Widget _card({Key? key, required List<Widget> children}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _DrawerStyle.border),
      borderRadius: BorderRadius.circular(_DrawerStyle.cardRadius),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );

  Widget _entry(BuildContext context, SellerDestination item) {
    final active = selected == item;
    return Semantics(
      selected: active,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Material(
          color: active ? _DrawerStyle.selectedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('seller-menu-${item.name}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelected(item),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (active)
                  Positioned(
                    key: ValueKey('seller-menu-indicator-${item.name}'),
                    left: 8,
                    top: 11,
                    bottom: 11,
                    child: Container(
                      width: _DrawerStyle.indicatorWidth,
                      decoration: BoxDecoration(
                        color: _DrawerStyle.gold,
                        borderRadius: BorderRadius.circular(
                          _DrawerStyle.indicatorWidth / 2,
                        ),
                      ),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(
                    minHeight: _DrawerStyle.rowHeight,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          item.icon,
                          size: _DrawerStyle.iconSize,
                          color: _DrawerStyle.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          style: _DrawerStyle.text(
                            14,
                            _DrawerStyle.ink,
                            weight: 500,
                          ),
                        ),
                      ),
                      if (item == SellerDestination.messages)
                        AnimatedBuilder(
                          animation: ChatService.instance,
                          builder: (context, _) {
                            final unread = ChatService.instance.conversations
                                .fold<int>(
                                  0,
                                  (sum, row) => sum + row.unreadCount,
                                );
                            if (unread <= 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Badge(
                                backgroundColor: _DrawerStyle.gold,
                                textColor: _DrawerStyle.ink,
                                label: Text(unread > 99 ? '99+' : '$unread'),
                              ),
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Icon(
                          Iconsax.arrow_right_3_copy,
                          size: _DrawerStyle.chevronSize,
                          color: _DrawerStyle.chevronColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String section) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        section,
        style: _DrawerStyle.text(
          11,
          _DrawerStyle.muted,
          weight: 600,
        ).copyWith(letterSpacing: .6),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // The sidebar surface is pure white.
    const ink = _DrawerStyle.ink;
    const muted = HomeAppColors.secondaryText;
    const surface = Colors.white;
    final fullName = user?.fullName.trim() ?? '';
    final parts = [
      user?.firstName.trim() ?? '',
      user?.lastName.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    final name = fullName.isNotEmpty
        ? fullName
        : parts.isNotEmpty
        ? parts
        : user?.studentId.trim().isNotEmpty == true
        ? user!.studentId.trim()
        : 'Your account';
    final academic = [
      user?.program.trim() ?? '',
      user?.yearSection.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' \u00b7 ');
    final photo = user?.resolvedProfilePhotoUrl ?? '';
    final entries = destinations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: surface,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Drawer(
        semanticLabel: 'CampusHub navigation',
        width: (MediaQuery.sizeOf(context).width * .90).clamp(0.0, 360.0),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                // Vertically scrollable menu for smaller screens.
                child: ListView(
                  key: const ValueKey('seller-navigation-list'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    Tooltip(
                      message: 'Open Profile',
                      child: InkWell(
                        onTap: onProfile,
                        borderRadius: BorderRadius.circular(
                          _DrawerStyle.radius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Semantics(
                                label: 'Profile avatar for $name',
                                image: true,
                                excludeSemantics: true,
                                child: CircleAvatar(
                                  key: const ValueKey('seller-profile-avatar'),
                                  radius: 24,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: ink,
                                  foregroundImage: photo.isEmpty
                                      ? null
                                      : NetworkImage(photo),
                                  onForegroundImageError: photo.isEmpty
                                      ? null
                                      : (_, _) {},
                                  child: photo.isEmpty
                                      ? const Icon(
                                          Iconsax.user_copy,
                                          size: 24,
                                          color: ink,
                                        )
                                      : Text(
                                          name.characters.first.toUpperCase(),
                                          style: ProfileStyle.identityText(
                                            18,
                                            color: ink,
                                            weight: 600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: ProfileStyle.identityText(
                                        16,
                                        color: ink,
                                        weight: 600,
                                      ),
                                    ),
                                    if (academic.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        academic,
                                        style: ProfileStyle.identityText(
                                          12,
                                          color: muted,
                                          weight: 400,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Iconsax.arrow_right_3_copy,
                                size: _DrawerStyle.chevronSize,
                                color: _DrawerStyle.chevronColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Divider(
                        key: ValueKey('seller-profile-divider'),
                        height: 1,
                        thickness: 1,
                        color: _DrawerStyle.border,
                      ),
                    ),
                    for (final section
                        in entries.map((item) => item.section).toSet()) ...[
                      _sectionHeading(section),
                      _card(
                        key: ValueKey('seller-menu-group-$section'),
                        children: [
                          for (final item in entries.where(
                            (item) => item.section == section,
                          ))
                            _entry(context, item),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Logout is a clean row separated by a divider, matching Design B.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _DrawerStyle.border,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('campushub-drawer-logout'),
                        borderRadius: BorderRadius.circular(
                          _DrawerStyle.radius,
                        ),
                        onTap: () => _logout(context),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _DrawerStyle.rowHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const ExcludeSemantics(
                                  child: Icon(
                                    Iconsax.logout_copy,
                                    color: ink,
                                    size: _DrawerStyle.iconSize,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Logout',
                                    style: _DrawerStyle.text(
                                      14,
                                      ink,
                                      weight: 500,
                                    ),
                                  ),
                                ),
                                const ExcludeSemantics(
                                  child: Icon(
                                    Iconsax.arrow_right_3_copy,
                                    size: _DrawerStyle.chevronSize,
                                    color: _DrawerStyle.chevronColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compatibility wrapper used by the approved seller workspace.
class SellerDrawer extends StatelessWidget {
  const SellerDrawer({
    super.key,
    required this.user,
    required this.selected,
    required this.onSelected,
    this.onBackToCampusHub,
    this.onProfile,
  });
  final AuthUser user;
  final SellerDestination selected;
  final ValueChanged<SellerDestination> onSelected;
  final VoidCallback? onBackToCampusHub, onProfile;
  static const drawerDestinations = [
    ...CampusHubDrawer.sellerDestinations,
    SellerDestination.messages,
  ];
  @override
  Widget build(BuildContext context) => CampusHubDrawer(
    user: user,
    sellerApproved: true,
    selected: selected,
    onSelected: (destination) {
      if (destination == SellerDestination.overview &&
          onBackToCampusHub != null) {
        Navigator.pop(context);
        onBackToCampusHub!();
      } else {
        onSelected(destination);
      }
    },
    onProfile: onProfile,
  );
}
