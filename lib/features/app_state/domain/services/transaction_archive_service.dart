import '../../../transactions/domain/entities/transaction_entity.dart';

class ArchivedTransactionEntity {
  final TransactionEntity transaction;
  final DateTime archivedAt;
  final DateTime expiresAt;
  final String reason;

  const ArchivedTransactionEntity({
    required this.transaction,
    required this.archivedAt,
    required this.expiresAt,
    required this.reason,
  });
}

class TransactionArchiveService {
  static ArchivedTransactionEntity archive({
    required TransactionEntity transaction,
    required String reason,
    Duration retention = const Duration(days: 30),
  }) {
    final now = DateTime.now();

    return ArchivedTransactionEntity(
      transaction: transaction,
      archivedAt: now,
      expiresAt: now.add(retention),
      reason: reason,
    );
  }

  static bool isExpired(ArchivedTransactionEntity archivedTransaction) {
    return DateTime.now().isAfter(archivedTransaction.expiresAt);
  }
}
