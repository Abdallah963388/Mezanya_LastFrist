import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/financial_transaction_engine.dart';
import '../services/notification_side_effect_service.dart';
import '../services/transaction_submission_service.dart';
import 'execute_recurring_transaction_usecase.dart';

class ProcessRecurringPipelineResult {
  const ProcessRecurringPipelineResult({
    required this.executionResult,
    required this.notificationResult,
  });

  final FinancialTransactionResult executionResult;
  final NotificationSideEffectResult notificationResult;
}

class ProcessRecurringPipelineUseCase {
  const ProcessRecurringPipelineUseCase({
    required this.executeRecurringTransactionUseCase,
  });

  final ExecuteRecurringTransactionUseCase
      executeRecurringTransactionUseCase;

  Future<Result<ProcessRecurringPipelineResult>> execute({
    required TransactionSubmissionRequest request,
    required bool isEnabled,
    required bool isDue,
    required bool requiresConfirmation,
    required String transactionName,
    required double amount,
  }) async {
    final recurringResult =
        await executeRecurringTransactionUseCase.execute(
      request: request,
      isEnabled: isEnabled,
      isDue: isDue,
      requiresConfirmation: requiresConfirmation,
    );

    if (recurringResult.isFailure) {
      return Result.failure(
        recurringResult.failure ??
            const RecurringFailure('Recurring pipeline failed'),
      );
    }

    final notificationResult =
        NotificationSideEffectService.recurringTransactionExecuted(
      transactionName: transactionName,
      amount: amount,
    );

    return Result.success(
      ProcessRecurringPipelineResult(
        executionResult: recurringResult.data!,
        notificationResult: notificationResult,
      ),
    );
  }
}
