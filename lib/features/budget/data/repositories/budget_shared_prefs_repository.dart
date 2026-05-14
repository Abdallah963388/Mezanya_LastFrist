import 'package:shared_preferences/shared_preferences.dart';

import '../datasources/local/shared_prefs_budget_data_source.dart';
import 'budget_repository_impl.dart';

class BudgetSharedPrefsRepository extends BudgetRepositoryImpl {
  BudgetSharedPrefsRepository(SharedPreferences prefs)
      : super(SharedPrefsBudgetDataSource(prefs));
}
