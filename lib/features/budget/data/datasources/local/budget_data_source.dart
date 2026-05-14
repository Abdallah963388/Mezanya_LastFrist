import '../../../domain/entities/budget_setup_entity.dart';

abstract class BudgetDataSource {
  Future<BudgetSetupEntity> loadBudget();

  Future<void> saveBudget(BudgetSetupEntity budget);
}
