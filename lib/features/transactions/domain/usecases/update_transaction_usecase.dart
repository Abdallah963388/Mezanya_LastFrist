import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../services/transaction_history_mutation_service.dart';

class UpdateTransactionUseCase {
  const UpdateTransactionUseCase();

  Result<List<TransactionEntity>> execute({
    required List<TransactionEntity> transactions,
    required TransactionEntity updatedTransaction,
  }) {
    final exists = transactions.any(
      (transaction) => transaction.id == updatedTransaction.id,
    );

    if (!exists) {
      return Result.failure(
        TransactionFailure('Transaction not found'),
      );
    }

    final updatedTransactions =
        TransactionHistoryMutationService.replaceTransaction(
      transactions: transactions,
      updatedTransaction: updatedTransaction,
    );

    return Result.success(updatedTransactions);
  }
}
