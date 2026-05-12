import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/financial_transaction_engine.dart';
import '../services/transaction_submission_service.dart';

class AddTransactionUseCase {
  const AddTransactionUseCase({
    required FinancialTransactionEngine engine,
  }) : _engine = engine;

  final FinancialTransactionEngine _engine;

  Future<Result<void>> call(
    TransactionSubmissionRequest request,
  ) async {
    final execution = await _engine.execute(request);

    if (!execution.success) {
      return Result.failure(
        TransactionFailure(
          execution.errorMessage ?? 'فشل تنفيذ المعاملة.',
        ),
      );
    }

    return Result.success(null);
  }
}
