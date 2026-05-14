import '../entities/budget_setup_entity.dart';
import '../repositories/budget_repository.dart';

class LoadBudgetSetupUseCase {
  LoadBudgetSetupUseCase(this._repository);

  final BudgetRepository _repository;

  Future<BudgetSetupEntity> call() => _repository.loadBudget();
}
