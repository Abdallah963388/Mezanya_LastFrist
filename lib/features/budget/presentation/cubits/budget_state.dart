import '../../domain/entities/budget_setup_entity.dart';

class BudgetState {
  BudgetState({
    BudgetSetupEntity? budgetSetup,
    this.isLoading = false,
  }) : budgetSetup =
            budgetSetup ?? BudgetSetupEntity.initial('wallet-cash-default');

  final BudgetSetupEntity budgetSetup;
  final bool isLoading;

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
    BudgetSetupEntity? budgetSetup,
    bool? isLoading,
  }) {
    return BudgetState(
      budgetSetup: budgetSetup ?? this.budgetSetup,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
