import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/settings/presentation/cubits/settings_cubit.dart';

void registerSettingsDependencies(GetIt sl) {
  if (!sl.isRegistered<SettingsCubit>()) {
    sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<AppRepository>()),
    );
  }
}
