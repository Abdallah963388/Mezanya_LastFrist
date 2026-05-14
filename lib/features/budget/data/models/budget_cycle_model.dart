import '../../domain/entities/budget_cycle_entity.dart';

/// Persistence / API DTO for [BudgetCycleEntity] (projection fields only).
class BudgetCycleModel {
  const BudgetCycleModel({
    required this.cycleStartIso,
    required this.cycleEndIso,
    required this.isCurrent,
    required this.isPast,
    required this.isFuture,
    required this.cycleKey,
  });

  final String cycleStartIso;
  final String cycleEndIso;
  final bool isCurrent;
  final bool isPast;
  final bool isFuture;
  final String cycleKey;

  factory BudgetCycleModel.fromEntity(BudgetCycleEntity entity) {
    return BudgetCycleModel(
      cycleStartIso: entity.cycleStart.toIso8601String(),
      cycleEndIso: entity.cycleEnd.toIso8601String(),
      isCurrent: entity.isCurrent,
      isPast: entity.isPast,
      isFuture: entity.isFuture,
      cycleKey: entity.cycleKey,
    );
  }

  BudgetCycleEntity toEntity() {
    return BudgetCycleEntity(
      cycleStart: DateTime.parse(cycleStartIso),
      cycleEnd: DateTime.parse(cycleEndIso),
      isCurrent: isCurrent,
      isPast: isPast,
      isFuture: isFuture,
      cycleKey: cycleKey,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cycleStart': cycleStartIso,
        'cycleEnd': cycleEndIso,
        'isCurrent': isCurrent,
        'isPast': isPast,
        'isFuture': isFuture,
        'cycleKey': cycleKey,
      };

  factory BudgetCycleModel.fromJson(Map<String, dynamic> json) {
    return BudgetCycleModel(
      cycleStartIso: json['cycleStart'] as String? ?? '',
      cycleEndIso: json['cycleEnd'] as String? ?? '',
      isCurrent: json['isCurrent'] as bool? ?? false,
      isPast: json['isPast'] as bool? ?? false,
      isFuture: json['isFuture'] as bool? ?? false,
      cycleKey: json['cycleKey'] as String? ?? '',
    );
  }
}
