import '../../../app_state/domain/entities/app_state_entity.dart';
import '../entities/budget_setup_entity.dart';
import '../entities/budget_tracking_dashboard_entity.dart';
import 'build_budget_tracking_dashboard_usecase.dart';
import 'resolve_budget_period_setup_usecase.dart';

class LoadBudgetDashboardUseCase {
  LoadBudgetDashboardUseCase(
    this._resolvePeriod,
    this._buildDashboard,
  );

  final ResolveBudgetPeriodSetupUseCase _resolvePeriod;
  final BuildBudgetTrackingDashboardUseCase _buildDashboard;

  BudgetTrackingDashboardEntity call({
    required AppStateEntity workspace,
    required DateTime selectedCycleStart,
  }) {
    final periodBudget = _resolvePeriod.call(
      workspace: workspace,
      cycleStart: selectedCycleStart,
    );
    return _buildDashboard.call(
      periodBudget: periodBudget,
      allTransactions: workspace.transactions,
      selectedCycleStart: selectedCycleStart,
    );
  }

  BudgetSetupEntity periodBudget({
    required AppStateEntity workspace,
    required DateTime selectedCycleStart,
  }) {
    return _resolvePeriod.call(
      workspace: workspace,
      cycleStart: selectedCycleStart,
    );
  }
}
