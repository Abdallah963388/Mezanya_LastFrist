import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionSharedPrefsRepository implements TransactionRepository {
  TransactionSharedPrefsRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<TransactionEntity>> loadTransactions() async {
    final transactions = _readTransactions();
    if (transactions != null) {
      return transactions;
    }

    final legacyTransactions =
        _readLegacyTransactions() ?? AppStateEntity.initial().transactions;
    await saveTransactions(legacyTransactions);
    return legacyTransactions;
  }

  @override
  Future<void> saveTransactions(List<TransactionEntity> transactions) async {
    await _prefs.setString(
      SharedPrefsKeys.transactions,
      jsonEncode(
        transactions.map((transaction) => transaction.toMap()).toList(),
      ),
    );
  }

  List<TransactionEntity>? _readTransactions() {
    final payload = _prefs.getString(SharedPrefsKeys.transactions);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TransactionEntity.fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<TransactionEntity>? _readLegacyTransactions() {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded).transactions;
    } catch (_) {
      return null;
    }
  }
}
