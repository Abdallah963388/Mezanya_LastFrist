import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/wallets/data/datasources/local/shared_prefs_wallet_local_data_source.dart';
import '../../../features/wallets/data/datasources/local/wallet_local_data_source.dart';
import '../../../features/wallets/data/repositories/wallet_repository_impl.dart';
import '../../../features/wallets/domain/repositories/wallet_repository.dart';
import '../../../features/wallets/domain/usecases/load_wallets_usecase.dart';
import '../../../features/wallets/domain/usecases/persist_wallets_usecase.dart';
import '../../../features/wallets/presentation/controllers/wallet_controller.dart';
import '../../../features/wallets/presentation/cubits/wallet_cubit.dart';

void registerWalletDependencies(GetIt sl) {
  if (!sl.isRegistered<WalletLocalDataSource>()) {
    sl.registerLazySingleton<WalletLocalDataSource>(
      () => SharedPrefsWalletLocalDataSource(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<WalletRepository>()) {
    sl.registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(sl<WalletLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<LoadWalletsUseCase>()) {
    sl.registerLazySingleton<LoadWalletsUseCase>(
      () => LoadWalletsUseCase(sl<WalletRepository>()),
    );
  }

  if (!sl.isRegistered<PersistWalletsUseCase>()) {
    sl.registerLazySingleton<PersistWalletsUseCase>(
      () => PersistWalletsUseCase(sl<WalletRepository>()),
    );
  }

  if (!sl.isRegistered<WalletController>()) {
    sl.registerLazySingleton<WalletController>(
      () => WalletController(
        sl<WalletRepository>(),
        loadWalletsUseCase: sl<LoadWalletsUseCase>(),
        persistWalletsUseCase: sl<PersistWalletsUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<WalletCubit>()) {
    sl.registerFactory<WalletCubit>(
      () => WalletCubit(
        sl<LoadWalletsUseCase>(),
        sl<PersistWalletsUseCase>(),
      ),
    );
  }
}
