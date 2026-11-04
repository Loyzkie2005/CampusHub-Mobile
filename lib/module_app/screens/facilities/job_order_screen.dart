import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/api_config.dart';
import '../../services/facility_booking_service.dart';

bool jobOrderNavigationAllowed(String target, Uri base, String prefix) {
  final destination = Uri.tryParse(target);
  if (destination != null &&
      destination.hasAuthority &&
      ['http', 'https'].contains(destination.scheme) &&
      destination.origin == base.origin &&
      destination.normalizePath().path.startsWith(prefix)) {
    return true;
  }
  return target.startsWith('blob:${base.origin}/');
}

/// The server exchanges a single-use header for a cookie scoped to this Job Order.
/// Mobile bearer tokens never enter the WebView, JavaScript, or a URL.
class JobOrderScreen extends StatefulWidget {
  const JobOrderScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<JobOrderScreen> createState() => _JobOrderScreenState();
}

class _JobOrderScreenState extends State<JobOrderScreen> {
  WebViewController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      setState(() {
        _loading = false;
        _error = 'Open Job Order signing in the Android or iOS app.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await const FacilityBookingService().request(
        'bookings/${Uri.encodeComponent(widget.bookingId)}/job-order/handoff/',
        body: {},
      );
      final base = Uri.parse(ApiConfig.effectiveBaseUrl);
      final uri = base.resolve(result['url'] as String);
      final expectedPath =
          '/api/mobile/bookings/${Uri.encodeComponent(widget.bookingId)}/job-order/';
      if (uri.origin != base.origin || !uri.path.startsWith(expectedPath)) {
        throw const BookingException('Unable to open this Job Order.');
      }
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              return jobOrderNavigationAllowed(request.url, base, expectedPath)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() {
                  _loading = false;
                  _error =
                      'Unable to open Job Order. Check your connection and retry.';
                });
              }
            },
            onHttpError: (error) {
              if (error.request?.uri.path == uri.path && mounted) {
                setState(() {
                  _loading = false;
                  _error =
                      'Your Job Order session may have expired. Please retry.';
                });
              }
            },
          ),
        );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(
        uri,
        headers: {'X-Job-Order-Handoff': result['handoff'] as String},
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is BookingException
              ? error.message
              : 'Unable to open Job Order. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job Order Request')),
    body: _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _open, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : Stack(
            children: [
              if (_controller != null) WebViewWidget(controller: _controller!),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
  );
}
