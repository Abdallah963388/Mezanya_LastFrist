import '../entities/transaction_entity.dart';

class RecurringExpenseService {
  const RecurringExpenseService._();

  static List<TransactionEntity> appendIfDue({
    required List<TransactionEntity> transactions,
    TransactionEntity? dueTransaction,
  }) {
    if (dueTransaction == null) {
      return transactions;
    }

    return <TransactionEntity>[
      ...transactions,
      dueTransaction,
    ];
  }
}
