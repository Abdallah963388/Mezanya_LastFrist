import '../../domain/entities/wallet_entity.dart';

class WalletState {
  const WalletState({
    this.wallets = const [],
    this.isLoading = false,
  });

  final List<WalletEntity> wallets;
  final bool isLoading;

  int get walletCount => wallets.length;

  bool get hasWallets => wallets.isNotEmpty;

  double get totalBalance =>
      wallets.fold(0, (sum, wallet) => sum + wallet.balance);

  List<WalletEntity> get positiveBalanceWallets =>
      wallets.where((wallet) => wallet.balance > 0).toList();

  WalletEntity? walletById(String id) {
    try {
      return wallets.firstWhere((wallet) => wallet.id == id);
    } catch (_) {
      return null;
    }
  }

  bool containsWallet(String id) {
    return wallets.any((wallet) => wallet.id == id);
  }

  WalletState copyWith({
    List<WalletEntity>? wallets,
    bool? isLoading,
  }) {
    return WalletState(
      wallets: wallets ?? this.wallets,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
