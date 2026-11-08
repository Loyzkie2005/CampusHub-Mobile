import 'package:flutter/material.dart';
import '../models/service_item.dart';
import '../routes/app_routes.dart';
import '../services/service_catalog.dart';
import '../widgets/facilities/booking_widgets.dart';
import 'service_details_screen.dart';
import '../widgets/facilities/resource_catalog_card.dart';
import '../widgets/home/home_preview_cards.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key, this.catalog = const ServiceCatalog()});
  final ServiceCatalog catalog;
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  List<ServiceItem> _services = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.catalog.fetchServices();
      if (mounted) setState(() => _services = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to load services. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: bookingNavy,
      child: ListView(
        key: const PageStorageKey('mobile-services-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const Text(
            'Services',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: bookingNavy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Available Services',
            style: TextStyle(fontWeight: FontWeight.w700, color: bookingNavy),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: bookingNavy),
              ),
            )
          else if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: bookingNavy)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ] else if (_services.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No services are currently available.',
                style: TextStyle(color: bookingMuted),
              ),
            )
          else
            ResourceCardGrid(
              children: [
                for (final row in _services)
                  ServicePreviewCard(
                    service: row,
                    catalog: widget.catalog,
                    onDetails: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        settings: RouteSettings(
                          name: AppRoutes.serviceDetails,
                          arguments: row.id,
                        ),
                        builder: (_) => ServiceDetailsScreen(
                          service: row,
                          catalog: widget.catalog,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
