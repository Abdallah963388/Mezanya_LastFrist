import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../app_cubit.dart';

extension AppCubitBudgetExtension on AppCubit {
  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
  }) async {
    await applyAndLog(
      action: 'edit',
      entityType: 'budget',
      entityId: 'budget-setup',
      details: detailsOverride ?? '?? ????? ??????? ?????????',
      apply: () async {
        final raw = await repository.updateBudgetSetup(setup);
        return withMonthlySnapshot(raw, setup);
      },
    );
  }

  Future<void> setCategories(List<CategoryEntity> categories) async {
    final next = state.copyWith(categories: categories);
    await applyAndLog(
      action: 'edit',
      entityType: 'category',
      entityId: 'categories',
      details: '?? ????? ??????',
      apply: () async => next,
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(allocations: allocations));
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final linkedWallets = state.budgetSetup.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(linkedWallets: linkedWallets));
  }
}
