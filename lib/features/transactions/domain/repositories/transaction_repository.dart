import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> loadTransactions();

  Future<void> saveTransactions(
    List<TransactionEntity> transactions,
  );
}
