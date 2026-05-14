import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/ports/budget_workspace_gateway.dart';
import '../../domain/usecases/calculate_budget_cycle_usecase.dart';
import '../../domain/usecases/load_budget_dashboard_usecase.dart';
import 'budget_state.dart';

class BudgetCubit extends Cubit<BudgetState> {
  BudgetCubit({
    required BudgetWorkspaceGateway workspaceGateway,
    required AppCubit appCubitBridge,
    required LoadBudgetDashboardUseCase loadBudgetDashboardUseCase,
    CalculateBudgetCycleUseCase calculateBudgetCycleUseCase =
        const CalculateBudgetCycleUseCase(),
  })  : _workspaceGateway = workspaceGateway,
        _appCubitBridge = appCubitBridge,
        _loadBudgetDashboardUseCase = loadBudgetDashboardUseCase,
        _calculateBudgetCycleUseCase = calculateBudgetCycleUseCase,
        super(BudgetState());

  final BudgetWorkspaceGateway _workspaceGateway;
  final AppCubit _appCubitBridge;
  final LoadBudgetDashboardUseCase _loadBudgetDashboardUseCase;
  final CalculateBudgetCycleUseCase _calculateBudgetCycleUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final workspace = await _workspaceGateway.loadWorkspace();
    final anchor = workspace.budgetSetup.cycleStartFor(DateTime.now());
    _emitWorkspace(workspace, preserveCycleAnchor: false, cycleStart: anchor);
    emit(state.copyWith(isLoading: false));
  }

  Future<void> refresh() async {
    final workspace = await _workspaceGateway.loadWorkspace();
    _emitWorkspace(workspace, preserveCycleAnchor: true);
  }

  Future<void> _afterAppMutation() async {
    await refresh();
  }

  void goToPreviousCycle() {
    final periodBudget = _loadBudgetDashboardUseCase.periodBudget(
      workspace: state.workspace,
      selectedCycleStart: state.selectedCycleStart,
    );
    final current = _calculateBudgetCycleUseCase.call(
      budget: periodBudget,
      cycleAnchor: state.selectedCycleStart,
    );
    final next = _calculateBudgetCycleUseCase.shiftByMonths(
      budget: periodBudget,
      current: current,
      monthDelta: -1,
    );
    _emitWorkspace(
      state.workspace,
      preserveCycleAnchor: false,
      cycleStart: next.cycleStart,
    );
  }

  void goToNextCycle() {
    final periodBudget = _loadBudgetDashboardUseCase.periodBudget(
      workspace: state.workspace,
      selectedCycleStart: state.selectedCycleStart,
    );
    final current = _calculateBudgetCycleUseCase.call(
      budget: periodBudget,
      cycleAnchor: state.selectedCycleStart,
    );
    final next = _calculateBudgetCycleUseCase.shiftByMonths(
      budget: periodBudget,
      current: current,
      monthDelta: 1,
    );
    _emitWorkspace(
      state.workspace,
      preserveCycleAnchor: false,
      cycleStart: next.cycleStart,
    );
  }

  void _emitWorkspace(
    AppStateEntity workspace, {
    required bool preserveCycleAnchor,
    DateTime? cycleStart,
  }) {
    final anchor = preserveCycleAnchor
        ? state.selectedCycleStart
        : (cycleStart ?? state.selectedCycleStart);
    final dashboard = _loadBudgetDashboardUseCase.call(
      workspace: workspace,
      selectedCycleStart: anchor,
    );
    emit(
      state.copyWith(
        workspace: workspace,
        selectedCycleStart: anchor,
        dashboard: dashboard,
      ),
    );
  }

  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
  }) async {
    await _appCubitBridge.updateBudgetSetup(setup, detailsOverride: detailsOverride);
    await _afterAppMutation();
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    await _appCubitBridge.updateAllocationCategories(
      allocationId: allocationId,
      categories: categories,
    );
    await _afterAppMutation();
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    await _appCubitBridge.updateLinkedWalletCategories(
      linkedWalletId: linkedWalletId,
      categories: categories,
    );
    await _afterAppMutation();
  }

  Future<void> confirmAllocationDistribution(String allocationId) async {
    await _appCubitBridge.confirmAllocationDistribution(allocationId);
    await _afterAppMutation();
  }

  Future<void> postponeAllocationDistribution(String allocationId) async {
    await _appCubitBridge.postponeAllocationDistribution(allocationId);
    await _afterAppMutation();
  }

  Future<void> confirmJarDistribution(String jarId) async {
    await _appCubitBridge.confirmJarDistribution(jarId);
    await _afterAppMutation();
  }

  Future<void> postponeJarDistribution(String jarId) async {
    await _appCubitBridge.postponeJarDistribution(jarId);
    await _afterAppMutation();
  }

  Future<void> addLentRecord({
    required String personName,
    required double amount,
    required String walletId,
    required DateTime expectedReturnDate,
    DateTime? lentDate,
    bool isMonthlyInstallments = false,
    String? existingPersonId,
    String? notes,
  }) async {
    await _appCubitBridge.addLentRecord(
      personName: personName,
      amount: amount,
      walletId: walletId,
      expectedReturnDate: expectedReturnDate,
      lentDate: lentDate,
      isMonthlyInstallments: isMonthlyInstallments,
      existingPersonId: existingPersonId,
      notes: notes,
    );
    await _afterAppMutation();
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _appCubitBridge.deleteRecurringTransaction(id);
    await _afterAppMutation();
  }

  Future<void> addRecurringTransaction({
    String? id,
    required String name,
    required String type,
    required double amount,
    required int dayOfMonth,
    required String executionType,
    required String walletId,
    required String budgetScope,
    required String recurrencePattern,
    required String icon,
    required String iconColor,
    int? weekday,
    List<int>? weekdays,
    int? monthOfYear,
    String? anchorDate,
    String? scheduledTime,
    int? reminderLeadDays,
    String? allocationId,
    String? targetJarId,
    String? incomeSourceId,
    List<String>? categoryIds,
    bool isVariableIncome = false,
    bool isDebtOrSubscription = false,
    String? expensePlanKind,
    double? debtPrincipalTotal,
    int? installmentCount,
    double? installmentDownPayment,
    String? notes,
  }) async {
    await _appCubitBridge.addRecurringTransaction(
      id: id,
      name: name,
      type: type,
      amount: amount,
      dayOfMonth: dayOfMonth,
      executionType: executionType,
      walletId: walletId,
      budgetScope: budgetScope,
      recurrencePattern: recurrencePattern,
      icon: icon,
      iconColor: iconColor,
      weekday: weekday,
      weekdays: weekdays,
      monthOfYear: monthOfYear,
      anchorDate: anchorDate,
      scheduledTime: scheduledTime,
      reminderLeadDays: reminderLeadDays,
      allocationId: allocationId,
      targetJarId: targetJarId,
      incomeSourceId: incomeSourceId,
      categoryIds: categoryIds,
      isVariableIncome: isVariableIncome,
      isDebtOrSubscription: isDebtOrSubscription,
      expensePlanKind: expensePlanKind,
      debtPrincipalTotal: debtPrincipalTotal,
      installmentCount: installmentCount,
      installmentDownPayment: installmentDownPayment,
      notes: notes,
    );
    await _afterAppMutation();
  }

  Future<void> updateRecurringTransaction(
    RecurringTransactionEntity recurring, {
    String? detailsOverride,
  }) async {
    await _appCubitBridge.updateRecurringTransaction(
      recurring,
      detailsOverride: detailsOverride,
    );
    await _afterAppMutation();
  }

  Future<void> addTransaction({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? toAllocationId,
    String? budgetScope,
    String? incomeSourceId,
    String? categoryId,
    String? transferType,
    String? notes,
    DateTime? createdAt,
    String? details,
  }) async {
    await _appCubitBridge.addTransaction(
      walletId: walletId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      type: type,
      allocationId: allocationId,
      toAllocationId: toAllocationId,
      budgetScope: budgetScope,
      incomeSourceId: incomeSourceId,
      categoryId: categoryId,
      transferType: transferType,
      notes: notes,
      createdAt: createdAt,
      details: details,
    );
    await _afterAppMutation();
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await _appCubitBridge.addLinkedWallet(linkedWallet);
    await _afterAppMutation();
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await _appCubitBridge.updateLinkedWallet(linkedWallet);
    await _afterAppMutation();
  }

  Future<void> deleteLinkedWallet(String id) async {
    await _appCubitBridge.deleteLinkedWallet(id);
    await _afterAppMutation();
  }
}
