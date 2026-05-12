import '../entities/budget_setup_entity.dart';

abstract class BudgetRepository {
  Future<BudgetSetupEntity> loadBudget();

  Future<void> saveBudget(
    BudgetSetupEntity budget,
  );
}
