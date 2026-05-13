import '../../domain/entities/goal_entity.dart';

class GoalsState {
  const GoalsState({
    this.goals = const [],
    this.isLoading = false,
  });

  final List<GoalEntity> goals;
  final bool isLoading;

  bool get hasGoals => goals.isNotEmpty;

  int get goalCount => goals.length;

  double get totalTargetAmount =>
      goals.fold(0, (sum, goal) => sum + goal.targetAmount);

  GoalsState copyWith({
    List<GoalEntity>? goals,
    bool? isLoading,
  }) {
    return GoalsState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
