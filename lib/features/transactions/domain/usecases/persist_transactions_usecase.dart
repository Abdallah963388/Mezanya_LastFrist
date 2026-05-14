import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class PersistTransactionsUseCase {
  PersistTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  Future<void> call(List<TransactionEntity> transactions) =>
      _repository.saveTransactions(transactions);
}
