import 'transaction_entity.dart';

enum FinancialTargetEntityType {
  allocation,
  jar,
  goal,
  space,
  sharedWallet,
}

class FinancialTransactionImpact {
  const FinancialTransactionImpact({
    required this.amount,
    required this.direction,
    this.walletId,
    this.targetEntityId,
    this.targetEntityType,
    this.metadata = const {},
  });

  final double amount;
  final String direction;
  final String? walletId;
  final String? targetEntityId;
  final FinancialTargetEntityType? targetEntityType;
  final Map<String, dynamic> metadata;
}

class FinancialTransactionContributor {
  const FinancialTransactionContributor({
    required this.contributorId,
    required this.displayName,
    required this.amount,
    this.role = 'contributor',
  });

  final String contributorId;
  final String displayName;
  final double amount;
  final String role;
}

class FinancialTransactionEntity {
  const FinancialTransactionEntity({
    required this.id,
    required this.createdAt,
    this.sourceWallet,
    this.physicalImpact,
    this.organizationalImpact,
    this.targetEntity,
    this.entityType,
    this.contributors = const [],
    this.isPhysical = true,
    this.isOrganizational = false,
    this.legacyTransaction,
  });

  final String id;
  final DateTime createdAt;
  final String? sourceWallet;
  final FinancialTransactionImpact? physicalImpact;
  final FinancialTransactionImpact? organizationalImpact;
  final String? targetEntity;
  final FinancialTargetEntityType? entityType;
  final List<FinancialTransactionContributor> contributors;
  final bool isPhysical;
  final bool isOrganizational;
  final TransactionEntity? legacyTransaction;
}
