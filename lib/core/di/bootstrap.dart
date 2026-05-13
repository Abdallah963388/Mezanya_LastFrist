import '../../features/app_state/presentation/controllers/app_controller.dart';
import '../../features/app_state/presentation/cubits/app_cubit.dart';
import '../../features/budget/presentation/controllers/budget_controller.dart';
import '../../features/transactions/presentation/controllers/transaction_controller.dart';
import '../../features/wallets/presentation/controllers/wallet_controller.dart';
import 'injection_container.dart';

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
    await configureDependencies();

    final transactionController = sl<TransactionController>();
    await transactionController.initialize();

    final cubit = sl<AppCubit>();
    await cubit.initialize();
    return cubit;
  }

  static Future<AppControllers> initializeControllers() async {
    await configureDependencies();

    final appController = sl<AppController>();
    final walletController = sl<WalletController>();
    final transactionController = sl<TransactionController>();
    final budgetController = sl<BudgetController>();

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
