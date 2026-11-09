import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Illustrative food fallback only; never presented as a seller-uploaded photo.
IconData demoFoodIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('coffee') || value.contains('tea')) {
    return Icons.local_cafe_outlined;
  }
  if (value.contains('drink') || value.contains('juice')) {
    return Icons.local_drink_outlined;
  }
  if (value.contains('noodle') || value.contains('pancit')) {
    return Icons.ramen_dining_outlined;
  }
  if (value.contains('egg')) return Icons.egg_outlined;
  if (value.contains('bread') || value.contains('cookie')) {
    return Icons.bakery_dining_outlined;
  }
  if (value.contains('burger')) return Icons.fastfood_outlined;
  return Icons.restaurant_outlined;
}

const _directory = 'assets/demo/synthetic';

/// Explicit CSV seller/product identities; these are never PostgreSQL IDs.
const syntheticDemoImageAssets = <String, String>{
  'S01:P01': '$_directory/noodles.png',
  'S01:P02': '$_directory/egg.png',
  'S01:P03': '$_directory/dumpling.png',
  'S01:P04': '$_directory/jelly-drink.png',
  'S01:P05': '$_directory/burger.png',
  'S01:P06': '$_directory/lemon.png',
  'S02:P01': '$_directory/noodles.png',
  'S02:P02': '$_directory/egg.png',
  'S02:P03': '$_directory/dumpling.png',
  'S02:P04': '$_directory/jelly-drink.png',
  'S02:P05': '$_directory/burger.png',
  'S02:P06': '$_directory/lemon.png',
  'S03:P01': '$_directory/noodles.png',
  'S03:P02': '$_directory/egg.png',
  'S03:P03': '$_directory/dumpling.png',
  'S03:P04': '$_directory/jelly-drink.png',
  'S03:P05': '$_directory/burger.png',
  'S03:P06': '$_directory/lemon.png',
  'S04:P01': '$_directory/noodles.png',
  'S04:P02': '$_directory/egg.png',
  'S04:P03': '$_directory/dumpling.png',
  'S04:P04': '$_directory/jelly-drink.png',
  'S04:P05': '$_directory/burger.png',
  'S04:P06': '$_directory/lemon.png',
  'S05:P01': '$_directory/noodles.png',
  'S05:P02': '$_directory/egg.png',
  'S05:P03': '$_directory/dumpling.png',
  'S05:P04': '$_directory/jelly-drink.png',
  'S05:P05': '$_directory/burger.png',
  'S05:P06': '$_directory/lemon.png',
};

bool _licenseRegistered = false;

String? syntheticDemoImage(Map row, Map product) {
  if (row['source'] != 'synthetic') return null;
  final asset = syntheticDemoImageAssets[product['source_id'] ?? product['id']];
  if (asset != null && !_licenseRegistered) {
    _licenseRegistered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        ['OpenMoji synthetic demo illustrations'],
        'Artwork by OpenMoji contributors, https://openmoji.org. '
        'Bundled unchanged from version 17.0.0. Illustrative demo artwork.\n\n'
        '${await rootBundle.loadString('$_directory/LICENSE.txt')}',
      );
    });
  }
  return asset;
}
