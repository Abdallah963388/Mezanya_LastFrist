import '../../../../core/results/result.dart';
import '../../../app_state/domain/services/transaction_mutation_service.dart';
import '../../../budget/domain/repositories/budget_repository.dart';
import '../../../wallets/domain/repositories/wallet_repository.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';
import '../services/financial_transaction_engine.dart';
import '../services/transaction_submission_service.dart';

class AddTransactionUseCase {
  const AddTransactionUseCase({
    required FinancialTransactionEngine engine,
  })  : _engine = engine,
        _walletRepository = null,
        _transactionRepository = null,
        _budgetRepository = null;

  const AddTransactionUseCase.repository(
    WalletRepository walletRepository,
    TransactionRepository transactionRepository,
    BudgetRepository budgetRepository,
  )   : _walletRepository = walletRepository,
        _transactionRepository = transactionRepository,
        _budgetRepository = budgetRepository,
        _engine = null;

  final FinancialTransactionEngine? _engine;
  final WalletRepository? _walletRepository;
  final TransactionRepository? _transactionRepository;
  final BudgetRepository? _budgetRepository;

  Future<Result<void>> call(
    TransactionSubmissionRequest request,
  ) async {
    final execution = await _engine!.execute(request);

    if (!execution.success) {
      return Result.failure(
        TransactionFailure(
          execution.errorMessage ?? 'فشل تنفيذ المعاملة.',
        ),
      );
    }

    return Result.success(null);
  }

  Future<List<TransactionEntity>> add(TransactionEntity transaction) async {
    final wallets = await _walletRepository!.loadWallets();
    final transactions = await _transactionRepository!.loadTransactions();
    final budget = await _budgetRepository!.loadBudget();

    final next = TransactionMutationService.applyTransaction(
      wallets: wallets,
      transactions: transactions,
      budgetSetup: budget,
      transaction: transaction,
    );

    await _walletRepository.saveWallets(next.wallets);
    await _budgetRepository.saveBudget(next.budgetSetup);
    await _transactionRepository.saveTransactions(next.transactions);

    return next.transactions;
  }
}
