import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../services/transaction_history_mutation_service.dart';

class DeleteTransactionUseCase {
  const DeleteTransactionUseCase();

  Result<List<TransactionEntity>> execute({
    required List<TransactionEntity> transactions,
    required String transactionId,
  }) {
    final exists = transactions.any(
      (transaction) => transaction.id == transactionId,
    );

    if (!exists) {
      return Result.failure(
        TransactionFailure('Transaction not found'),
      );
    }

    final updatedTransactions =
        TransactionHistoryMutationService.removeTransaction(
      transactions: transactions,
      transactionId: transactionId,
    );

    return Result.success(updatedTransactions);
  }
}
