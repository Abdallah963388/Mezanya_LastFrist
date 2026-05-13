import 'package:flutter/material.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class WalletsTransactionTile extends StatelessWidget {
  const WalletsTransactionTile({
    super.key,
    required this.transaction,
    required this.state,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final AppStateEntity state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNegative = transaction.type == 'expense' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend';
    final label = _label();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4DCCF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isNegative ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: isNegative
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF165B47),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
                    style: const TextStyle(color: Color(0xFF7D7461)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }

  String _walletName(String? id) {
    if (id == null || id.isEmpty) return 'محفظة غير محددة';
    return state.wallets
            .where((wallet) => wallet.id == id)
            .map((wallet) => wallet.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null) ??
        id;
  }

  String _jarName(String? id) {
    if (id == null || id.isEmpty) return 'حصالة غير محددة';
    return state.budgetSetup.linkedWallets
            .where((jar) => jar.id == id)
            .map((jar) => jar.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null) ??
        id;
  }

  String _incomeName(String? id) {
    if (id == null || id.isEmpty) return 'الدخل';
    return state.budgetSetup.incomeSources
            .where((source) => source.id == id)
            .map((source) => source.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null) ??
        id;
  }

  String _label() {
    switch (transaction.transferType) {
      case 'jar-funding':
        return 'حجز من ${_incomeName(transaction.incomeSourceId)} من محفظة ${_walletName(transaction.fromWalletId)} إلى ${_jarName(transaction.toWalletId)}';
      case 'jar-allocation':
      case 'allocation-to-jar':
        return 'حجز من محفظة ${_walletName(transaction.fromWalletId)} إلى ${_jarName(transaction.toWalletId)}';
      case 'jar-allocation-cancel':
        return 'إلغاء حجز من ${_jarName(transaction.toWalletId ?? transaction.walletId)}';
      case 'jar-allocation-spend':
        return 'سحب من ${_jarName(transaction.toWalletId ?? transaction.walletId)}';
      case 'jar-to-allocation':
        return 'تحويل من ${_jarName(transaction.walletId)} إلى مخصص';
      case 'wallet-to-wallet':
        return 'تحويل من ${_walletName(transaction.fromWalletId)} إلى ${_walletName(transaction.toWalletId)}';
    }
    return transaction.notes ??
        switch (transaction.type) {
          'income' => 'دخل',
          'expense' => 'مصروف',
          _ => 'تحويل',
        };
  }
}
