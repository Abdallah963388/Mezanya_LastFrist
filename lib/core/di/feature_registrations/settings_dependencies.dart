import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/settings/domain/usecases/load_settings_read_model_usecase.dart';
import '../../../features/settings/presentation/cubits/settings_cubit.dart';

void registerSettingsDependencies(GetIt sl) {
  if (!sl.isRegistered<LoadSettingsReadModelUseCase>()) {
    sl.registerLazySingleton<LoadSettingsReadModelUseCase>(
      () => LoadSettingsReadModelUseCase(sl<AppRepository>()),
    );
  }

  if (!sl.isRegistered<SettingsCubit>()) {
    sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<LoadSettingsReadModelUseCase>()),
    );
  }
}
