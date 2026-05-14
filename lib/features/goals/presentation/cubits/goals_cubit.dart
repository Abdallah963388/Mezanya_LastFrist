import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/usecases/load_budget_setup_usecase.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/usecases/load_goals_usecase.dart';
import 'goals_state.dart';

/// Goals feature orchestration. Reads goals + default savings jar context via
/// repositories; forwards writes through [AppCubit] to preserve audit/logging
/// until goal mutations are extracted to a shared apply layer.
class GoalsCubit extends Cubit<GoalsState> {
  GoalsCubit({
    required AppCubit appCubitBridge,
    required LoadGoalsUseCase loadGoalsUseCase,
    required LoadBudgetSetupUseCase loadBudgetSetupUseCase,
  })  : _appCubit = appCubitBridge,
        _loadGoalsUseCase = loadGoalsUseCase,
        _loadBudgetSetupUseCase = loadBudgetSetupUseCase,
        super(const GoalsState());

  final AppCubit _appCubit;
  final LoadGoalsUseCase _loadGoalsUseCase;
  final LoadBudgetSetupUseCase _loadBudgetSetupUseCase;

  Future<void> initialize() async {
    await refresh();
    await _appCubit.ensureDefaultSavingsJar();
    await refresh();
    emit(state.copyWith(isLoading: false, hasSyncedOnce: true));
  }

  Future<void> refresh() async {
    final goals = await _loadGoalsUseCase();
    final budget = await _loadBudgetSetupUseCase();
    emit(
      state.copyWith(
        goals: goals,
        budgetSetup: budget,
        hasSyncedOnce: true,
      ),
    );
  }

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String icon = 'savings',
    String iconColor = '#2f6f5e',
    String? notes,
  }) async {
    await _appCubit.addGoal(
      name: name,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      icon: icon,
      iconColor: iconColor,
      notes: notes,
    );
    await refresh();
  }

  Future<void> updateGoal(GoalEntity goal) async {
    await _appCubit.updateGoal(goal);
    await refresh();
  }

  Future<void> deleteGoal(String id) async {
    await _appCubit.deleteGoal(id);
    await refresh();
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
    await _appCubit.addTransaction(
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
    await refresh();
  }
}
