import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_state/data/repositories/shared_prefs_app_repository.dart';
import '../../features/app_state/domain/repositories/app_repository.dart';
import '../../features/app_state/presentation/controllers/app_controller.dart';
import '../../features/app_state/presentation/cubits/app_cubit.dart';
import '../../features/budget/presentation/controllers/budget_controller.dart';
import '../../features/transactions/presentation/controllers/transaction_controller.dart';
import '../../features/wallets/presentation/controllers/wallet_controller.dart';

class AppControllers {
  const AppControllers({
    required this.appController,
    required this.walletController,
    required this.transactionController,
    required this.budgetController,
  });

  final AppController appController;
  final WalletController walletController;
  final TransactionController transactionController;
  final BudgetController budgetController;
}

class AppBootstrap {
  static Future<AppCubit> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final AppRepository repository = SharedPrefsAppRepository(prefs);
    final cubit = AppCubit(repository);
    await cubit.initialize();
    return cubit;
  }

  static Future<AppControllers> initializeControllers() async {
    final prefs = await SharedPreferences.getInstance();
    final AppRepository repository = SharedPrefsAppRepository(prefs);

    final appController = AppController(repository);
    final walletController = WalletController(repository);
    final transactionController = TransactionController(repository);
    final budgetController = BudgetController(repository);

    await appController.initialize();
    await walletController.initialize();
    await transactionController.initialize();
    await budgetController.initialize();

    return AppControllers(
      appController: appController,
      walletController: walletController,
      transactionController: transactionController,
      budgetController: budgetController,
    );
  }
}
