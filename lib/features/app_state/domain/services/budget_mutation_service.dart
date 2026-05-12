import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../entities/app_state_entity.dart';

class BudgetMutationService {
  const BudgetMutationService._();

  static AppStateEntity updateBudgetSetup({
    required AppStateEntity current,
    required BudgetSetupEntity budgetSetup,
  }) {
    return current.copyWith(
      budgetSetup: replaceBudgetSetup(budgetSetup),
    );
  }

  static BudgetSetupEntity replaceBudgetSetup(BudgetSetupEntity budgetSetup) {
    return budgetSetup;
  }
}
