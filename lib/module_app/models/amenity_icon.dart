import 'package:flutter/material.dart';

/// Normalize only a lookup copy. Keep the API's original label for display.
String normalizeAmenityName(String label) => label
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-/\\|,.;:()\[\]&+\u2010-\u2015]+'), ' ')
    .trim();

const _icons = <String, IconData>{
  'fan': Icons.wind_power_outlined,
  'stage': Icons.theater_comedy_outlined,
  'sound system': Icons.speaker_outlined,
  'pickleball net': Icons.sports_tennis_outlined,
  'restroom': Icons.wc_outlined,
  'parking': Icons.local_parking_outlined,
  'lighting': Icons.lightbulb_outline,
  'air conditioning': Icons.ac_unit_outlined,
  'chair': Icons.chair_outlined,
  'table': Icons.table_restaurant_outlined,
  'projector': Icons.present_to_all_outlined,
  'microphone': Icons.mic_none_outlined,
  'bed': Icons.bed_outlined,
  'bleachers': Icons.stadium_outlined,
  // Preserve other existing, specific amenities without broad substring rules.
  'wifi': Icons.wifi_outlined,
  'cabinet': Icons.inventory_2_outlined,
  'basketball court': Icons.sports_basketball_outlined,
};

const _aliases = <String, String>{
  'fans': 'fan',
  'electric fan': 'fan',
  'electric fans': 'fan',
  'platform': 'stage',
  'platforms': 'stage',
  'stages': 'stage',
  'speaker': 'sound system',
  'speakers': 'sound system',
  'audio system': 'sound system',
  'sound systems': 'sound system',
  'audio systems': 'sound system',
  'pa system': 'sound system',
  'public address system': 'sound system',
  'pickleball nets': 'pickleball net',
  'pickle ball net': 'pickleball net',
  'pickle ball nets': 'pickleball net',
  'restrooms': 'restroom',
  'toilet': 'restroom',
  'toilets': 'restroom',
  'cr': 'restroom',
  'c r': 'restroom',
  'comfort room': 'restroom',
  'comfort rooms': 'restroom',
  'parking area': 'parking',
  'parking areas': 'parking',
  'parking lot': 'parking',
  'light': 'lighting',
  'lights': 'lighting',
  'aircon': 'air conditioning',
  'air con': 'air conditioning',
  'ac': 'air conditioning',
  'a c': 'air conditioning',
  'air conditioner': 'air conditioning',
  'air conditioners': 'air conditioning',
  'air conditioned': 'air conditioning',
  'chairs': 'chair',
  'seat': 'chair',
  'seats': 'chair',
  'seating': 'chair',
  'tables': 'table',
  'projectors': 'projector',
  'mic': 'microphone',
  'mics': 'microphone',
  'microphones': 'microphone',
  'bedding': 'bed',
  'beds': 'bed',
  'bed linen': 'bed',
  'bed linens': 'bed',
  'bleacher': 'bleachers',
  'wi fi': 'wifi',
  'wireless internet': 'wifi',
  'cabinets': 'cabinet',
  'basketball': 'basketball court',
};

// Only recognized modifiers plus a complete amenity phrase may match. Anchors
// reject unrelated text such as "fan club", "chairperson" or "air quality".
final _keywordRules = <(RegExp, String)>[
  (
    RegExp(
      r'^(?:(?:ceiling|wall|standing|stand|mounted|electric|portable|industrial)\s+)+fans?$',
    ),
    'fan',
  ),
  (
    RegExp(
      r'^(?:(?:raised|portable|indoor|outdoor|covered)\s+)+(?:stage|platform)s?$',
    ),
    'stage',
  ),
  (
    RegExp(
      r'^(?:(?:portable|wireless|bluetooth|powered|indoor|outdoor)\s+)+(?:sound system|audio system|speakers?)$',
    ),
    'sound system',
  ),
  (
    RegExp(
      r'^(?:(?:portable|adjustable|indoor|outdoor)\s+)+pickle\s?ball nets?$',
    ),
    'pickleball net',
  ),
  (
    RegExp(
      r"^(?:(?:accessible|unisex|male|female|men's|women's|public)\s+)+(?:restrooms?|toilets?|comfort rooms?)$",
    ),
    'restroom',
  ),
  (
    RegExp(
      r'^(?:(?:covered|indoor|outdoor|accessible|designated|car|vehicle|motorcycle)\s+)+parking(?:\s+(?:area|lot))?$',
    ),
    'parking',
  ),
  (
    RegExp(
      r'^(?:(?:led|ceiling|indoor|outdoor|emergency|court|overhead)\s+)+(?:lights?|lighting)$',
    ),
    'lighting',
  ),
  (
    RegExp(
      r'^(?:(?:split|type|window|central|portable)\s+)+(?:air conditioning|air conditioners?|aircon|ac)$',
    ),
    'air conditioning',
  ),
  (
    RegExp(
      r'^(?:(?:plastic|wooden|folding|foldable|padded|stackable|dining|office)\s+)+chairs?$',
    ),
    'chair',
  ),
  (
    RegExp(
      r'^(?:(?:plastic|wooden|folding|foldable|dining|conference|study)\s+)+tables?$',
    ),
    'table',
  ),
  (
    RegExp(
      r'^(?:(?:lcd|led|digital|portable|ceiling|mounted)\s+)+projectors?$',
    ),
    'projector',
  ),
  (
    RegExp(
      r'^(?:(?:wireless|wired|handheld|lapel)\s+)+(?:microphones?|mics?)$',
    ),
    'microphone',
  ),
  (RegExp(r'^(?:(?:single|double|twin|queen|king|bunk)\s+)+beds?$'), 'bed'),
  (
    RegExp(
      r'^(?:(?:covered|indoor|outdoor|retractable|tiered)\s+)+bleachers?$',
    ),
    'bleachers',
  ),
];

/// Exact name -> alias -> conservative phrase rule -> neutral fallback.
/// The result depends only on the amenity label, never category or list order.
IconData iconForAmenity(String label) {
  final normalized = normalizeAmenityName(label);
  final exact = _icons[normalized];
  if (exact != null) return exact;
  final alias = _aliases[normalized];
  if (alias != null) return _icons[alias]!;
  for (final (pattern, amenity) in _keywordRules) {
    if (pattern.hasMatch(normalized)) return _icons[amenity]!;
  }
  return Icons.widgets_outlined;
}
