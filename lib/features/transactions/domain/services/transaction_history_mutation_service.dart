import '../entities/transaction_entity.dart';

class TransactionHistoryMutationService {
  const TransactionHistoryMutationService._();

  static List<TransactionEntity> addTransaction({
    required List<TransactionEntity> transactions,
    required TransactionEntity transaction,
  }) {
    return [
      transaction,
      ...transactions,
    ];
  }

  static List<TransactionEntity> removeTransaction({
    required List<TransactionEntity> transactions,
    required String transactionId,
  }) {
    return transactions
        .where((transaction) => transaction.id != transactionId)
        .toList();
  }

  static List<TransactionEntity> replaceTransaction({
    required List<TransactionEntity> transactions,
    required TransactionEntity updatedTransaction,
  }) {
    return transactions.map((transaction) {
      if (transaction.id == updatedTransaction.id) {
        return updatedTransaction;
      }

      return transaction;
    }).toList();
  }
}
