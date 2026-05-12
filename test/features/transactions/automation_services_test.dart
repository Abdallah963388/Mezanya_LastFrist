import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/transactions/domain/automation/debt_payment_service.dart';
import 'package:mezanya_app/features/transactions/domain/automation/recurring_expense_service.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';

void main() {
  test('debt payment service creates debt transaction and updates wallet', () {
    final result = DebtPaymentService.apply(
      wallets: const [WalletEntity(id: 'wallet-1', name: 'Cash', balance: 100)],
      transactions: const [],
      debts: const [
        DebtEntity(
          id: 'debt-1',
          name: 'Loan',
          amount: 40,
          executionDay: 1,
          type: 'confirm',
          fundingSource: 'income-1',
        ),
      ],
      transaction: TransactionEntity(
        id: 'txn-1',
        walletId: 'wallet-1',
        amount: 100,
        type: 'income',
        incomeSourceId: 'income-1',
        createdAt: DateTime(2026),
      ),
      sourceId: 'income-1',
      amount: 40,
    );

    expect(result.wallets.single.balance, 60);
    expect(result.transactions.single.type, 'expense');
    expect(result.remainingAmount, 0);
  });

  test('recurring expense service appends due transaction only', () {
    final dueTransaction = TransactionEntity(
      id: 'txn-due',
      amount: 10,
      type: 'expense',
      createdAt: DateTime(2026),
    );

    expect(
      RecurringExpenseService.appendIfDue(
        transactions: const [],
        dueTransaction: dueTransaction,
      ),
      [dueTransaction],
    );
    expect(
      RecurringExpenseService.appendIfDue(transactions: const []),
      isEmpty,
    );
  });
}
