import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/notification_side_effect_service.dart';

class ProcessNotificationPipelineParams {
  const ProcessNotificationPipelineParams({
    required this.transactionName,
    required this.amount,
    required this.walletName,
    required this.walletBalance,
  });

  final String transactionName;
  final double amount;
  final String walletName;
  final double walletBalance;
}

class ProcessNotificationPipelineResult {
  const ProcessNotificationPipelineResult({
    required this.recurringNotification,
    required this.lowBalanceNotification,
  });

  final NotificationSideEffectResult recurringNotification;
  final NotificationSideEffectResult lowBalanceNotification;
}

class ProcessNotificationPipelineUseCase {
  const ProcessNotificationPipelineUseCase();

  Result<ProcessNotificationPipelineResult> execute(
    ProcessNotificationPipelineParams params,
  ) {
    final recurringNotification =
        NotificationSideEffectService.recurringTransactionExecuted(
      transactionName: params.transactionName,
      amount: params.amount,
    );

    final lowBalanceNotification =
        NotificationSideEffectService.lowWalletBalance(
      walletName: params.walletName,
      balance: params.walletBalance,
    );

    if (!recurringNotification.shouldNotify &&
        !lowBalanceNotification.shouldNotify) {
      return Result.failure(
        const TransactionFailure('No notification side effects generated'),
      );
    }

    return Result.success(
      ProcessNotificationPipelineResult(
        recurringNotification: recurringNotification,
        lowBalanceNotification: lowBalanceNotification,
      ),
    );
  }
}
