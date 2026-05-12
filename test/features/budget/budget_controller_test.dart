import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/budget/domain/repositories/budget_repository.dart';
import 'package:mezanya_app/features/budget/presentation/controllers/budget_controller.dart';

class _MemoryBudgetRepository implements BudgetRepository {
  _MemoryBudgetRepository(this._budget);

  BudgetSetupEntity _budget;

  @override
  Future<BudgetSetupEntity> loadBudget() async => _budget;

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) async {
    _budget = budget;
  }
}

void main() {
  test('update budget stores isolated budget setup', () async {
    final controller = BudgetController(
      _MemoryBudgetRepository(BudgetSetupEntity.initial('wallet-1')),
    );

    await controller.initialize();
    await controller.updateBudgetSetup(
      controller.budgetSetup.copyWith(startDay: 5),
    );

    expect(controller.budgetSetup.startDay, 5);
  });

  test('add linked wallet updates budget linked wallets only', () async {
    final controller = BudgetController(
      _MemoryBudgetRepository(BudgetSetupEntity.initial('wallet-1')),
    );

    await controller.initialize();
    await controller.addLinkedWallet(
      const LinkedWalletEntity(
        id: 'jar-1',
        name: 'Emergency',
        monthlyAmount: 50,
        executionDay: 1,
        fundingSource: 'income-1',
        funding: [],
        icon: 'PiggyBank',
        iconColor: '#0f766e',
        automationType: 'confirm',
        categories: [],
      ),
    );

    expect(controller.budgetSetup.linkedWallets, hasLength(1));
    expect(controller.budgetSetup.linkedWallets.single.name, 'Emergency');
  });
}
