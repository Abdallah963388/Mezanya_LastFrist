import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

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
        final wallets = state.wallets;
        final txns = state.transactions;
        final monthTx = txns
            .where((t) =>
                t.createdAt.year == _month.year &&
                t.createdAt.month == _month.month &&
                !_isJarReserveTx(t))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final totalWalletBalances =
            wallets.fold<double>(0, (sum, wallet) => sum + wallet.balance);
        final netIncome = monthTx
            .where((t) => t.type == 'income')
            .fold<double>(0, (s, t) => s + t.amount);
        final netExpense = monthTx
            .where((t) => t.type == 'expense')
            .fold<double>(0, (s, t) => s + t.amount);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _monthBar(context),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C6D25), Color(0xFF096119)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x201C6D25),
                    blurRadius: 40,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي المحافظ',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      '${totalWalletBalances.toStringAsFixed(2)} ${state.currencyCode}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _mini('صافي دخل الشهر', netIncome)),
                        const SizedBox(width: 10),
                        Expanded(child: _mini('صافي مصروف الشهر', netExpense)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SquareSection(
              title: 'المعاملات',
              subtitle: 'آخر الحركات في هذا الشهر',
              onMore: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AllTransactionsPage(
                      cubit: widget.cubit,
                      allTransactions: txns,
                      initialMonth: _month,
                    ),
                  ),
                );
              },
              child: monthTx.isEmpty
                  ? const _SectionEmpty(text: 'لا توجد معاملات لهذا الشهر.')
                  : SingleChildScrollView(
                      child: Column(
                        children: monthTx
                            .take(4)
                            .map((t) => _txnTile(context, t))
                            .toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _SquareSection(
              title: 'الرسم البياني',
              subtitle: 'تحليل معاملات آخر شهر',
              onMore: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ChartsPage(
                      allTransactions: txns,
                      initialMonth: _month,
                    ),
                  ),
                );
              },
              child: monthTx.isEmpty
                  ? const _SectionEmpty(text: 'لا توجد بيانات للشارت الآن.')
                  : _ChartPreview(monthTx: monthTx),
            ),
          ],
        );
      },
    );
  }

  Widget _monthBar(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(_month);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
                child: Center(
                    child: Text(monthLabel,
                        style: Theme.of(context).textTheme.titleMedium))),
            IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txnTile(BuildContext context, TransactionEntity t) {
    return ListTile(
      dense: true,
      title: Text(t.notes?.isNotEmpty == true ? t.notes! : _txTypeName(t.type)),
      subtitle: Text(DateFormat('d/M/yyyy').format(t.createdAt)),
      trailing: Text(
        '${t.type == 'expense' ? '-' : '+'}${t.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: t.type == 'expense'
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: () => openTransactionDetailsSheet(
        context,
        cubit: widget.cubit,
        transaction: t,
      ),
    );
  }

  String _txTypeName(String type) {
    if (type == 'income') return 'دخل';
    if (type == 'expense') return 'مصروف';
    return 'تحويل';
  }

  bool _isJarReserveTx(TransactionEntity t) {
    return t.transferType == 'jar-allocation' ||
        t.transferType == 'jar-allocation-cancel' ||
        t.transferType == 'jar-allocation-spend';
  }

  Widget _mini(String title, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

class _SquareSection extends StatelessWidget {
  const _SquareSection({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Expanded(child: child),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: onMore, child: const Text('المزيد')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
}

class _ChartPreview extends StatelessWidget {
  const _ChartPreview({required this.monthTx});
  final List<TransactionEntity> monthTx;

  @override
  Widget build(BuildContext context) {
    final income = monthTx
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = monthTx
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);
    final transfer = monthTx
        .where((t) => t.type == 'transfer')
        .fold<double>(0, (s, t) => s + t.amount);
    final maxValue =
        [income, expense, transfer].fold<double>(1, (m, v) => v > m ? v : m);
    return Column(
      children: [
        _bar(context, 'دخل', income, maxValue, const Color(0xFF16A34A)),
        _bar(context, 'مصروف', expense, maxValue, const Color(0xFFDC2626)),
        _bar(context, 'تحويل', transfer, maxValue, const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _bar(BuildContext context, String label, double value, double max,
      Color color) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 11,
                color: color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _AllTransactionsPage extends StatefulWidget {
  const _AllTransactionsPage({
    required this.cubit,
    required this.allTransactions,
    required this.initialMonth,
  });

  final AppCubit cubit;
  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<_AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<_AllTransactionsPage> {
  String _tab = 'all';
  String _range = 'month';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter(widget.allTransactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('كل المعاملات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('all', 'عام'),
                _chip('income', 'دخل'),
                _chip('expense', 'مصروف'),
                _chip('transfer', 'تحويل'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _range,
            decoration: const InputDecoration(labelText: 'فلتر التاريخ'),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('آخر يوم')),
              DropdownMenuItem(value: 'week', child: Text('آخر أسبوع')),
              DropdownMenuItem(value: 'month', child: Text('آخر شهر')),
              DropdownMenuItem(
                  value: 'specific-month', child: Text('شهر معين')),
              DropdownMenuItem(
                  value: 'custom', child: Text('من تاريخ إلى تاريخ')),
            ],
            onChanged: (v) => setState(() => _range = v ?? 'month'),
          ),
          if (_range == 'specific-month') ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month - 1, 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    Expanded(
                        child: Center(
                            child: Text(
                                DateFormat('MMMM yyyy', 'ar').format(_month)))),
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month + 1, 1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_range == 'custom') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('من تاريخ'),
                    subtitle: Text(_from == null
                        ? 'اختر'
                        : DateFormat('d/M/yyyy').format(_from!)),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _from ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setState(() => _from = p);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('إلى تاريخ'),
                    subtitle: Text(_to == null
                        ? 'اختر'
                        : DateFormat('d/M/yyyy').format(_to!)),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _to ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setState(() => _to = p);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const Card(child: ListTile(title: Text('لا توجد معاملات مطابقة.')))
          else
            ...filtered.map((t) => Card(
                  child: ListTile(
                    title:
                        Text(t.notes?.isNotEmpty == true ? t.notes! : t.type),
                    subtitle: Text(
                        DateFormat('d/M/yyyy - HH:mm').format(t.createdAt)),
                    trailing: Text(
                      '${t.type == 'expense' ? '-' : '+'}${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.type == 'expense'
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () => openTransactionDetailsSheet(
                      context,
                      cubit: widget.cubit,
                      transaction: t,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _chip(String id, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _tab == id,
        onSelected: (_) => setState(() => _tab = id),
      ),
    );
  }

  List<TransactionEntity> _filter(List<TransactionEntity> tx) {
    final now = DateTime.now();
    var out = tx.where((t) => !_isJarReserveTx(t)).toList();
    if (_tab != 'all') out = out.where((t) => t.type == _tab).toList();
    if (_range == 'day') {
      out =
          out.where((t) => now.difference(t.createdAt).inHours <= 24).toList();
    } else if (_range == 'week') {
      out = out.where((t) => now.difference(t.createdAt).inDays <= 7).toList();
    } else if (_range == 'month') {
      out = out.where((t) => now.difference(t.createdAt).inDays <= 30).toList();
    } else if (_range == 'specific-month') {
      out = out
          .where((t) =>
              t.createdAt.year == _month.year &&
              t.createdAt.month == _month.month)
          .toList();
    } else if (_range == 'custom' && _from != null && _to != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      out = out
          .where(
              (t) => !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end))
          .toList();
    }
    return out;
  }

  bool _isJarReserveTx(TransactionEntity t) {
    return t.transferType == 'jar-allocation' ||
        t.transferType == 'jar-allocation-cancel' ||
        t.transferType == 'jar-allocation-spend';
  }
}

class _ChartsPage extends StatefulWidget {
  const _ChartsPage({
    required this.allTransactions,
    required this.initialMonth,
  });

  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<_ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<_ChartsPage> {
  String _mode = 'monthly';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _from;
  DateTime? _to;
  bool _yearly = false;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final tx = _filtered(widget.allTransactions);
    final income = tx
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = tx
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);
    final transfer = tx
        .where((t) => t.type == 'transfer')
        .fold<double>(0, (s, t) => s + t.amount);
    final max =
        [income, expense, transfer].fold<double>(1, (m, v) => v > m ? v : m);

    return Scaffold(
      appBar: AppBar(title: const Text('تحليلات المعاملات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                  child: Center(
                      child:
                          Text(DateFormat('MMMM yyyy', 'ar').format(_month)))),
              IconButton(
                onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(labelText: 'فلتر المدة'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('شهري')),
              DropdownMenuItem(
                  value: 'custom', child: Text('من تاريخ إلى تاريخ')),
              DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
            ],
            onChanged: (v) => setState(() {
              _mode = v ?? 'monthly';
              _yearly = _mode == 'yearly';
            }),
          ),
          if (_mode == 'custom') ...[
            const SizedBox(height: 8),
            ListTile(
              title: const Text('من'),
              subtitle: Text(_from == null
                  ? 'اختر'
                  : DateFormat('d/M/yyyy').format(_from!)),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _from ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _from = p);
              },
            ),
            ListTile(
              title: const Text('إلى'),
              subtitle: Text(
                  _to == null ? 'اختر' : DateFormat('d/M/yyyy').format(_to!)),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _to ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _to = p);
              },
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _chartRow(
                      context, 'دخل', income, max, const Color(0xFF16A34A)),
                  _chartRow(
                      context, 'مصروف', expense, max, const Color(0xFFDC2626)),
                  _chartRow(
                      context, 'تحويل', transfer, max, const Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملخص المقارنة',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('الدخل: ${income.toStringAsFixed(2)}'),
                  Text('المصروف: ${expense.toStringAsFixed(2)}'),
                  Text('التحويل: ${transfer.toStringAsFixed(2)}'),
                  Text('الصافي: ${(income - expense).toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartRow(BuildContext context, String label, double value, double max,
      Color color) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                color: color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  List<TransactionEntity> _filtered(List<TransactionEntity> tx) {
    if (_mode == 'monthly') {
      return tx
          .where((t) =>
              t.createdAt.year == _month.year &&
              t.createdAt.month == _month.month)
          .toList();
    }
    if (_mode == 'yearly' || _yearly) {
      return tx.where((t) => t.createdAt.year == _month.year).toList();
    }
    if (_mode == 'custom' && _from != null && _to != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      return tx
          .where(
              (t) => !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end))
          .toList();
    }
    return tx;
  }
}
