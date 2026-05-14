import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goals_repository.dart';
import '../datasources/local/goals_local_data_source.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl(this._localDataSource);

  final GoalsLocalDataSource _localDataSource;

  @override
  Future<List<GoalEntity>> loadGoals() {
    return _localDataSource.loadGoals();
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) {
    return _localDataSource.saveGoals(goals);
  }
}
