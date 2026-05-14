import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/local/budget_data_source.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._localDataSource);

  final BudgetDataSource _localDataSource;

  @override
  Future<BudgetSetupEntity> loadBudget() {
    return _localDataSource.loadBudget();
  }

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) {
    return _localDataSource.saveBudget(budget);
  }
}
