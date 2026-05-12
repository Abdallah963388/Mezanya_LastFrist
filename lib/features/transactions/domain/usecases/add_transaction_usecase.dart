import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../entities/transaction_entity.dart';
import '../services/financial_transaction_engine.dart';
import '../services/transaction_submission_service.dart';

class AddTransactionUseCase {
  const AddTransactionUseCase({
    required FinancialTransactionEngine engine,
  })  : _engine = engine,
        _repository = null;

  const AddTransactionUseCase.repository(
    AppRepository repository,
  )   : _repository = repository,
        _engine = null;

  final FinancialTransactionEngine? _engine;
  final AppRepository? _repository;

  Future<Result<void>> call(
    TransactionSubmissionRequest request,
  ) async {
    final execution = await _engine!.execute(request);

    if (!execution.success) {
      return Result.failure(
        TransactionFailure(
          execution.errorMessage ?? 'فشل تنفيذ المعاملة.',
        ),
      );
    }

    return Result.success(null);
  }

  Future<AppStateEntity> add(TransactionEntity transaction) {
    return _repository!.addTransaction(transaction);
  }
}
