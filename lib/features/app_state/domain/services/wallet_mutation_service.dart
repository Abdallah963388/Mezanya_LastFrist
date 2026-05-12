import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';

class WalletMutationService {
  const WalletMutationService._();

  static AppStateEntity addWallet({
    required AppStateEntity current,
    required WalletEntity wallet,
  }) {
    return current.copyWith(
      wallets: appendWallet(
        wallets: current.wallets,
        wallet: wallet,
      ),
    );
  }

  static List<WalletEntity> appendWallet({
    required List<WalletEntity> wallets,
    required WalletEntity wallet,
  }) {
    return <WalletEntity>[
      ...wallets,
      wallet,
    ];
  }

  static List<WalletEntity> updateWallet({
    required List<WalletEntity> wallets,
    required WalletEntity wallet,
  }) {
    return wallets.map((item) => item.id == wallet.id ? wallet : item).toList();
  }

  static List<WalletEntity> deleteWallet({
    required List<WalletEntity> wallets,
    required String id,
  }) {
    return wallets.where((wallet) => wallet.id != id).toList();
  }
}
