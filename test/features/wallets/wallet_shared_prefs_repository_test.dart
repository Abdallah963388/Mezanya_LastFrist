import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/storage/shared_prefs_keys.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/wallets/data/repositories/wallet_shared_prefs_repository.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads wallets from split key', () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsKeys.wallets: jsonEncode([
        const WalletEntity(id: 'wallet-1', name: 'Cash', balance: 100).toMap(),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = WalletSharedPrefsRepository(prefs);

    final wallets = await repository.loadWallets();

    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Cash');
  });

  test('migrates wallets from legacy app state when split key is missing',
      () async {
    final legacy = AppStateEntity.initial().copyWith(
      wallets: const [
        WalletEntity(id: 'wallet-legacy', name: 'Legacy', balance: 250),
      ],
    );
    SharedPreferences.setMockInitialValues({
      SharedPrefsKeys.appState: jsonEncode(legacy.toMap()),
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = WalletSharedPrefsRepository(prefs);

    final wallets = await repository.loadWallets();

    expect(wallets.single.id, 'wallet-legacy');
    expect(prefs.containsKey(SharedPrefsKeys.wallets), isTrue);
  });
}
