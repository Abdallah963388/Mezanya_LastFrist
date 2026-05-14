import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/budget_setup_entity.dart';
import '../entities/budget_tracking_dashboard_entity.dart';
import 'calculate_budget_cycle_usecase.dart';
import 'calculate_budget_money_totals_usecase.dart';
import 'load_budget_transactions_for_cycle_usecase.dart';

class SelectBudgetTrackingJarsUseCase {
  const SelectBudgetTrackingJarsUseCase();

  List<LinkedWalletEntity> call(BudgetSetupEntity budget) {
    return budget.linkedWallets.where((jar) {
      if (jar.id == 'linked-savings-default') return true;
      return jar.funding
          .any((f) => f.incomeSourceId.isNotEmpty && f.plannedAmount > 0);
    }).toList();
  }
}

class BuildBudgetTrackingDashboardUseCase {
  const BuildBudgetTrackingDashboardUseCase(
    this._calculateCycle,
    this._loadTx,
    this._moneyTotals,
    this._trackingJars,
  );

  final CalculateBudgetCycleUseCase _calculateCycle;
  final LoadBudgetTransactionsForCycleUseCase _loadTx;
  final CalculateBudgetMoneyTotalsUseCase _moneyTotals;
  final SelectBudgetTrackingJarsUseCase _trackingJars;

  BudgetTrackingDashboardEntity call({
    required BudgetSetupEntity periodBudget,
    required List<TransactionEntity> allTransactions,
    required DateTime selectedCycleStart,
  }) {
    final cycle = _calculateCycle.call(
      budget: periodBudget,
      cycleAnchor: selectedCycleStart,
    );
    final cycleTx = _loadTx.call(
      allTransactions: allTransactions,
      cycle: cycle,
    );
    final money = _moneyTotals.call(cycleTx);
    final jars = _trackingJars.call(periodBudget);
    return BudgetTrackingDashboardEntity(
      cycle: cycle,
      cycleTransactions: cycleTx,
      moneyTotals: money,
      trackingJars: jars,
    );
  }
}
