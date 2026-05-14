import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class LoadTransactionsUseCase {
  LoadTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  Future<List<TransactionEntity>> call() => _repository.loadTransactions();
}
