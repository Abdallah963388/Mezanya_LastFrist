import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/storage/shared_prefs_keys.dart';
import '../../../../app_state/domain/entities/app_state_entity.dart';
import '../../../domain/entities/budget_setup_entity.dart';
import 'budget_local_data_source.dart';

class SharedPrefsBudgetLocalDataSource implements BudgetLocalDataSource {
  SharedPrefsBudgetLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<BudgetSetupEntity> loadBudget() async {
    final budget = _readBudget();
    if (budget != null) {
      return budget;
    }

    final legacyBudget =
        _readLegacyBudget() ?? AppStateEntity.initial().budgetSetup;
    await saveBudget(legacyBudget);
    return legacyBudget;
  }

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) async {
    await _prefs.setString(
      SharedPrefsKeys.budget,
      jsonEncode(budget.toMap()),
    );
  }

  BudgetSetupEntity? _readBudget() {
    final payload = _prefs.getString(SharedPrefsKeys.budget);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return BudgetSetupEntity.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  BudgetSetupEntity? _readLegacyBudget() {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded).budgetSetup;
    } catch (_) {
      return null;
    }
  }
}
