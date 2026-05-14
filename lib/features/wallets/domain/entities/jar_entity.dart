enum JarKind {
  normal,
  external,
  shared,
}

class JarContributorEntity {
  const JarContributorEntity({
    required this.contributorId,
    required this.displayName,
    required this.plannedAmount,
    this.paidAmount = 0,
  });

  final String contributorId;
  final String displayName;
  final double plannedAmount;
  final double paidAmount;
}

class JarEntity {
  const JarEntity({
    required this.id,
    required this.name,
    required this.kind,
    this.balance = 0,
    this.manualBalance = 0,
    this.contributors = const [],
    this.isTrackingOnly = false,
  });

  final String id;
  final String name;
  final JarKind kind;
  final double balance;
  final double manualBalance;
  final List<JarContributorEntity> contributors;
  final bool isTrackingOnly;
}

class NormalJarEntity extends JarEntity {
  const NormalJarEntity({
    required super.id,
    required super.name,
    super.balance,
    super.contributors,
  }) : super(kind: JarKind.normal);
}

class ExternalJarEntity extends JarEntity {
  const ExternalJarEntity({
    required super.id,
    required super.name,
    super.manualBalance,
    super.contributors,
  }) : super(
          kind: JarKind.external,
          isTrackingOnly: true,
        );
}

class SharedJarEntity extends JarEntity {
  const SharedJarEntity({
    required super.id,
    required super.name,
    super.balance,
    super.contributors,
  }) : super(kind: JarKind.shared);
}
