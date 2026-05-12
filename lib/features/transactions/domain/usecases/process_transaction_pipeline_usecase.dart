import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/financial_transaction_engine.dart';
import 'add_transaction_usecase.dart';
import 'build_transaction_request_usecase.dart';
import 'validate_transaction_usecase.dart';

class ProcessTransactionPipelineUseCase {
  const ProcessTransactionPipelineUseCase({
    required this.validateTransactionUseCase,
    required this.buildTransactionRequestUseCase,
    required this.addTransactionUseCase,
  });

  final ValidateTransactionUseCase validateTransactionUseCase;
  final BuildTransactionRequestUseCase buildTransactionRequestUseCase;
  final AddTransactionUseCase addTransactionUseCase;

  Future<Result<void>> execute({
    required ValidateTransactionParams validationParams,
    required BuildTransactionRequestParams requestParams,
  }) async {
    final validationResult =
        validateTransactionUseCase.execute(validationParams);

    if (validationResult.isFailure) {
      return Result.failure(
        validationResult.failure ??
            const ValidationFailure('Validation failed'),
      );
    }

    final requestResult =
        buildTransactionRequestUseCase.execute(requestParams);

    if (requestResult.isFailure) {
      return Result.failure(
        requestResult.failure ??
            const TransactionFailure('Failed to build transaction request'),
      );
    }

    final executionResult = await addTransactionUseCase(
      requestResult.data!,
    );

    if (executionResult.isFailure) {
      return Result.failure(
        executionResult.failure ??
            const TransactionFailure('Transaction execution failed'),
      );
    }

    return Result.success(null);
  }
}
