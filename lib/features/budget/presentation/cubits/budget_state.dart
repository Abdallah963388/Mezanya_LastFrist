import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/entities/budget_tracking_dashboard_entity.dart';

class BudgetState {
  BudgetState({
    AppStateEntity? workspace,
    DateTime? selectedCycleStart,
    this.dashboard,
    this.isLoading = false,
    this.errorMessage,
  }) : workspace = workspace ?? AppStateEntity.initial(),
       selectedCycleStart = selectedCycleStart ??
           (workspace ?? AppStateEntity.initial())
               .budgetSetup
               .cycleStartFor(DateTime.now());

  final AppStateEntity workspace;
  final DateTime selectedCycleStart;
  final BudgetTrackingDashboardEntity? dashboard;
  final bool isLoading;
  final String? errorMessage;

  BudgetSetupEntity get budgetSetup => workspace.budgetSetup;

  List<AllocationEntity> get allocations => budgetSetup.allocations;

  List<LinkedWalletEntity> get linkedWallets => budgetSetup.linkedWallets;

  List<DebtEntity> get debts => budgetSetup.debts;

  List<IncomeSourceEntity> get incomeSources => budgetSetup.incomeSources;

  double get totalIncome => budgetSetup.totalIncome;

  double get totalAllocated => budgetSetup.totalAllocated;

  double get unallocatedAmount => budgetSetup.unallocatedAmount;

  bool get hasAllocations => allocations.isNotEmpty;

  bool get hasLinkedWallets => linkedWallets.isNotEmpty;

  bool get hasDebts => debts.isNotEmpty;

  int get allocationCount => allocations.length;

  int get linkedWalletCount => linkedWallets.length;

  int get debtCount => debts.length;

  BudgetState copyWith({
    AppStateEntity? workspace,
    DateTime? selectedCycleStart,
    BudgetTrackingDashboardEntity? dashboard,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BudgetState(
      workspace: workspace ?? this.workspace,
      selectedCycleStart: selectedCycleStart ?? this.selectedCycleStart,
      dashboard: dashboard ?? this.dashboard,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
