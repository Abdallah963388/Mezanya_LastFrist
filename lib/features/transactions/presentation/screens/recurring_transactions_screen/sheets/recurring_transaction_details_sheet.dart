import 'package:flutter/material.dart';

import '../../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../../../app_state/domain/entities/app_state_entity.dart';
import '../../../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../../domain/entities/recurring_transaction_entity.dart';
import '../../../../domain/entities/transaction_entity.dart';
import '../../../widgets/transaction_details_sheet.dart';
import '../helpers/recurring_transactions_screen_helper.dart';

Future<void> showRecurringTransactionDetailsSheet({
  required BuildContext context,
  required AppCubit cubit,
  required AppStateEntity state,
  required RecurringTransactionEntity record,
  required Color cardBackground,
  required Future<void> Function() onEdit,
}) async {
  final accent = RecurringTransactionsScreenHelper.parseColor(record.iconColor);
  final relatedTransactions = RecurringTransactionsScreenHelper.relatedTransactions(state, record);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.84,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(record.icon, color: accent, size: 31),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${RecurringTransactionsScreenHelper.typeLabel(record)} · ${RecurringTransactionsScreenHelper.executionLabel(record.executionType)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  record.isVariableIncome ? 'متغير' : record.amount.toStringAsFixed(2),
                  style: const TextStyle(color: Color(0xFF254034), fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailsTable(rows: RecurringTransactionsScreenHelper.detailsRows(state, record)),
          const SizedBox(height: 14),
          _RelatedTransactionsSection(transactions: relatedTransactions, cubit: cubit),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await cubit.deleteRecurringTransaction(record.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RelatedTransactionsSection extends StatelessWidget {
  const _RelatedTransactionsSection({required this.transactions, required this.cubit});

  final List<TransactionEntity> transactions;
  final AppCubit cubit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المعاملات المرتبطة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            transactions.isEmpty
                ? 'لا توجد معاملات مسجلة لهذه العملية المتكررة حتى الآن.'
                : 'آخر المعاملات المسجلة المرتبطة بهذه العملية.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...transactions.map((transaction) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RelatedTransactionTile(transaction: transaction, cubit: cubit),
            )),
          ],
        ],
      ),
    );
  }
}

class _RelatedTransactionTile extends StatelessWidget {
  const _RelatedTransactionTile({required this.transaction, required this.cubit});

  final TransactionEntity transaction;
  final AppCubit cubit;

  @override
  Widget build(BuildContext context) {
    final date = '${transaction.createdAt.day.toString().padLeft(2, '0')}/${transaction.createdAt.month.toString().padLeft(2, '0')}/${transaction.createdAt.year}';
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(transaction.amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(transaction.notes?.trim().isNotEmpty == true ? '${transaction.notes}\n$date' : date),
      isThreeLine: transaction.notes?.trim().isNotEmpty == true,
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => openTransactionDetailsSheet(context, cubit: cubit, transaction: transaction),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: rows.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(entry.value, textAlign: TextAlign.start, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.key,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

