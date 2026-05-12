import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/financial_transaction_engine.dart';
import '../services/recurring_transaction_orchestrator.dart';
import '../services/transaction_submission_service.dart';

class ExecuteRecurringTransactionUseCase {
  const ExecuteRecurringTransactionUseCase(this._engine);

  final FinancialTransactionEngine _engine;

  Future<Result<FinancialTransactionResult>> execute({
    required TransactionSubmissionRequest request,
    required bool isEnabled,
    required bool isDue,
    required bool requiresConfirmation,
  }) async {
    final orchestration = RecurringTransactionOrchestrator.prepare(
      request: request,
      isEnabled: isEnabled,
      isDue: isDue,
      requiresConfirmation: requiresConfirmation,
    );

    if (!orchestration.shouldExecute) {
      return Result.failure(
        RecurringFailure(orchestration.reason ?? 'Recurring execution blocked'),
      );
    }

    final result = await _engine.execute(orchestration.request);

    if (!result.success) {
      return Result.failure(
        TransactionFailure(result.errorMessage ?? 'Transaction execution failed'),
      );
    }

    return Result.success(result);
  }
}
