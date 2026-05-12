import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';
import 'budget_mutation_service.dart';
import 'transaction_mutation_service.dart';
import 'wallet_mutation_service.dart';

class AppStateMutationService {
  const AppStateMutationService._();

  static AppStateEntity addWallet({
    required AppStateEntity current,
    required WalletEntity wallet,
  }) {
    return WalletMutationService.addWallet(
      current: current,
      wallet: wallet,
    );
  }

  static AppStateEntity updateBudgetSetup({
    required AppStateEntity current,
    required BudgetSetupEntity budgetSetup,
  }) {
    return BudgetMutationService.updateBudgetSetup(
      current: current,
      budgetSetup: budgetSetup,
    );
  }

  static AppStateEntity addTransaction({
    required AppStateEntity current,
    required TransactionEntity transaction,
  }) {
    return TransactionMutationService.addTransaction(
      current: current,
      transaction: transaction,
    );
  }
}
