import '../session/session_service.dart';

/// null means ownership cannot safely be decided yet. IDs retain their namespace.
bool? ownsProduct(int? mobileUserId, {String? sellerRef, int? sellerId}) {
  if (mobileUserId == null || mobileUserId <= 0) return null;
  final supplied = sellerRef?.trim() ?? '';
  final reference = supplied.isNotEmpty
      ? supplied
      : sellerId != null && sellerId > 0
      ? 'admin:$sellerId'
      : '';
  if (!RegExp(r'^(mobile|admin):[1-9]\d*$').hasMatch(reference)) return null;
  return reference == 'mobile:$mobileUserId';
}

Future<int?> authenticatedProductViewer() async {
  try {
    final user = await SessionService.loadUser();
    final token = await SessionService.loadChatToken();
    return user != null && user.id > 0 && token != null && token.isNotEmpty
        ? user.id
        : null;
  } catch (_) {
    return null;
  }
}
