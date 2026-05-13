import '../../../domain/entities/transaction_entity.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionEntity>> loadTransactions();

  Future<void> saveTransactions(List<TransactionEntity> transactions);
}
