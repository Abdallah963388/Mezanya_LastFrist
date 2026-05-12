import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/budget/domain/repositories/budget_repository.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:mezanya_app/features/transactions/presentation/controllers/transaction_controller.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:mezanya_app/features/wallets/domain/repositories/wallet_repository.dart';

class _MemoryFinanceRepository
    implements WalletRepository, TransactionRepository, BudgetRepository {
  _MemoryFinanceRepository({
    required List<WalletEntity> wallets,
    required BudgetSetupEntity budget,
    List<TransactionEntity>? transactions,
  })  : _wallets = wallets,
        _budget = budget,
        _transactions = transactions ?? <TransactionEntity>[];

  List<WalletEntity> _wallets;
  List<TransactionEntity> _transactions;
  BudgetSetupEntity _budget;

  List<WalletEntity> get wallets => _wallets;
  BudgetSetupEntity get budget => _budget;

  @override
  Future<List<WalletEntity>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) async {
    _wallets = wallets;
  }

  @override
  Future<List<TransactionEntity>> loadTransactions() async => _transactions;

  @override
  Future<void> saveTransactions(List<TransactionEntity> transactions) async {
    _transactions = transactions;
  }

  @override
  Future<BudgetSetupEntity> loadBudget() async => _budget;

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) async {
    _budget = budget;
  }
}

void main() {
  test('add transaction updates isolated transaction state', () async {
    final repository = _MemoryFinanceRepository(
      wallets: const [WalletEntity(id: 'wallet-1', name: 'Cash', balance: 100)],
      budget: BudgetSetupEntity.initial('wallet-1'),
    );
    final controller =
        TransactionController(repository, repository, repository);

    await controller.initialize();
    await controller.addTransaction(
      walletId: 'wallet-1',
      amount: 25,
      type: 'expense',
    );

    expect(controller.transactions, hasLength(1));
    expect(repository.wallets.single.balance, 75);
  });

  test('transfer updates source and destination wallets through pipeline',
      () async {
    final repository = _MemoryFinanceRepository(
      wallets: const [
        WalletEntity(id: 'wallet-1', name: 'Cash', balance: 100),
        WalletEntity(id: 'wallet-2', name: 'Bank', balance: 50),
      ],
      budget: BudgetSetupEntity.initial('wallet-1'),
    );
    final controller =
        TransactionController(repository, repository, repository);

    await controller.initialize();
    await controller.addTransaction(
      fromWalletId: 'wallet-1',
      toWalletId: 'wallet-2',
      amount: 40,
      type: 'transfer',
    );

    expect(repository.wallets.first.balance, 60);
    expect(repository.wallets.last.balance, 90);
  });

  test('income automation funds linked jars', () async {
    final budget = BudgetSetupEntity.initial('wallet-1').copyWith(
      linkedWallets: const [
        LinkedWalletEntity(
          id: 'jar-1',
          name: 'Emergency',
          monthlyAmount: 50,
          executionDay: 1,
          fundingSource: 'income-1',
          funding: [
            LinkedWalletEntityFunding(
              id: 'funding-1',
              incomeSourceId: 'income-1',
              plannedAmount: 30,
            ),
          ],
          icon: 'PiggyBank',
          iconColor: '#0f766e',
          automationType: 'auto',
          categories: [],
        ),
      ],
    );
    final repository = _MemoryFinanceRepository(
      wallets: const [WalletEntity(id: 'wallet-1', name: 'Cash', balance: 0)],
      budget: budget,
    );
    final controller =
        TransactionController(repository, repository, repository);

    await controller.initialize();
    await controller.addTransaction(
      walletId: 'wallet-1',
      amount: 100,
      type: 'income',
      incomeSourceId: 'income-1',
    );

    expect(repository.wallets.single.balance, 100);
    expect(repository.budget.linkedWallets.single.balance, 30);
    expect(controller.transactions, hasLength(2));
  });
}
