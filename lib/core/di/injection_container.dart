import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feature_registrations/app_dependencies.dart';
import 'feature_registrations/budget_dependencies.dart';
import 'feature_registrations/goals_dependencies.dart';
import 'feature_registrations/logs_dependencies.dart';
import 'feature_registrations/settings_dependencies.dart';
import 'feature_registrations/spaces_dependencies.dart';
import 'feature_registrations/transaction_dependencies.dart';
import 'feature_registrations/wallet_dependencies.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (!sl.isRegistered<SharedPreferences>()) {
    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(prefs);
  }

  registerWalletDependencies(sl);
  registerBudgetDependencies(sl);
  registerTransactionDependencies(sl);
  registerAppDependencies(sl);
  registerGoalsDependencies(sl);
  registerSpacesDependencies(sl);
  registerLogsDependencies(sl);
  registerSettingsDependencies(sl);
}
