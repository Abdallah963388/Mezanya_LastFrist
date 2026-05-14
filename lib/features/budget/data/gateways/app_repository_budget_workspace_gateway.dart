import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../../domain/ports/budget_workspace_gateway.dart';

class AppRepositoryBudgetWorkspaceGateway implements BudgetWorkspaceGateway {
  AppRepositoryBudgetWorkspaceGateway(this._repository);

  final AppRepository _repository;

  @override
  Future<AppStateEntity> loadWorkspace() => _repository.loadState();
}
