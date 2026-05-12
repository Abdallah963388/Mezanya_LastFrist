class NotificationSideEffectResult {
  const NotificationSideEffectResult({
    required this.shouldNotify,
    this.title,
    this.body,
  });

  final bool shouldNotify;
  final String? title;
  final String? body;
}

class NotificationSideEffectService {
  const NotificationSideEffectService._();

  static NotificationSideEffectResult recurringTransactionExecuted({
    required String transactionName,
    required double amount,
  }) {
    return NotificationSideEffectResult(
      shouldNotify: true,
      title: 'تم تنفيذ معاملة متكررة',
      body: '$transactionName • ${amount.toStringAsFixed(2)}',
    );
  }

  static NotificationSideEffectResult lowWalletBalance({
    required String walletName,
    required double balance,
  }) {
    if (balance > 0) {
      return const NotificationSideEffectResult(
        shouldNotify: false,
      );
    }

    return NotificationSideEffectResult(
      shouldNotify: true,
      title: 'رصيد منخفض',
      body: '$walletName وصل إلى ${balance.toStringAsFixed(2)}',
    );
  }
}
