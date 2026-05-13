import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/local/shared_prefs_transaction_local_data_source.dart';
import 'transaction_repository_impl.dart';

class TransactionSharedPrefsRepository extends TransactionRepositoryImpl {
  TransactionSharedPrefsRepository(SharedPreferences prefs)
      : super(SharedPrefsTransactionLocalDataSource(prefs));
}
