import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/wallets/data/repositories/wallet_shared_prefs_repository.dart';
import '../../../features/wallets/domain/repositories/wallet_repository.dart';
import '../../../features/wallets/presentation/controllers/wallet_controller.dart';

void registerWalletDependencies(GetIt sl) {
  if (!sl.isRegistered<WalletRepository>()) {
    sl.registerLazySingleton<WalletRepository>(
      () => WalletSharedPrefsRepository(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<WalletController>()) {
    sl.registerLazySingleton<WalletController>(
      () => WalletController(sl<WalletRepository>()),
    );
  }
}
