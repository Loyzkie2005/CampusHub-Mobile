import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/demo_bundle_store.dart';
import '../theme/app_typography.dart';
import '../theme/marketplace_colors.dart';
import '../widgets/seller/product_inventory_fields.dart';
import '../widgets/product_image.dart';
import '../widgets/profile/profile_widgets.dart';
import '../widgets/seller/synthetic_demo_images.dart';
import '../widgets/home/home_preview_cards.dart';

// DotLottie puts manifest.json first; select the animation rather than metadata.
Future<LottieComposition?> decodeBundleCheck(List<int> bytes) =>
    LottieComposition.decodeZip(
      bytes,
      filePicker: (files) => files.firstWhere(
        (file) =>
            file.name.startsWith('animations/') && file.name.endsWith('.json'),
      ),
    );

String _formattedPrice(String amount) {
  final parts = amount.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '₱$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// One route creates and manages samples without touching marketplace records.
class SellerDemoBundlePage extends StatefulWidget {
  const SellerDemoBundlePage({
    super.key,
    required this.pair,
    required this.store,
    this.saved,
  });
  final Map<String, dynamic> pair;
  final DemoBundleStore store;
  final Map<String, dynamic>? saved;
  @override
  State<SellerDemoBundlePage> createState() => _SellerDemoBundlePageState();
}

enum _Stage { form, success, view }

class _SellerDemoBundlePageState extends State<SellerDemoBundlePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text:
        widget.saved?['name'] ??
        (widget.pair['products'] as List).map((p) => p['name']).join(' + '),
  );
  late final _price = TextEditingController(text: widget.saved?['price'] ?? '');
  late List<int> _quantities = widget.saved == null
      ? [1, 1]
      : List<int>.from(widget.saved!['quantities']);
  late Map<String, dynamic>? _saved = widget.saved;
  late _Stage _stage = widget.saved == null ? _Stage.form : _Stage.view;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _back() {
    if (_busy) return;
    if (_stage == _Stage.form && _saved != null) {
      setState(() {
        _restore();
        _stage = _Stage.view;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _restore() {
    _name.text = _saved!['name'];
    _price.text = _saved!['price'];
    _quantities = List<int>.from(_saved!['quantities']);
    _error = null;
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.store.save(
        pair: widget.pair,
        name: _name.text,
        quantities: const [1, 1],
        price: _price.text.trim(),
        editing: _saved != null,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        final editing = _saved != null;
        _saved = saved;
        _restore();
        _stage = editing ? _Stage.view : _Stage.success;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to save this demo. Check the inputs and device storage, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Demo Bundle?'),
        content: const Text('This removes the saved demo from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Demo Bundle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.delete(_saved!['id']);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to delete this demo. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Match Add Product's field treatment, using its shared style/type tokens.
  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.placeholder.copyWith(
      color: ProductFormStyle.muted,
    ),
    helperStyle: AppTypography.helper.copyWith(color: ProductFormStyle.muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ProductFormStyle.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(width: 1.8, color: ProductFormStyle.navy),
    ),
    errorStyle: AppTypography.error.copyWith(color: ProductFormStyle.error),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ProductFormStyle.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ProductFormStyle.error, width: 1.8),
    ),
    errorMaxLines: 3,
  );

  Widget _label(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ProductFieldLabel(label),
      const SizedBox(height: 8),
      Semantics(label: label, child: field),
    ],
  );

  Widget _products(bool editable) => Column(
    children: [
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: ProductImage(
                  imageUrl: '${widget.pair['products'][i]['image_url'] ?? ''}',
                  fallbackAsset: syntheticDemoImage(
                    widget.pair,
                    widget.pair['products'][i],
                  ),
                  fallbackIcon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.pair['products'][i]['name']}',
                  style: ProfileStyle.text(13, weight: 500),
                ),
              ),
              Text(
                '×${editable ? 1 : _quantities[i]}',
                key: ValueKey('demo-quantity-$i'),
                style: ProfileStyle.text(14, weight: 600),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _savedSummary() => Container(
    key: const ValueKey('demo-saved-summary'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ProductFormStyle.selectedSurface,
      border: Border.all(color: ProductDetailsColors.outline),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _name.text,
                style: ProfileStyle.text(17, weight: 600),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Demo Only',
              style: ProfileStyle.text(12, color: ProfileStyle.secondary),
            ),
          ],
        ),
        const Divider(height: 24, color: ProductDetailsColors.outline),
        _products(false),
        const Divider(height: 24, color: ProductDetailsColors.outline),
        Row(
          children: [
            Expanded(
              child: Text(
                'Price',
                style: ProfileStyle.text(13, color: ProfileStyle.secondary),
              ),
            ),
            Expanded(
              child: Text(
                _formattedPrice(_price.text),
                textAlign: TextAlign.end,
                style: ProfileStyle.text(17, weight: 600),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _createdConfirmation() => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        SizedBox(
          key: const ValueKey('demo-created-check'),
          width: 144,
          height: 144,
          child: ExcludeSemantics(
            child: Lottie.asset(
              'assets/animations/check.lottie',
              decoder: decodeBundleCheck,
              repeat: false,
              animate: !MediaQuery.disableAnimationsOf(context),
              controller: MediaQuery.disableAnimationsOf(context)
                  ? const AlwaysStoppedAnimation<double>(1)
                  : null,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => DecoratedBox(
                decoration: BoxDecoration(
                  color: HomeAppColors.success,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bundle Created!',
          style: ProfileStyle.text(20, weight: 700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editing = _stage == _Stage.form;
    final title = switch (_stage) {
      _Stage.form => _saved == null ? 'Create Demo Bundle' : 'Edit Demo Bundle',
      _Stage.success => 'Demo Bundle',
      _Stage.view => 'Demo Bundle',
    };
    return ProfileTheme(
      child: PopScope(
        canPop:
            !_busy &&
            (_stage == _Stage.view ||
                _stage == _Stage.success ||
                (editing && _saved == null)),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _busy ? null : _back,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
            title: Text(title),
          ),
          bottomNavigationBar: editing || _stage == _Stage.success
              ? Padding(
                  key: const ValueKey('demo-bottom-action'),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : editing
                          ? _save
                          : () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: ProductDetailsColors.gold,
                        foregroundColor: ProductDetailsColors.navy,
                        disabledBackgroundColor: ProductDetailsColors.softNavy,
                        disabledForegroundColor: ProductDetailsColors.muted,
                        elevation: 0,
                        minimumSize: const Size(0, 52),
                        shape: const StadiumBorder(),
                        textStyle: AppTypography.text(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _busy
                            ? 'Saving…'
                            : editing
                            ? 'Save Demo Bundle'
                            : 'OK',
                      ),
                    ),
                  ),
                )
              : null,
          body: _stage == _Stage.success
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 64),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 104).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Column(
                        key: const ValueKey('demo-centered-success'),
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_createdConfirmation(), _savedSummary()],
                      ),
                    ),
                  ),
                )
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!editing) _savedSummary(),
                      if (editing)
                        _label(
                          'Bundle Name',
                          TextFormField(
                            key: const ValueKey('demo-name'),
                            controller: _name,
                            enabled: !_busy,
                            style: AppTypography.input.copyWith(
                              color: ProfileStyle.navy,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: _field(
                              'Enter bundle name',
                            ).copyWith(counterText: ''),
                            maxLength: 150,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Enter a bundle name.'
                                : null,
                          ),
                        ),
                      if (editing) ...[
                        const SizedBox(height: 12),
                        const ProductFieldLabel('Included Products'),
                        _products(true),
                        const SizedBox(height: 16),
                      ],
                      if (editing)
                        _label(
                          'Price (₱)',
                          TextFormField(
                            key: const ValueKey('demo-price'),
                            controller: _price,
                            enabled: !_busy,
                            style: AppTypography.input.copyWith(
                              color: ProfileStyle.navy,
                            ),
                            decoration: _field('Enter sample price').copyWith(
                              prefixText: '₱ ',
                              prefixStyle: AppTypography.input.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ProfileStyle.navy,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              final price = (value ?? '').trim();
                              final amount = double.tryParse(price);
                              return amount == null ||
                                      !amount.isFinite ||
                                      amount <= 0 ||
                                      !RegExp(
                                        r'^\d+(\.\d{1,2})?$',
                                      ).hasMatch(price)
                                  ? 'Enter a price greater than zero (up to 2 decimals).'
                                  : null;
                            },
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, semanticsLabel: _error),
                        ),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (!editing) const SizedBox(height: 20),
                      if (_stage == _Stage.view)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _stage = _Stage.form),
                          child: const Text('Edit'),
                        ),
                      if (_stage == _Stage.view)
                        OutlinedButton(
                          onPressed: _busy ? null : _delete,
                          child: const Text('Delete Demo Bundle'),
                        ),
                      if (_stage == _Stage.view)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Back to Suggestions'),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Keeps saved samples reachable even after a recommendation is dismissed.
class SellerDemoBundleList extends StatefulWidget {
  const SellerDemoBundleList({super.key, required this.store});
  final DemoBundleStore store;
  @override
  State<SellerDemoBundleList> createState() => _SellerDemoBundleListState();
}

class _SellerDemoBundleListState extends State<SellerDemoBundleList> {
  late Future<List<Map<String, dynamic>>> _records = widget.store.list();
  @override
  Widget build(BuildContext context) => ProfileTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Saved Demo Bundles')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.hasError) ...[
                const Text('Unable to read demos from this device.'),
                TextButton(
                  onPressed: () => setState(() {
                    _records = widget.store.list();
                  }),
                  child: const Text('Retry'),
                ),
              ] else if (snapshot.data!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No saved demo bundles yet.'),
                )
              else
                for (final record in snapshot.data!)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(record['name']),
                    subtitle: Text(
                      'Demo Only • ${_formattedPrice(record['price'])}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerDemoBundlePage(
                            pair: Map<String, dynamic>.from(
                              record['recommendation'],
                            ),
                            store: widget.store,
                            saved: record,
                          ),
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          _records = widget.store.list();
                        });
                      }
                    },
                  ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Suggestions'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
