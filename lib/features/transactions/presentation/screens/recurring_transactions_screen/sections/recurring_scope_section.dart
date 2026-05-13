import 'package:flutter/material.dart';

import '../../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../../../app_state/domain/entities/app_state_entity.dart';
import '../../../../domain/entities/recurring_transaction_entity.dart';
import '../helpers/recurring_transactions_screen_helper.dart';

class RecurringScopeSection extends StatelessWidget {
  const RecurringScopeSection({
    super.key,
    required this.state,
    required this.title,
    required this.subtitle,
    required this.records,
    required this.emptyLabel,
    required this.accent,
    required this.cardBackground,
    required this.onRecordTap,
  });

  final AppStateEntity state;
  final String title;
  final String subtitle;
  final List<RecurringTransactionEntity> records;
  final String emptyLabel;
  final Color accent;
  final Color cardBackground;
  final ValueChanged<RecurringTransactionEntity> onRecordTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = records.where((item) => !item.isVariableIncome).fold<double>(0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.layers_rounded, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          if (records.isEmpty)
            _RecurringEmptyCard(text: emptyLabel)
          else
            ...records.map(
              (record) => _RecurringCard(
                state: state,
                record: record,
                cardBackground: cardBackground,
                onTap: () => onRecordTap(record),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecurringEmptyCard extends StatelessWidget {
  const _RecurringEmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.state,
    required this.record,
    required this.cardBackground,
    required this.onTap,
  });

  final AppStateEntity state;
  final RecurringTransactionEntity record;
  final Color cardBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = RecurringTransactionsScreenHelper.parseColor(record.iconColor);
    final amountLabel = record.isVariableIncome ? 'متغير' : record.amount.toStringAsFixed(2);
    final wallet = RecurringTransactionsScreenHelper.walletName(state, record.walletId);
    final execution = RecurringTransactionsScreenHelper.executionLabel(record.executionType);
    final scope = record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(record.icon, color: accent, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                        Text(
                          amountLabel,
                          style: const TextStyle(color: Color(0xFF254034), fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      RecurringTransactionsScreenHelper.recurrenceLabel(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniTag(text: execution),
                        _MiniTag(text: scope),
                        if (wallet != '-') _MiniTag(text: wallet),
                        if (record.type == 'expense') _MiniTag(text: RecurringTransactionsScreenHelper.expensePlanKindLabel(record)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Text(
        text,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

