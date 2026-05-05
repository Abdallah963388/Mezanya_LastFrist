import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../widgets/money_overview_widgets.dart';
import 'all_transactions_screen.dart';
import 'transaction_charts_screen.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final transactions = state.transactions;
        final monthTransactions = _monthTransactions(transactions)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final totalWalletBalances = state.wallets.fold<double>(
          0,
          (sum, wallet) => sum + wallet.balance,
        );
        final netIncome = monthTransactions
            .where((transaction) => transaction.type == 'income')
            .fold<double>(0, (sum, transaction) => sum + transaction.amount);
        final netExpense = monthTransactions
            .where((transaction) => transaction.type == 'expense')
            .fold<double>(0, (sum, transaction) => sum + transaction.amount);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MoneyMonthSelectorCard(
              label: DateFormat('MMMM yyyy', 'ar').format(_month),
              onPreviousMonth: _openPreviousMonth,
              onNextMonth: _openNextMonth,
            ),
            const SizedBox(height: 12),
            MoneySummaryCard(
              currencyCode: state.currencyCode,
              totalWalletBalances: totalWalletBalances,
              netIncome: netIncome,
              netExpense: netExpense,
            ),
            const SizedBox(height: 12),
            MoneyDashboardSection(
              title: 'المعاملات',
              subtitle: 'آخر الحركات في هذا الشهر',
              onMore: () => _openAllTransactions(transactions),
              child: monthTransactions.isEmpty
                  ? const MoneySectionEmptyState(
                      text: 'لا توجد معاملات لهذا الشهر.',
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: monthTransactions.take(4).map((transaction) {
                          return _buildTransactionTile(context, transaction);
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            MoneyDashboardSection(
              title: 'الرسم البياني',
              subtitle: 'تحليل معاملات آخر شهر',
              onMore: () => _openCharts(transactions),
              child: monthTransactions.isEmpty
                  ? const MoneySectionEmptyState(
                      text: 'لا توجد بيانات للشارت الآن.',
                    )
                  : MoneyChartPreview(transactions: monthTransactions),
            ),
          ],
        );
      },
    );
  }

  List<TransactionEntity> _monthTransactions(List<TransactionEntity> source) {
    return source
        .where(
          (transaction) =>
              transaction.createdAt.year == _month.year &&
              transaction.createdAt.month == _month.month &&
              !_isJarReserveTx(transaction),
        )
        .toList();
  }

  Widget _buildTransactionTile(
    BuildContext context,
    TransactionEntity transaction,
  ) {
    return MoneyTransactionTile(
      transaction: transaction,
      title: transaction.notes?.isNotEmpty == true
          ? transaction.notes!
          : _transactionTypeName(transaction.type),
      subtitle: DateFormat('d MMMM yyyy', 'ar').format(transaction.createdAt),
      onTap: () => openTransactionDetailsSheet(
        context,
        cubit: widget.cubit,
        transaction: transaction,
      ),
    );
  }

  void _openPreviousMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
  }

  void _openNextMonth() {
    setState(() => _month = DateTime(_month.year, _month.month + 1, 1));
  }

  void _openAllTransactions(List<TransactionEntity> transactions) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllTransactionsScreen(
          cubit: widget.cubit,
          allTransactions: transactions,
          initialMonth: _month,
        ),
      ),
    );
  }

  void _openCharts(List<TransactionEntity> transactions) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionChartsScreen(
          cubit: widget.cubit,
          allTransactions: transactions,
          initialMonth: _month,
        ),
      ),
    );
  }

  String _transactionTypeName(String type) {
    if (type == 'income') {
      return 'دخل';
    }
    if (type == 'expense') {
      return 'مصروف';
    }
    return 'تحويل';
  }

  bool _isJarReserveTx(TransactionEntity transaction) {
    return transaction.transferType == 'jar-allocation' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend';
  }
}
