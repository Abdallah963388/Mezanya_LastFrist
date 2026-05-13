import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/logs/presentation/cubits/logs_cubit.dart';

void registerLogsDependencies(GetIt sl) {
  if (!sl.isRegistered<LogsCubit>()) {
    sl.registerFactory<LogsCubit>(
      () => LogsCubit(sl<AppRepository>()),
    );
  }
}
