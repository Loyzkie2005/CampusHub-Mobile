import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Iconsax product-add glyph matching the existing navigation icon family.
class AddProductNavigationIcon extends StatelessWidget {
  const AddProductNavigationIcon({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final themeSize = theme.size;
    final dimension =
        size ?? (themeSize != null && themeSize >= 20 ? themeSize : 26.0);

    return SizedBox.square(
      dimension: dimension,
      child: Icon(
        Iconsax.box_add_copy,
        size: dimension,
        color: theme.color ?? const Color(0xFF1A1851),
      ),
    );
  }
}
