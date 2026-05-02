import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

class TransactionChartsScreen extends StatefulWidget {
  const TransactionChartsScreen({
    super.key,
    required this.allTransactions,
    required this.initialMonth,
  });

  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<TransactionChartsScreen> createState() => _TransactionChartsScreenState();
}

class _TransactionChartsScreenState extends State<TransactionChartsScreen> {
  String _mode = 'monthly';
  late DateTime _selectedMonth;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions(widget.allTransactions);
    final income = _sumForType(transactions, 'income');
    final expense = _sumForType(transactions, 'expense');
    final transfer = _sumForType(transactions, 'transfer');
    final maxValue = [income, expense, transfer]
        .fold<double>(1, (max, value) => value > max ? value : max);

    return Scaffold(
      appBar: AppBar(title: const Text('تحليلات المعاملات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ChartsMonthSelector(
            label: DateFormat('MMMM yyyy', 'ar').format(_selectedMonth),
            onPreviousMonth: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                  1,
                );
              });
            },
            onNextMonth: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                  1,
                );
              });
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(labelText: 'فلتر المدة'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('شهري')),
              DropdownMenuItem(value: 'custom', child: Text('من تاريخ إلى تاريخ')),
              DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
            ],
            onChanged: (value) {
              setState(() => _mode = value ?? 'monthly');
            },
          ),
          if (_mode == 'custom') ...[
            const SizedBox(height: 8),
            _ChartsCustomDateRange(
              from: _from,
              to: _to,
              onPickFrom: () => _pickDate(isFrom: true),
              onPickTo: () => _pickDate(isFrom: false),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _ChartComparisonRow(
                    label: 'دخل',
                    value: income,
                    maxValue: maxValue,
                    color: const Color(0xFF16A34A),
                  ),
                  _ChartComparisonRow(
                    label: 'مصروف',
                    value: expense,
                    maxValue: maxValue,
                    color: const Color(0xFFDC2626),
                  ),
                  _ChartComparisonRow(
                    label: 'تحويل',
                    value: transfer,
                    maxValue: maxValue,
                    color: const Color(0xFF2563EB),
                  ),
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
                  const Text(
                    'ملخص المقارنة',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });
  }

  double _sumForType(List<TransactionEntity> transactions, String type) {
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  List<TransactionEntity> _filteredTransactions(List<TransactionEntity> source) {
    if (_mode == 'monthly') {
      return source
          .where(
            (transaction) =>
                transaction.createdAt.year == _selectedMonth.year &&
                transaction.createdAt.month == _selectedMonth.month,
          )
          .toList();
    }

    if (_mode == 'yearly') {
      return source
          .where((transaction) => transaction.createdAt.year == _selectedMonth.year)
          .toList();
    }

    if (_mode == 'custom' && _from != null && _to != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      return source
          .where(
            (transaction) =>
                !transaction.createdAt.isBefore(start) &&
                !transaction.createdAt.isAfter(end),
          )
          .toList();
    }

    return source;
  }
}

class _ChartsMonthSelector extends StatelessWidget {
  const _ChartsMonthSelector({
    required this.label,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String label;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPreviousMonth,
          icon: const Icon(Icons.chevron_right),
        ),
        Expanded(
          child: Center(child: Text(label)),
        ),
        IconButton(
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_left),
        ),
      ],
    );
  }
}

class _ChartsCustomDateRange extends StatelessWidget {
  const _ChartsCustomDateRange({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('من'),
          subtitle: Text(
            from == null ? 'اختر' : DateFormat('d/M/yyyy').format(from!),
          ),
          onTap: onPickFrom,
        ),
        ListTile(
          title: const Text('إلى'),
          subtitle: Text(
            to == null ? 'اختر' : DateFormat('d/M/yyyy').format(to!),
          ),
          onTap: onPickTo,
        ),
      ],
    );
  }
}

class _ChartComparisonRow extends StatelessWidget {
  const _ChartComparisonRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

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
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
