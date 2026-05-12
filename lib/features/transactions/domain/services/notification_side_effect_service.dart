class NotificationSideEffectResult {
  const NotificationSideEffectResult({
    required this.shouldNotify,
    required this.title,
    required this.message,
  });

  final bool shouldNotify;
  final String title;
  final String message;
}

class NotificationSideEffectService {
  const NotificationSideEffectService._();

  static NotificationSideEffectResult recurringTransactionExecuted({
    required String transactionName,
    required double amount,
  }) {
    return NotificationSideEffectResult(
      shouldNotify: true,
      title: 'Recurring Transaction Executed',
      message:
          'Recurring transaction "$transactionName" executed with amount $amount',
    );
  }

  static NotificationSideEffectResult lowWalletBalance({
    required String walletName,
    required double balance,
  }) {
    final shouldNotify = balance <= 100;

    return NotificationSideEffectResult(
      shouldNotify: shouldNotify,
      title: 'Low Wallet Balance',
      message: shouldNotify
          ? 'Wallet "$walletName" balance is low: $balance'
          : 'Wallet balance is healthy',
    );
  }
}
