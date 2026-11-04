import 'package:flutter/material.dart';

import '../models/facility_item.dart';
import '../services/facility_service.dart';
import '../widgets/facilities/resource_catalog_card.dart';
import '../widgets/home/home_preview_cards.dart';
import 'facility_details_screen.dart';
import 'facilities/facility_booking_history_screen.dart';

class FacilitiesPage extends StatefulWidget {
  const FacilitiesPage({
    super.key,
    this.loadFacilities = FacilityService.fetchFacilities,
  });

  final Future<FacilityServiceResult> Function() loadFacilities;

  @override
  State<FacilitiesPage> createState() => _FacilitiesPageState();
}

class _FacilitiesPageState extends State<FacilitiesPage> {
  List<FacilityItem> _facilities = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
  }

  Future<void> _fetchFacilities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.loadFacilities();
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _facilities = result.facilities.map(FacilityItem.fromJson).toList();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _errorMessage = result.message ?? 'Cannot reach CampusHub server.';
      _isLoading = false;
    });
  }

  void _openFacilityDetails(FacilityItem facility) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FacilityDetailsScreen(facility: facility),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchFacilities,
      child: ListView(
        cacheExtent: 700,
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('My Bookings'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FacilityBookingHistoryScreen(),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _FacilityEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load facilities',
              message: _errorMessage!,
              actionLabel: 'Retry',
              onAction: _fetchFacilities,
            )
          else if (_facilities.isEmpty)
            _FacilityEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No facilities yet',
              message: 'Newly added facilities will appear here.',
              actionLabel: 'Refresh',
              onAction: _fetchFacilities,
            )
          else
            ResourceCardGrid(
              children: [
                for (final facility in _facilities)
                  FacilityPreviewCard(
                    facility: facility,
                    onDetails: () => _openFacilityDetails(facility),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FacilityEmptyState extends StatelessWidget {
  const _FacilityEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF7)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: ResourceCatalogCard.navy),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: ResourceCatalogCard.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: ResourceCatalogCard.navy,
              side: const BorderSide(color: Color(0xFFE5E9F1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
