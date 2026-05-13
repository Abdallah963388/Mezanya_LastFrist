import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../notifications/domain/entities/notification_entity.dart';

class AppStateAuditResult {
  final LogEntryEntity log;
  final NotificationEntity notification;

  const AppStateAuditResult({
    required this.log,
    required this.notification,
  });
}

class AppStateAuditService {
  static AppStateAuditResult createAudit({
    required String logId,
    required String notificationId,
    required String action,
    required String entityType,
    required String entityId,
    required String details,
    required String beforeState,
    required String afterState,
    required DateTime timestamp,
    String? titleOverride,
  }) {
    final title = titleOverride ??
        notificationTitle(
          action: action,
          entityType: entityType,
        );

    final log = LogEntryEntity(
      id: logId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: timestamp,
      beforeState: beforeState,
      afterState: afterState,
      isReverted: false,
    );

    final notification = NotificationEntity(
      id: notificationId,
      title: title,
      message: details,
      createdAt: timestamp,
      type: entityType,
      relatedLogId: log.id,
    );

    return AppStateAuditResult(
      log: log,
      notification: notification,
    );
  }

  static String notificationTitle({
    required String action,
    required String entityType,
  }) {
    if (entityType == 'income' || entityType == 'transaction') {
      return 'إشعار معاملة';
    }

    if (entityType == 'budget') {
      return 'إشعار الميزانية';
    }

    if (entityType == 'recurring-transaction') {
      return 'إشعار معاملة متكررة';
    }

    if (entityType == 'goal') {
      return 'إشعار هدف';
    }

    if (action == 'delete') {
      return 'إشعار حذف';
    }

    return 'إشعار جديد';
  }
}
