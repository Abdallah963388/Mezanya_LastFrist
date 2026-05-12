import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/storage/shared_prefs_keys.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/budget/data/repositories/budget_shared_prefs_repository.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('migrates budget from legacy app state', () async {
    final legacy = AppStateEntity.initial().copyWith(
      budgetSetup: BudgetSetupEntity.initial('wallet-1').copyWith(startDay: 7),
    );
    SharedPreferences.setMockInitialValues({
      SharedPrefsKeys.appState: jsonEncode(legacy.toMap()),
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = BudgetSharedPrefsRepository(prefs);

    final budget = await repository.loadBudget();

    expect(budget.startDay, 7);
    expect(prefs.containsKey(SharedPrefsKeys.budget), isTrue);
  });
}
