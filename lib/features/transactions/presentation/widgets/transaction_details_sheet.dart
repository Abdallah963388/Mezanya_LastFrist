import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/transaction_entity.dart';
import '../screens/add_transaction_screen.dart';

Future<void> openTransactionDetailsSheet(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  final theme = Theme.of(context);
  final accent = _accentForTransaction(theme, transaction);
  final rows = _detailRows(cubit, transaction);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      _iconForTransaction(transaction),
                      color: accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.categoryId != null &&
                                  transaction.categoryId!.isNotEmpty
                              ? (cubit.state.categories
                                      .where((c) =>
                                          c.id == transaction.categoryId)
                                      .firstOrNull
                                      ?.name ??
                                  transaction.notes?.trim() ??
                                  _typeLabel(transaction.type))
                              : transaction.notes?.trim().isNotEmpty == true
                                  ? transaction.notes!.trim()
                                  : _typeLabel(transaction.type),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // ملاحظات تفصيلية تحت الاسم لو الاسم من الفئة
                        if (transaction.categoryId != null &&
                            transaction.categoryId!.isNotEmpty &&
                            transaction.notes?.trim().isNotEmpty == true) ...[
                          Text(
                            transaction.notes!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accent.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          '${_typeLabel(transaction.type)} - ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(transaction.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    transaction.amount.toStringAsFixed(2),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailsBlock(rows: rows),
            const SizedBox(height: 18),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => FractionallySizedBox(
                    heightFactor: 0.96,
                    child: AddTransactionScreen(
                      cubit: cubit,
                      initialTransaction: transaction,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل المعاملة'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: accent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<MapEntry<String, String>> _detailRows(AppCubit cubit, TransactionEntity tx) {
  final state = cubit.state;
  String walletName(String? id) => state.wallets
          .where((w) => w.id == id)
          .map((w) => w.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String jarName(String? id) => state.budgetSetup.linkedWallets
          .where((j) => j.id == id)
          .map((j) => j.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String allocName(String? id) => state.budgetSetup.allocations
          .where((a) => a.id == id)
          .map((a) => a.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String categoryName(String? id) => state.categories
          .where((c) => c.id == id)
          .map((c) => c.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';

  return [
    MapEntry('النوع', _typeLabel(tx.type)),
    MapEntry('المبلغ', tx.amount.toStringAsFixed(2)),
    MapEntry('التاريخ', DateFormat('d MMMM yyyy', 'ar').format(tx.createdAt)),
    MapEntry('الوقت', DateFormat('HH:mm', 'ar').format(tx.createdAt)),
    if (tx.walletId != null) MapEntry('المحفظة', walletName(tx.walletId)),
    if (tx.fromWalletId != null)
      MapEntry('من محفظة', walletName(tx.fromWalletId)),
    if (tx.toWalletId != null) MapEntry('إلى', jarName(tx.toWalletId)),
    if (tx.allocationId != null) MapEntry('المخصص', allocName(tx.allocationId)),
    if (tx.categoryId != null) MapEntry('الفئة', categoryName(tx.categoryId)),
    if (tx.budgetScope != null)
      MapEntry('نطاق الميزانية', _budgetScopeLabel(tx.budgetScope!)),
    if (tx.transferType != null) MapEntry('نوع التحويل', tx.transferType!),
    if (tx.notes?.trim().isNotEmpty == true)
      MapEntry('الملاحظات', tx.notes!.trim()),
  ];
}

String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return 'دخل';
    case 'expense':
      return 'مصروف';
    default:
      return 'تحويل';
  }
}

String _budgetScopeLabel(String value) {
  switch (value) {
    case 'within-budget':
      return 'داخل الميزانية';
    case 'outside-budget':
      return 'خارج الميزانية';
    default:
      return value;
  }
}

IconData _iconForTransaction(TransactionEntity tx) {
  switch (tx.type) {
    case 'income':
      return Icons.south_west_rounded;
    case 'expense':
      return Icons.north_east_rounded;
    default:
      return Icons.swap_horiz_rounded;
  }
}

Color _accentForTransaction(ThemeData theme, TransactionEntity tx) {
  switch (tx.type) {
    case 'income':
      return const Color(0xFF1F8B5F);
    case 'expense':
      return const Color(0xFFC86D2B);
    default:
      return theme.colorScheme.primary;
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }
}