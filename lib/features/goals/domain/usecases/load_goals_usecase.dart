import '../entities/goal_entity.dart';
import '../repositories/goals_repository.dart';

class LoadGoalsUseCase {
  LoadGoalsUseCase(this._repository);

  final GoalsRepository _repository;

  Future<List<GoalEntity>> call() => _repository.loadGoals();
}
