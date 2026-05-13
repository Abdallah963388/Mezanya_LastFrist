import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/app_state/data/repositories/shared_prefs_app_repository.dart';
import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/app_state/presentation/controllers/app_controller.dart';
import '../../../features/app_state/presentation/cubits/app_cubit.dart';
import '../../../features/transactions/presentation/controllers/transaction_controller.dart';

void registerAppDependencies(GetIt sl) {
  if (!sl.isRegistered<AppRepository>()) {
    sl.registerLazySingleton<AppRepository>(
      () => SharedPrefsAppRepository(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<AppController>()) {
    sl.registerLazySingleton<AppController>(
      () => AppController(sl<AppRepository>()),
    );
  }

  if (!sl.isRegistered<AppCubit>()) {
    sl.registerFactory<AppCubit>(
      () => AppCubit(
        sl<AppRepository>(),
        sl<TransactionController>(),
      ),
    );
  }
}
