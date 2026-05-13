import 'dart:convert';

import '../../../../logs/domain/entities/log_entry_entity.dart';
import '../../../../notifications/domain/entities/notification_entity.dart';
import '../app_cubit.dart';

extension AppCubitLogsExtension on AppCubit {
  Future<void> toggleLogRevert(String logId) async {
    final target = state.logs.where((log) => log.id == logId).toList();
    if (target.isEmpty) return;
    final log = target.first;

    final updatedLogs = state.logs
        .map((item) => item.id == logId
            ? item.copyWith(
                isReverted: !item.isReverted,
                revertedAt: item.isReverted ? null : DateTime.now(),
              )
            : item)
        .toList();

    final restored = restoreStateFromCore(
      log.isReverted ? log.afterState : log.beforeState,
      updatedLogs,
    );
    final revertLog = LogEntryEntity(
      id: generateId('log'),
      action: 'revert',
      entityType: log.entityType,
      entityId: log.entityId,
      details: log.isReverted
          ? '?? ??????? ?? ???????'
          : '?? ??????? ?? ??????? ???????',
      timestamp: DateTime.now(),
      beforeState: jsonEncode(coreStateMap(state.copyWith(logs: updatedLogs))),
      afterState: jsonEncode(coreStateMap(restored)),
      isReverted: false,
    );
    final revertNotification = NotificationEntity(
      id: generateId('notif'),
      title: '????? ?????',
      message: revertLog.details,
      createdAt: DateTime.now(),
      type: 'revert-system',
      relatedLogId: revertLog.id,
    );
    final next = restored.copyWith(
      logs: [revertLog, ...updatedLogs].take(600).toList(),
      notifications:
          [revertNotification, ...state.notifications].take(800).toList(),
    );
    await repository.saveState(next);
    emitState(next);
  }
}

