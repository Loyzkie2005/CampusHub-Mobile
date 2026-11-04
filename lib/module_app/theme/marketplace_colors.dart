import 'package:flutter/material.dart';

/// Shared product-card surfaces for the mobile marketplace and its previews.
abstract final class MarketplaceColors {
  static const cardSurface = Colors.white;
  static const imageSurface = cardSurface;
}

/// Product Details' navy/gold treatment, isolated from marketplace card colors.
abstract final class ProductDetailsColors {
  static const navy = Color(0xFF1A1851);
  // Explicit Product Details accent requested by the user.
  static const gold = Color(0xFFFCB316);
  static const surface = Colors.white;
  static const muted = Color(0xFF667085);
  static const outline = Color(0xFFE8EAF0);
  static const softNavy = Color(0xFFF4F4F8);
  static const headerControlSurface = Color(0xFFEEF0F3);
  static const softGold = Color(0xFFFFF7E5);
}
