import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/budget/data/datasources/local/budget_local_data_source.dart';
import '../../../features/budget/data/datasources/local/shared_prefs_budget_local_data_source.dart';
import '../../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../../features/budget/domain/repositories/budget_repository.dart';
import '../../../features/budget/domain/usecases/update_budget_setup_usecase.dart';
import '../../../features/budget/presentation/controllers/budget_controller.dart';
import '../../../features/budget/presentation/cubits/budget_cubit.dart';

void registerBudgetDependencies(GetIt sl) {
  if (!sl.isRegistered<BudgetLocalDataSource>()) {
    sl.registerLazySingleton<BudgetLocalDataSource>(
      () => SharedPrefsBudgetLocalDataSource(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<BudgetRepository>()) {
    sl.registerLazySingleton<BudgetRepository>(
      () => BudgetRepositoryImpl(sl<BudgetLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<UpdateBudgetSetupUseCase>()) {
    sl.registerLazySingleton<UpdateBudgetSetupUseCase>(
      () => UpdateBudgetSetupUseCase(sl<BudgetRepository>()),
    );
  }

  if (!sl.isRegistered<BudgetController>()) {
    sl.registerLazySingleton<BudgetController>(
      () => BudgetController(
        sl<BudgetRepository>(),
        updateBudgetSetupUseCase: sl<UpdateBudgetSetupUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<BudgetCubit>()) {
    sl.registerFactory<BudgetCubit>(
      () => BudgetCubit(
        sl<BudgetRepository>(),
        updateBudgetSetupUseCase: sl<UpdateBudgetSetupUseCase>(),
      ),
    );
  }
}
