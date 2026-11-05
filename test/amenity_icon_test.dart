import 'package:campushub/module_app/models/amenity_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final groups = <IconData, List<String>>{
    Icons.wind_power_outlined: ['Fan', 'Fans', 'Electric Fan', 'Electric Fans'],
    Icons.theater_comedy_outlined: ['Stage', 'Stages', 'Platform', 'Platforms'],
    Icons.speaker_outlined: [
      'Sound System',
      'Speaker',
      'Speakers',
      'Audio System',
      'PA System',
    ],
    Icons.sports_tennis_outlined: [
      'Pickleball Net',
      'Pickleball Nets',
      'Pickle Ball Net',
    ],
    Icons.wc_outlined: [
      'Restroom',
      'Restrooms',
      'Toilet',
      'Toilets',
      'CR',
      'C.R.',
      'Comfort Room',
    ],
    Icons.local_parking_outlined: ['Parking', 'Parking Area', 'Parking Lot'],
    Icons.lightbulb_outline: ['Lighting', 'Light', 'Lights'],
    Icons.ac_unit_outlined: [
      'Aircon',
      'AC',
      'A.C.',
      'Air Conditioning',
      'Air Conditioners',
      'Air-conditioned',
    ],
    Icons.chair_outlined: ['Chair', 'Chairs', 'Seating'],
    Icons.table_restaurant_outlined: ['Table', 'Tables'],
    Icons.present_to_all_outlined: ['Projector', 'Projectors'],
    Icons.mic_none_outlined: ['Microphone', 'Microphones', 'Mic', 'Mics'],
    Icons.bed_outlined: ['Bedding', 'Bed', 'Beds'],
    Icons.stadium_outlined: ['Bleachers', 'Bleacher'],
  };
  for (final entry in groups.entries) {
    test(
      'canonical and aliases for ${entry.value.first} identify the same icon',
      () {
        for (final label in entry.value) {
          expect(iconForAmenity(label), entry.key, reason: label);
          expect(
            iconForAmenity('  ${label.toUpperCase()}  '),
            entry.key,
            reason: label,
          );
        }
      },
    );
  }

  test('normalization standardizes common separators on a lookup copy', () {
    for (final label in [
      'Sound_System',
      'sound-system',
      'sound/system',
      'sound | system',
      'Sound—System',
      'sound\t system',
    ]) {
      expect(normalizeAmenityName(label), 'sound system');
      expect(iconForAmenity(label), Icons.speaker_outlined);
    }
    expect(iconForAmenity('Wi-Fi'), Icons.wifi_outlined);
    expect(iconForAmenity('A/C'), Icons.ac_unit_outlined);
    expect(iconForAmenity('C/R'), Icons.wc_outlined);
  });

  test('limited descriptive phrases match complete amenity words', () {
    const phrases = {
      'Ceiling-mounted electric fans': Icons.wind_power_outlined,
      'Raised outdoor stage': Icons.theater_comedy_outlined,
      'Portable sound system': Icons.speaker_outlined,
      'Adjustable pickleball net': Icons.sports_tennis_outlined,
      'Accessible restroom': Icons.wc_outlined,
      'Covered parking area': Icons.local_parking_outlined,
      'LED ceiling lights': Icons.lightbulb_outline,
      'Split-type air conditioning': Icons.ac_unit_outlined,
      'Padded folding chairs': Icons.chair_outlined,
      'Wooden dining tables': Icons.table_restaurant_outlined,
      'Ceiling-mounted projector': Icons.present_to_all_outlined,
      'Wireless mic': Icons.mic_none_outlined,
      'Queen beds': Icons.bed_outlined,
      'Retractable bleachers': Icons.stadium_outlined,
    };
    for (final entry in phrases.entries) {
      expect(iconForAmenity(entry.key), entry.value, reason: entry.key);
    }
  });

  test('unknown, negated, ambiguous and unrelated text stays generic', () {
    for (final label in [
      '',
      '   ',
      'Custom amenity',
      'Chairperson office',
      'Wheelchair ramp',
      'Air quality monitor',
      'Park view',
      'Parking policy',
      'No parking',
      'Without AC',
      'Fan club',
      'Stagecraft tools',
      'Soundproof wall',
      'Audio editing workstation',
      'Light refreshments',
      'Projector cable',
      'Microphone policy',
      'Bedroom key',
      'Table tennis',
      'Fans and chairs',
      'Snack table service',
      'Parking unavailable',
      'Repainting materials',
    ]) {
      expect(iconForAmenity(label), Icons.widgets_outlined, reason: label);
    }
  });

  test('specific existing non-table amenities remain supported', () {
    expect(iconForAmenity('Wi-Fi'), Icons.wifi_outlined);
    expect(iconForAmenity('Cabinets'), Icons.inventory_2_outlined);
    expect(
      iconForAmenity('Basketball Court'),
      Icons.sports_basketball_outlined,
    );
  });
}
