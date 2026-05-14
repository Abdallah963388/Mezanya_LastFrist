class BudgetMoneyTotalsEntity {
  const BudgetMoneyTotalsEntity({
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
  });

  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;
}
