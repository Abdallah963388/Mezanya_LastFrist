import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../domain/entities/goal_entity.dart';

class GoalsState {
  const GoalsState({
    this.goals = const [],
    this.budgetSetup,
    this.hasSyncedOnce = false,
    this.isLoading = true,
  });

  final List<GoalEntity> goals;
  final BudgetSetupEntity? budgetSetup;
  final bool hasSyncedOnce;
  final bool isLoading;

  BudgetSetupEntity get effectiveBudget =>
      budgetSetup ?? BudgetSetupEntity.initial('wallet-cash-default');

  bool get hasGoals => goals.isNotEmpty;

  int get goalCount => goals.length;

  double get totalTargetAmount =>
      goals.fold(0, (sum, goal) => sum + goal.targetAmount);

  GoalsState copyWith({
    List<GoalEntity>? goals,
    BudgetSetupEntity? budgetSetup,
    bool? hasSyncedOnce,
    bool? isLoading,
  }) {
    return GoalsState(
      goals: goals ?? this.goals,
      budgetSetup: budgetSetup ?? this.budgetSetup,
      hasSyncedOnce: hasSyncedOnce ?? this.hasSyncedOnce,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
