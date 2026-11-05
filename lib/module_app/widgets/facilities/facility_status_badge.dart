import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';

/// Presentation of the existing Django facility status, independent of slots.
class FacilityStatusBadge extends StatelessWidget {
  const FacilityStatusBadge({
    super.key,
    required this.status,
    this.fontFamily = AppTypography.family,
  });

  final String status;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      'Open for Booking' => (const Color(0xFF166534), const Color(0xFFF0FDF4)),
      'Temporarily Unavailable' => (
        const Color(0xFF92400E),
        const Color(0xFFFFFBEB),
      ),
      'Under Maintenance' => (const Color(0xFF991B1B), const Color(0xFFFEF2F2)),
      _ => (const Color(0xFF475569), const Color(0xFFF1F5F9)),
    };
    return Semantics(
      label: 'Facility status: $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontVariations: fontFamily == 'Montserrat'
                ? const [FontVariation('wght', 600)]
                : null,
            height: 1.3,
          ).copyWith(color: foreground),
        ),
      ),
    );
  }
}
