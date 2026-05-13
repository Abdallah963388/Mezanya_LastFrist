import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local/transaction_local_data_source.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._localDataSource);

  final TransactionLocalDataSource _localDataSource;

  @override
  Future<List<TransactionEntity>> loadTransactions() {
    return _localDataSource.loadTransactions();
  }

  @override
  Future<void> saveTransactions(List<TransactionEntity> transactions) {
    return _localDataSource.saveTransactions(transactions);
  }
}
