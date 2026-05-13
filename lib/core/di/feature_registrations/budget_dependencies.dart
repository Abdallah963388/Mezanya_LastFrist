import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/budget/data/repositories/budget_shared_prefs_repository.dart';
import '../../../features/budget/domain/repositories/budget_repository.dart';
import '../../../features/budget/presentation/controllers/budget_controller.dart';

void registerBudgetDependencies(GetIt sl) {
  if (!sl.isRegistered<BudgetRepository>()) {
    sl.registerLazySingleton<BudgetRepository>(
      () => BudgetSharedPrefsRepository(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<BudgetController>()) {
    sl.registerLazySingleton<BudgetController>(
      () => BudgetController(sl<BudgetRepository>()),
    );
  }
}
