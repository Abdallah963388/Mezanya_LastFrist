class TransactionTargetResolution {
  const TransactionTargetResolution({
    required this.allocationId,
    required this.jarId,
    required this.isWithinBudget,
  });

  final String? allocationId;
  final String? jarId;
  final bool isWithinBudget;
}

class TransactionTargetResolverService {
  const TransactionTargetResolverService._();

  static TransactionTargetResolution resolveExpenseTarget(
    String budgetTargetId,
  ) {
    if (budgetTargetId.startsWith('alloc:')) {
      return TransactionTargetResolution(
        allocationId: budgetTargetId.replaceFirst('alloc:', ''),
        jarId: null,
        isWithinBudget: true,
      );
    }

    if (budgetTargetId.startsWith('jar:')) {
      return TransactionTargetResolution(
        allocationId: null,
        jarId: budgetTargetId.replaceFirst('jar:', ''),
        isWithinBudget: true,
      );
    }

    return const TransactionTargetResolution(
      allocationId: null,
      jarId: null,
      isWithinBudget: false,
    );
  }
}
