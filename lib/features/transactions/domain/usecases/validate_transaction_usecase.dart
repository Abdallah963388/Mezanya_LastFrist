import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/transaction_validation_service.dart';

class ValidateTransactionParams {
  const ValidateTransactionParams({
    required this.amount,
    required this.walletId,
    required this.requiresBudgetTarget,
    required this.missingIncomeTarget,
    required this.recurringMode,
    required this.recurringName,
    required this.exceedsUnallocated,
  });

  final double amount;
  final String walletId;
  final bool requiresBudgetTarget;
  final bool missingIncomeTarget;
  final bool recurringMode;
  final String recurringName;
  final bool exceedsUnallocated;
}

class ValidateTransactionUseCase {
  const ValidateTransactionUseCase();

  Result<void> execute(ValidateTransactionParams params) {
    final validation = TransactionValidationService.validate(
      amount: params.amount,
      walletId: params.walletId,
      requiresBudgetTarget: params.requiresBudgetTarget,
      missingIncomeTarget: params.missingIncomeTarget,
      recurringMode: params.recurringMode,
      recurringName: params.recurringName,
      exceedsUnallocated: params.exceedsUnallocated,
    );

    if (!validation.isValid) {
      return Result.failure(
        ValidationFailure(validation.message ?? 'Validation failed'),
      );
    }

    return Result.success(null);
  }
}
