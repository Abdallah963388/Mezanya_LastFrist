import '../entities/goal_entity.dart';

abstract class GoalsRepository {
  Future<List<GoalEntity>> loadGoals();

  Future<void> saveGoals(List<GoalEntity> goals);
}
