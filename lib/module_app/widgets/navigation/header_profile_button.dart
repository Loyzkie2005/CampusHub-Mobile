import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home/home_preview_cards.dart';
import '../profile/profile_widgets.dart';

/// Reuses the signed-in identity without inventing a profile image URL.
class HeaderProfileButton extends StatelessWidget {
  const HeaderProfileButton({
    super.key,
    this.user,
    required this.onPressed,
    this.avatarKey,
    this.nameKey,
    this.greeting,
    this.actionLabel,
    this.outlinedAvatar = false,
    this.onDarkSurface = false,
  });

  final AuthUser? user;
  final VoidCallback onPressed;
  final Key? avatarKey, nameKey;

  /// Optional caption above the name; other profile shortcuts keep their layout.
  final String? greeting;

  /// Overrides the profile action's tooltip and spoken purpose for drawer use.
  final String? actionLabel;
  final bool outlinedAvatar;
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName.trim() ?? '';
    final parts = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    final name = fullName.isNotEmpty ? fullName : parts;
    final photo = user?.resolvedProfilePhotoUrl ?? '';
    final action = actionLabel ?? 'View profile';
    final label = name.isEmpty ? action : '$action: $name';
    final nameText = Text(
      name.isEmpty ? 'Profile' : name,
      key: nameKey,
      maxLines: greeting == null ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: ProfileStyle.identityText(
        14,
        weight: 600,
        color: onDarkSurface ? Colors.white : HomeAppColors.navy,
      ),
    );
    return Tooltip(
      message: actionLabel ?? label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    _ProfileAvatarOutline(
                      enabled: outlinedAvatar,
                      child: CircleAvatar(
                        key: avatarKey,
                        radius: 18,
                        backgroundColor: HomeAppColors.navy,
                        foregroundColor: Colors.white,
                        foregroundImage: photo.isEmpty
                            ? null
                            : NetworkImage(photo),
                        onForegroundImageError: photo.isEmpty
                            ? null
                            : (_, _) {},
                        child: name.isEmpty
                            ? const Icon(Iconsax.user_copy, size: 20)
                            : Text(
                                name.characters.first.toUpperCase(),
                                style: ProfileStyle.identityText(
                                  14,
                                  weight: 600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: greeting == null
                          ? nameText
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ProfileStyle.identityText(
                                    12,
                                    color: onDarkSurface
                                        ? Colors.white
                                        : ProfileStyle.secondary,
                                  ),
                                ),
                                nameText,
                              ],
                            ),
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

class _ProfileAvatarOutline extends StatelessWidget {
  const _ProfileAvatarOutline({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DecoratedBox(
      key: const ValueKey('header-profile-outline'),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [HomeAppColors.navy, HomeAppColors.gold, HomeAppColors.navy],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(padding: const EdgeInsets.all(2), child: child),
        ),
      ),
    );
  }
}
