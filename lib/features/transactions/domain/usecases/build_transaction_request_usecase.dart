import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../services/transaction_submission_service.dart';

class BuildTransactionRequestParams {
  const BuildTransactionRequestParams({
    required this.walletId,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.budgetTargetId,
    required this.incomeJarId,
    required this.incomeBudgetScope,
    required this.incomeSourceId,
    required this.notes,
    required this.categoryId,
  });

  final String walletId;
  final String type;
  final double amount;
  final DateTime createdAt;
  final String budgetTargetId;
  final String incomeJarId;
  final String incomeBudgetScope;
  final String incomeSourceId;
  final String notes;
  final String? categoryId;
}

class BuildTransactionRequestUseCase {
  const BuildTransactionRequestUseCase();

  Result<TransactionSubmissionRequest> execute(
    BuildTransactionRequestParams params,
  ) {
    if (params.amount <= 0) {
      return Result.failure(
        ValidationFailure('Transaction amount must be greater than zero'),
      );
    }

    final request = TransactionSubmissionService.build(
      walletId: params.walletId,
      type: params.type,
      amount: params.amount,
      createdAt: params.createdAt,
      budgetTargetId: params.budgetTargetId,
      incomeJarId: params.incomeJarId,
      incomeBudgetScope: params.incomeBudgetScope,
      incomeSourceId: params.incomeSourceId,
      notes: params.notes,
      categoryId: params.categoryId,
    );

    return Result.success(request);
  }
}
