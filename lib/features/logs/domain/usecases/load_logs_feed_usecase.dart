import '../../../app_state/domain/repositories/app_repository.dart';
import '../entities/log_entry_entity.dart';
import '../../../notifications/domain/entities/notification_entity.dart';

class LogsFeedSnapshot {
  const LogsFeedSnapshot({
    required this.logs,
    required this.notifications,
  });

  final List<LogEntryEntity> logs;
  final List<NotificationEntity> notifications;
}

class LoadLogsFeedUseCase {
  LoadLogsFeedUseCase(this._appRepository);

  final AppRepository _appRepository;

  Future<LogsFeedSnapshot> call() async {
    final appState = await _appRepository.loadState();
    return LogsFeedSnapshot(
      logs: appState.logs,
      notifications: appState.notifications,
    );
  }
}
