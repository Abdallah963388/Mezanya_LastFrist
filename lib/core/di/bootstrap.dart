import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_state/data/repositories/shared_prefs_app_repository.dart';
import '../../features/app_state/presentation/controllers/app_controller.dart';
import '../../features/app_state/presentation/cubits/app_cubit.dart';
import '../../features/budget/data/repositories/budget_shared_prefs_repository.dart';
import '../../features/budget/presentation/controllers/budget_controller.dart';
import '../../features/transactions/data/repositories/transaction_shared_prefs_repository.dart';
import '../../features/transactions/presentation/controllers/transaction_controller.dart';
import '../../features/wallets/data/repositories/wallet_shared_prefs_repository.dart';
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
    final SharedPrefsAppRepository repository = SharedPrefsAppRepository(prefs);
    final cubit = AppCubit(repository);
    await cubit.initialize();
    return cubit;
  }

  static Future<AppControllers> initializeControllers() async {
    final prefs = await SharedPreferences.getInstance();
    final appRepository = SharedPrefsAppRepository(prefs);
    final walletRepository = WalletSharedPrefsRepository(prefs);
    final transactionRepository = TransactionSharedPrefsRepository(prefs);
    final budgetRepository = BudgetSharedPrefsRepository(prefs);

    final appController = AppController(appRepository);
    final walletController = WalletController(walletRepository);
    final transactionController = TransactionController(
      transactionRepository,
      walletRepository,
      budgetRepository,
    );
    final budgetController = BudgetController(budgetRepository);

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
