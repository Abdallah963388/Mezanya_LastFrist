import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/storage/shared_prefs_keys.dart';
import '../../../../app_state/domain/entities/app_state_entity.dart';
import '../../../domain/entities/wallet_entity.dart';
import 'wallet_local_data_source.dart';

class SharedPrefsWalletLocalDataSource implements WalletLocalDataSource {
  SharedPrefsWalletLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<WalletEntity>> loadWallets() async {
    final wallets = _readWallets();
    if (wallets != null) {
      return wallets;
    }

    final legacyWallets =
        _readLegacyWallets() ?? AppStateEntity.initial().wallets;
    await saveWallets(legacyWallets);
    return legacyWallets;
  }

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) async {
    await _prefs.setString(
      SharedPrefsKeys.wallets,
      jsonEncode(wallets.map((wallet) => wallet.toMap()).toList()),
    );
  }

  List<WalletEntity>? _readWallets() {
    final payload = _prefs.getString(SharedPrefsKeys.wallets);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WalletEntity.fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<WalletEntity>? _readLegacyWallets() {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded).wallets;
    } catch (_) {
      return null;
    }
  }
}
