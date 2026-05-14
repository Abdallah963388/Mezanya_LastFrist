import 'package:get_it/get_it.dart';

import '../../../features/budget/domain/usecases/load_budget_setup_usecase.dart';
import '../../../features/spaces/presentation/cubits/spaces_cubit.dart';

void registerSpacesDependencies(GetIt sl) {
  if (!sl.isRegistered<SpacesCubit>()) {
    sl.registerFactory<SpacesCubit>(
      () => SpacesCubit(sl<LoadBudgetSetupUseCase>()),
    );
  }
}
