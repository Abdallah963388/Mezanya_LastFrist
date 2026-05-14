import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/budget/data/datasources/local/budget_data_source.dart';
import '../../../features/budget/data/datasources/local/shared_prefs_budget_data_source.dart';
import '../../../features/budget/data/gateways/app_repository_budget_workspace_gateway.dart';
import '../../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../../features/budget/domain/ports/budget_workspace_gateway.dart';
import '../../../features/budget/domain/repositories/budget_repository.dart';
import '../../../features/budget/domain/usecases/build_budget_tracking_dashboard_usecase.dart';
import '../../../features/budget/domain/usecases/calculate_budget_cycle_usecase.dart';
import '../../../features/budget/domain/usecases/calculate_budget_money_totals_usecase.dart';
import '../../../features/budget/domain/usecases/load_budget_dashboard_usecase.dart';
import '../../../features/budget/domain/usecases/load_budget_setup_usecase.dart';
import '../../../features/budget/domain/usecases/load_budget_transactions_for_cycle_usecase.dart';
import '../../../features/budget/domain/usecases/resolve_budget_period_setup_usecase.dart';
import '../../../features/budget/domain/usecases/update_budget_setup_usecase.dart';
import '../../../features/budget/presentation/controllers/budget_controller.dart';

void registerBudgetDependencies(GetIt sl) {
  if (!sl.isRegistered<BudgetDataSource>()) {
    sl.registerLazySingleton<BudgetDataSource>(
      () => SharedPrefsBudgetDataSource(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<BudgetRepository>()) {
    sl.registerLazySingleton<BudgetRepository>(
      () => BudgetRepositoryImpl(sl<BudgetDataSource>()),
    );
  }

  if (!sl.isRegistered<LoadBudgetSetupUseCase>()) {
    sl.registerLazySingleton<LoadBudgetSetupUseCase>(
      () => LoadBudgetSetupUseCase(sl<BudgetRepository>()),
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
        loadBudgetSetupUseCase: sl<LoadBudgetSetupUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<BudgetWorkspaceGateway>()) {
    sl.registerLazySingleton<BudgetWorkspaceGateway>(
      () => AppRepositoryBudgetWorkspaceGateway(sl<AppRepository>()),
    );
  }

  if (!sl.isRegistered<ResolveBudgetPeriodSetupUseCase>()) {
    sl.registerLazySingleton<ResolveBudgetPeriodSetupUseCase>(
      () => const ResolveBudgetPeriodSetupUseCase(),
    );
  }

  if (!sl.isRegistered<CalculateBudgetCycleUseCase>()) {
    sl.registerLazySingleton<CalculateBudgetCycleUseCase>(
      () => const CalculateBudgetCycleUseCase(),
    );
  }

  if (!sl.isRegistered<LoadBudgetTransactionsForCycleUseCase>()) {
    sl.registerLazySingleton<LoadBudgetTransactionsForCycleUseCase>(
      () => const LoadBudgetTransactionsForCycleUseCase(),
    );
  }

  if (!sl.isRegistered<CalculateBudgetMoneyTotalsUseCase>()) {
    sl.registerLazySingleton<CalculateBudgetMoneyTotalsUseCase>(
      () => const CalculateBudgetMoneyTotalsUseCase(),
    );
  }

  if (!sl.isRegistered<SelectBudgetTrackingJarsUseCase>()) {
    sl.registerLazySingleton<SelectBudgetTrackingJarsUseCase>(
      () => const SelectBudgetTrackingJarsUseCase(),
    );
  }

  if (!sl.isRegistered<BuildBudgetTrackingDashboardUseCase>()) {
    sl.registerLazySingleton<BuildBudgetTrackingDashboardUseCase>(
      () => BuildBudgetTrackingDashboardUseCase(
        sl<CalculateBudgetCycleUseCase>(),
        sl<LoadBudgetTransactionsForCycleUseCase>(),
        sl<CalculateBudgetMoneyTotalsUseCase>(),
        sl<SelectBudgetTrackingJarsUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<LoadBudgetDashboardUseCase>()) {
    sl.registerLazySingleton<LoadBudgetDashboardUseCase>(
      () => LoadBudgetDashboardUseCase(
        sl<ResolveBudgetPeriodSetupUseCase>(),
        sl<BuildBudgetTrackingDashboardUseCase>(),
      ),
    );
  }
}
