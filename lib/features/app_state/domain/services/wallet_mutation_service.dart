import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';

class WalletMutationService {
  const WalletMutationService._();

  static AppStateEntity addWallet({
    required AppStateEntity current,
    required WalletEntity wallet,
  }) {
    return current.copyWith(
      wallets: <WalletEntity>[
        ...current.wallets,
        wallet,
      ],
    );
  }
}
