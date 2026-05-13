import 'package:get_it/get_it.dart';

import '../../../features/app_state/domain/repositories/app_repository.dart';
import '../../../features/spaces/presentation/cubits/spaces_cubit.dart';

void registerSpacesDependencies(GetIt sl) {
  if (!sl.isRegistered<SpacesCubit>()) {
    sl.registerFactory<SpacesCubit>(
      () => SpacesCubit(sl<AppRepository>()),
    );
  }
}
