import '../../../app_state/domain/entities/app_state_entity.dart';

abstract class BudgetWorkspaceGateway {
  Future<AppStateEntity> loadWorkspace();
}
