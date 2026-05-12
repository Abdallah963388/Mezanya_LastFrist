import '../entities/budget_setup_entity.dart';
import '../repositories/budget_repository.dart';

class UpdateBudgetSetupUseCase {
  const UpdateBudgetSetupUseCase(this._repository);

  final BudgetRepository _repository;

  Future<BudgetSetupEntity> call(BudgetSetupEntity budgetSetup) async {
    await _repository.saveBudget(budgetSetup);
    return budgetSetup;
  }
}
