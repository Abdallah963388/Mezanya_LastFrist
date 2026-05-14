import '../../../../app_state/domain/repositories/app_repository.dart';
import '../../../domain/entities/goal_entity.dart';

abstract class GoalsLocalDataSource {
  Future<List<GoalEntity>> loadGoals();

  Future<void> saveGoals(List<GoalEntity> goals);
}

class AppStateGoalsLocalDataSource implements GoalsLocalDataSource {
  AppStateGoalsLocalDataSource(this._appRepository);

  final AppRepository _appRepository;

  @override
  Future<List<GoalEntity>> loadGoals() async {
    final appState = await _appRepository.loadState();
    return appState.goals;
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    final appState = await _appRepository.loadState();
    await _appRepository.saveState(appState.copyWith(goals: goals));
  }
}
