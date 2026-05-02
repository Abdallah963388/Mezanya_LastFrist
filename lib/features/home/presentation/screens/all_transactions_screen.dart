import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../widgets/money_overview_widgets.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({
    super.key,
    required this.cubit,
    required this.allTransactions,
    required this.initialMonth,
  });

  final AppCubit cubit;
  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _selectedTab = 'all';
  String _selectedRange = 'month';
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
    final filteredTransactions = _filterTransactions(widget.allTransactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('كل المعاملات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _TransactionTypeFilterBar(
            selectedTab: _selectedTab,
            onSelected: (value) => setState(() => _selectedTab = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRange,
            decoration: const InputDecoration(labelText: 'فلتر التاريخ'),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('آخر يوم')),
              DropdownMenuItem(value: 'week', child: Text('آخر أسبوع')),
              DropdownMenuItem(value: 'month', child: Text('آخر شهر')),
              DropdownMenuItem(
                value: 'specific-month',
                child: Text('شهر معين'),
              ),
              DropdownMenuItem(
                value: 'custom',
                child: Text('من تاريخ إلى تاريخ'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedRange = value ?? 'month');
            },
          ),
          if (_selectedRange == 'specific-month') ...[
            const SizedBox(height: 8),
            MoneyMonthSelectorCard(
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
          ],
          if (_selectedRange == 'custom') ...[
            const SizedBox(height: 8),
            _CustomDateRangePicker(
              from: _from,
              to: _to,
              onPickFrom: () => _pickDate(isFrom: true),
              onPickTo: () => _pickDate(isFrom: false),
            ),
          ],
          const SizedBox(height: 10),
          if (filteredTransactions.isEmpty)
            const Card(
              child: ListTile(title: Text('لا توجد معاملات مطابقة.')),
            )
          else
            ...filteredTransactions.map(_buildTransactionCard),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionEntity transaction) {
    return Card(
      child: MoneyTransactionTile(
        transaction: transaction,
        title: transaction.notes?.isNotEmpty == true
            ? transaction.notes!
            : _transactionTypeLabel(transaction.type),
        subtitle: DateFormat('d/M/yyyy - HH:mm').format(transaction.createdAt),
        onTap: () => openTransactionDetailsSheet(
          context,
          cubit: widget.cubit,
          transaction: transaction,
        ),
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

  List<TransactionEntity> _filterTransactions(List<TransactionEntity> source) {
    final now = DateTime.now();
    var output = source
        .where((transaction) => !_isJarReserveTx(transaction))
        .toList();

    if (_selectedTab != 'all') {
      output = output
          .where((transaction) => transaction.type == _selectedTab)
          .toList();
    }

    if (_selectedRange == 'day') {
      output = output
          .where((transaction) => now.difference(transaction.createdAt).inHours <= 24)
          .toList();
    } else if (_selectedRange == 'week') {
      output = output
          .where((transaction) => now.difference(transaction.createdAt).inDays <= 7)
          .toList();
    } else if (_selectedRange == 'month') {
      output = output
          .where((transaction) => now.difference(transaction.createdAt).inDays <= 30)
          .toList();
    } else if (_selectedRange == 'specific-month') {
      output = output
          .where(
            (transaction) =>
                transaction.createdAt.year == _selectedMonth.year &&
                transaction.createdAt.month == _selectedMonth.month,
          )
          .toList();
    } else if (_selectedRange == 'custom' && _from != null && _to != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      output = output
          .where(
            (transaction) =>
                !transaction.createdAt.isBefore(start) &&
                !transaction.createdAt.isAfter(end),
          )
          .toList();
    }

    return output;
  }

  String _transactionTypeLabel(String type) {
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

class _TransactionTypeFilterBar extends StatelessWidget {
  const _TransactionTypeFilterBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final String selectedTab;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = const [
      ('all', 'عام'),
      ('income', 'دخل'),
      ('expense', 'مصروف'),
      ('transfer', 'تحويل'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(option.$2),
              selected: selectedTab == option.$1,
              onSelected: (_) => onSelected(option.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CustomDateRangePicker extends StatelessWidget {
  const _CustomDateRangePicker({
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
    return Row(
      children: [
        Expanded(
          child: ListTile(
            title: const Text('من تاريخ'),
            subtitle: Text(
              from == null ? 'اختر' : DateFormat('d/M/yyyy').format(from!),
            ),
            onTap: onPickFrom,
          ),
        ),
        Expanded(
          child: ListTile(
            title: const Text('إلى تاريخ'),
            subtitle: Text(
              to == null ? 'اختر' : DateFormat('d/M/yyyy').format(to!),
            ),
            onTap: onPickTo,
          ),
        ),
      ],
    );
  }
}
