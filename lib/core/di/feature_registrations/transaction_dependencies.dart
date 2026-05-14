import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/budget/domain/repositories/budget_repository.dart';
import '../../../features/transactions/data/datasources/local/shared_prefs_transaction_local_data_source.dart';
import '../../../features/transactions/data/datasources/local/transaction_local_data_source.dart';
import '../../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../../features/transactions/domain/usecases/add_transaction_usecase.dart';
import '../../../features/transactions/domain/usecases/delete_transaction_usecase.dart';
import '../../../features/transactions/domain/usecases/update_transaction_usecase.dart';
import '../../../features/transactions/presentation/controllers/transaction_controller.dart';
import '../../../features/transactions/presentation/cubits/transaction_cubit.dart';
import '../../../features/wallets/domain/repositories/wallet_repository.dart';

void registerTransactionDependencies(GetIt sl) {
  if (!sl.isRegistered<TransactionLocalDataSource>()) {
    sl.registerLazySingleton<TransactionLocalDataSource>(
      () => SharedPrefsTransactionLocalDataSource(sl<SharedPreferences>()),
    );
  }

  if (!sl.isRegistered<TransactionRepository>()) {
    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl<TransactionLocalDataSource>()),
    );
  }

  if (!sl.isRegistered<AddTransactionUseCase>()) {
    sl.registerLazySingleton<AddTransactionUseCase>(
      () => AddTransactionUseCase.repository(
        sl<WalletRepository>(),
        sl<TransactionRepository>(),
        sl<BudgetRepository>(),
      ),
    );
  }

  if (!sl.isRegistered<DeleteTransactionUseCase>()) {
    sl.registerLazySingleton<DeleteTransactionUseCase>(
      () => const DeleteTransactionUseCase(),
    );
  }

  if (!sl.isRegistered<UpdateTransactionUseCase>()) {
    sl.registerLazySingleton<UpdateTransactionUseCase>(
      () => const UpdateTransactionUseCase(),
    );
  }

  if (!sl.isRegistered<TransactionController>()) {
    sl.registerLazySingleton<TransactionController>(
      () => TransactionController(
        sl<TransactionRepository>(),
        sl<WalletRepository>(),
        sl<BudgetRepository>(),
        addTransactionUseCase: sl<AddTransactionUseCase>(),
      ),
    );
  }

  if (!sl.isRegistered<TransactionCubit>()) {
    sl.registerFactory<TransactionCubit>(
      () => TransactionCubit(
        sl<TransactionRepository>(),
        sl<AddTransactionUseCase>(),
        deleteTransactionUseCase: sl<DeleteTransactionUseCase>(),
        updateTransactionUseCase: sl<UpdateTransactionUseCase>(),
      ),
    );
  }
}
