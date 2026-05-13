import '../../../../goals/domain/entities/goal_entity.dart';
import '../app_cubit.dart';

extension AppCubitGoalsExtension on AppCubit {
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String icon = 'savings',
    String iconColor = '#2f6f5e',
    String? notes,
  }) async {
    final goal = GoalEntity(
      id: generateId('goal'),
      name: name,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      icon: icon,
      iconColor: iconColor,
      notes: notes,
    );
    final next = state.copyWith(goals: [...state.goals, goal]);
    await applyAndLog(
      action: 'add',
      entityType: 'goal',
      entityId: goal.id,
      details: '??? ????? ???: $name',
      apply: () async => next,
    );
  }

  Future<void> updateGoal(GoalEntity goal) async {
    final next = state.copyWith(
      goals:
          state.goals.map((item) => item.id == goal.id ? goal : item).toList(),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'goal',
      entityId: goal.id,
      details: '?? ????? ???',
      apply: () async => next,
    );
  }

  Future<void> deleteGoal(String id) async {
    final next = state.copyWith(
        goals: state.goals.where((item) => item.id != id).toList());
    await applyAndLog(
      action: 'delete',
      entityType: 'goal',
      entityId: id,
      details: '?? ??? ???',
      apply: () async => next,
    );
  }
}
