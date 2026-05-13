import '../../../budget/domain/entities/budget_setup_entity.dart';

class SpacesState {
  const SpacesState({
    this.savingsSpaces = const [],
    this.allocationSpaces = const [],
    this.isLoading = false,
  });

  final List<LinkedWalletEntity> savingsSpaces;
  final List<AllocationEntity> allocationSpaces;
  final bool isLoading;

  bool get hasSavingsSpaces => savingsSpaces.isNotEmpty;

  bool get hasAllocationSpaces => allocationSpaces.isNotEmpty;

  int get savingsSpaceCount => savingsSpaces.length;

  int get allocationSpaceCount => allocationSpaces.length;

  double get totalSavingsSpaceBalance =>
      savingsSpaces.fold(0, (sum, space) => sum + space.balance);

  double get totalAllocationSpaceBalance =>
      allocationSpaces.fold(0, (sum, space) => sum + space.balance);

  SpacesState copyWith({
    List<LinkedWalletEntity>? savingsSpaces,
    List<AllocationEntity>? allocationSpaces,
    bool? isLoading,
  }) {
    return SpacesState(
      savingsSpaces: savingsSpaces ?? this.savingsSpaces,
      allocationSpaces: allocationSpaces ?? this.allocationSpaces,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
