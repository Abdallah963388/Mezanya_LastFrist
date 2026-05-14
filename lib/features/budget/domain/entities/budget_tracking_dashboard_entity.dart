import 'budget_cycle_entity.dart';
import 'budget_money_totals_entity.dart';
import 'budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class BudgetTrackingDashboardEntity {
  const BudgetTrackingDashboardEntity({
    required this.cycle,
    required this.cycleTransactions,
    required this.moneyTotals,
    required this.trackingJars,
  });

  final BudgetCycleEntity cycle;
  final List<TransactionEntity> cycleTransactions;
  final BudgetMoneyTotalsEntity moneyTotals;
  final List<LinkedWalletEntity> trackingJars;
}
