import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../entities/budget_setup_entity.dart';

class UpdateBudgetSetupUseCase {
  const UpdateBudgetSetupUseCase(this._repository);

  final AppRepository _repository;

  Future<AppStateEntity> call(BudgetSetupEntity budgetSetup) {
    return _repository.updateBudgetSetup(budgetSetup);
  }
}
