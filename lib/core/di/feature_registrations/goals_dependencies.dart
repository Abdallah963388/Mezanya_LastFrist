import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/goals/presentation/cubits/goals_cubit.dart';

void registerGoalsDependencies(GetIt sl) {
  if (!sl.isRegistered<GoalsCubit>()) {
    sl.registerFactory<GoalsCubit>(
      () => GoalsCubit(sl<AppRepository>()),
    );
  }
}
