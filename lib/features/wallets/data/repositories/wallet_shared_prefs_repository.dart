import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/local/shared_prefs_wallet_local_data_source.dart';
import 'wallet_repository_impl.dart';

class WalletSharedPrefsRepository extends WalletRepositoryImpl {
  WalletSharedPrefsRepository(SharedPreferences prefs)
      : super(SharedPrefsWalletLocalDataSource(prefs));
}
