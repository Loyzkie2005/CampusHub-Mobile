import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../screens/search_page.dart';
import '../../theme/app_typography.dart';
import '../home/home_preview_cards.dart';

/// Compact entry to the existing catalog Search page from the shared header.
class HeaderSearchButton extends StatelessWidget {
  const HeaderSearchButton({
    super.key,
    this.onPressed,
    this.asSearchBar = false,
    this.hint = 'Search anything',
    this.fontFamily = AppTypography.family,
  });

  final VoidCallback? onPressed;
  final bool asSearchBar;
  final String hint;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final action =
        onPressed ??
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
    if (asSearchBar) {
      return Tooltip(
        message: 'Search',
        child: Material(
          color: HomeAppColors.white,
          shape: const StadiumBorder(
            side: BorderSide(color: HomeAppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: action,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Iconsax.search_normal_1_copy,
                      size: 20,
                      color: HomeAppColors.navy,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontVariations: const [FontVariation('wght', 400)],
                          color: HomeAppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Search',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Iconsax.search_normal_1_copy, color: HomeAppColors.navy),
      onPressed: action,
    );
  }
}
