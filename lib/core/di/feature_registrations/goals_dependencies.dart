import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/goals/data/datasources/local/goals_local_data_source.dart';
import '../../../features/goals/data/repositories/goals_repository_impl.dart';
import '../../../features/goals/domain/repositories/goals_repository.dart';
import '../../../features/goals/domain/usecases/load_goals_usecase.dart';
void registerGoalsDependencies(GetIt sl) {
  if (!sl.isRegistered<GoalsLocalDataSource>()) {
    sl.registerLazySingleton<GoalsLocalDataSource>(
      () => AppStateGoalsLocalDataSource(sl<AppRepository>()),
    );
  }

  if (!sl.isRegistered<GoalsRepository>()) {
    sl.registerLazySingleton<GoalsRepository>(
      () => GoalsRepositoryImpl(sl<GoalsLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<LoadGoalsUseCase>()) {
    sl.registerLazySingleton<LoadGoalsUseCase>(
      () => LoadGoalsUseCase(sl<GoalsRepository>()),
    );
  }

}
