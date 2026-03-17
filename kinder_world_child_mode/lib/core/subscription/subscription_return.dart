class SubscriptionReturnPayload {
  const SubscriptionReturnPayload({
    required this.flow,
    required this.result,
    this.sessionId,
    this.checkoutStatus,
    this.paymentStatus,
    this.provider,
  });

  final String flow;
  final String result;
  final String? sessionId;
  final String? checkoutStatus;
  final String? paymentStatus;
  final String? provider;

  static SubscriptionReturnPayload? fromQuery(Map<String, String> params) {
    final flow = (params['flow'] ?? params['source'] ?? '').trim().toLowerCase();
    final result = (params['result'] ?? params['status'] ?? '').trim().toLowerCase();
    final sessionId = params['session_id']?.trim();
    final checkoutStatus = params['checkout_status']?.trim();
    final paymentStatus = params['payment_status']?.trim();
    final provider = params['provider']?.trim();

    final hasSignal = flow.isNotEmpty ||
        result.isNotEmpty ||
        (sessionId != null && sessionId.isNotEmpty) ||
        (checkoutStatus != null && checkoutStatus.isNotEmpty) ||
        (paymentStatus != null && paymentStatus.isNotEmpty);
    if (!hasSignal) return null;

    final resolvedFlow = flow.isNotEmpty
        ? flow
        : (sessionId != null && sessionId.isNotEmpty ? 'checkout' : 'portal');
    final resolvedResult = _normalizeResult(result);
    return SubscriptionReturnPayload(
      flow: resolvedFlow,
      result: resolvedResult,
      sessionId: sessionId?.isEmpty ?? true ? null : sessionId,
      checkoutStatus:
          checkoutStatus?.isEmpty ?? true ? null : checkoutStatus?.toLowerCase(),
      paymentStatus:
          paymentStatus?.isEmpty ?? true ? null : paymentStatus?.toLowerCase(),
      provider: provider?.isEmpty ?? true ? null : provider?.toLowerCase(),
    );
  }

  static String _normalizeResult(String raw) {
    switch (raw) {
      case 'success':
      case 'succeeded':
      case 'paid':
        return 'success';
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return 'canceled';
      case 'failed':
      case 'failure':
        return 'failed';
      case 'pending':
      case 'processing':
      case 'open':
        return 'pending';
      default:
        return raw.isEmpty ? 'pending' : raw;
    }
  }

  String get cacheKey =>
      '${flow}_${result}_${sessionId ?? ''}_${checkoutStatus ?? ''}_${paymentStatus ?? ''}';
}
