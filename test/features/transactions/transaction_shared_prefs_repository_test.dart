import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/storage/shared_prefs_keys.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/transactions/data/repositories/transaction_shared_prefs_repository.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('migrates transactions from legacy app state', () async {
    final legacy = AppStateEntity.initial().copyWith(
      transactions: [
        TransactionEntity(
          id: 'txn-legacy',
          amount: 50,
          type: 'income',
          createdAt: DateTime(2026),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      SharedPrefsKeys.appState: jsonEncode(legacy.toMap()),
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = TransactionSharedPrefsRepository(prefs);

    final transactions = await repository.loadTransactions();

    expect(transactions.single.id, 'txn-legacy');
    expect(prefs.containsKey(SharedPrefsKeys.transactions), isTrue);
  });
}
