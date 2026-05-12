import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../entities/transaction_entity.dart';
import 'delete_transaction_usecase.dart';
import 'update_transaction_usecase.dart';

class ProcessTransactionStateTransitionResult {
  const ProcessTransactionStateTransitionResult({
    required this.transactions,
  });

  final List<TransactionEntity> transactions;
}

class ProcessTransactionStateTransitionUseCase {
  const ProcessTransactionStateTransitionUseCase({
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
  });

  final UpdateTransactionUseCase updateTransactionUseCase;
  final DeleteTransactionUseCase deleteTransactionUseCase;

  Result<ProcessTransactionStateTransitionResult> processUpdate({
    required List<TransactionEntity> transactions,
    required TransactionEntity updatedTransaction,
  }) {
    final result = updateTransactionUseCase.execute(
      transactions: transactions,
      updatedTransaction: updatedTransaction,
    );

    if (result.isFailure) {
      return Result.failure(
        result.failure ??
            const TransactionFailure('Transaction update transition failed'),
      );
    }

    return Result.success(
      ProcessTransactionStateTransitionResult(
        transactions: result.data!,
      ),
    );
  }

  Result<ProcessTransactionStateTransitionResult> processDelete({
    required List<TransactionEntity> transactions,
    required String transactionId,
  }) {
    final result = deleteTransactionUseCase.execute(
      transactions: transactions,
      transactionId: transactionId,
    );

    if (result.isFailure) {
      return Result.failure(
        result.failure ??
            const TransactionFailure('Transaction delete transition failed'),
      );
    }

    return Result.success(
      ProcessTransactionStateTransitionResult(
        transactions: result.data!,
      ),
    );
  }
}
