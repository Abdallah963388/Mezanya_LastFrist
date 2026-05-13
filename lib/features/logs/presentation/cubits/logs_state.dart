import '../../../notifications/domain/entities/notification_entity.dart';
import '../../domain/entities/log_entry_entity.dart';

class LogsState {
  const LogsState({
    this.logs = const [],
    this.notifications = const [],
    this.isLoading = false,
  });

  final List<LogEntryEntity> logs;
  final List<NotificationEntity> notifications;
  final bool isLoading;

  bool get hasLogs => logs.isNotEmpty;

  int get logCount => logs.length;

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  LogsState copyWith({
    List<LogEntryEntity>? logs,
    List<NotificationEntity>? notifications,
    bool? isLoading,
  }) {
    return LogsState(
      logs: logs ?? this.logs,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
