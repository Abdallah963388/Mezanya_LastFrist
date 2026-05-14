enum SpaceMemberRole {
  owner,
  editor,
  viewer,
}

class SpaceMemberEntity {
  const SpaceMemberEntity({
    required this.memberId,
    required this.displayName,
    required this.role,
  });

  final String memberId;
  final String displayName;
  final SpaceMemberRole role;
}

class SpaceContributionEntity {
  const SpaceContributionEntity({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String memberId;
  final double amount;
  final DateTime createdAt;
  final String? notes;
}

class SpaceTransactionMetadata {
  const SpaceTransactionMetadata({
    required this.paidBy,
    this.visibleTo = const [],
    this.affectsWho = const [],
  });

  final String paidBy;
  final List<String> visibleTo;
  final List<String> affectsWho;
}

class SpaceEntity {
  const SpaceEntity({
    required this.id,
    required this.name,
    this.members = const [],
    this.contributions = const [],
    this.visibility = 'private',
    this.permissions = const {},
  });

  final String id;
  final String name;
  final List<SpaceMemberEntity> members;
  final List<SpaceContributionEntity> contributions;
  final String visibility;
  final Map<String, dynamic> permissions;
}
