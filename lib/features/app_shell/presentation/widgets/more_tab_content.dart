import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../budget/presentation/screens/budget_setup_screen.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../logs/presentation/screens/logs_screen.dart';
import '../../../notifications/presentation/screens/notifications_center_screen.dart';
import '../../../transactions/presentation/screens/recurring_transactions_screen.dart';
import 'package:mezanya_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:mezanya_app/features/settings/presentation/screens/backup_settings_screen.dart';
import 'package:mezanya_app/features/backup/backup_service.dart';
import 'package:mezanya_app/features/backup/backup_conflict_dialog.dart';
import 'section_page_scaffold.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/presentation/screens/debts_and_subscriptions_screen.dart';

class MoreTabContent extends StatefulWidget {
  final AppCubit cubit;

  const MoreTabContent({
    super.key,
    required this.cubit,
  });

  @override
  State<MoreTabContent> createState() => _MoreTabContentState();
}

class _MoreTabContentState extends State<MoreTabContent> {
  static const _green = Color(0xFF2F6F5E);

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  GoogleSignInAccount? user;
  String? _lastBackupAt;
  bool _backupLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLastBackupTime();
  }

  Future<void> _loadUser() async {
    final signedUser =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (!mounted) return;
    setState(() => user = signedUser);
  }

  Future<void> _loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('last_cloud_backup_at');
    if (!mounted) return;
    setState(() => _lastBackupAt = val);
  }

  String _formatBackupTime(String? iso) {
    if (iso == null) return 'لم يتم النسخ بعد';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'لم يتم النسخ بعد';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _quickUpload() async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجل دخول بجوجل أولاً من الإعدادات')),
      );
      return;
    }

    final appState = widget.cubit.state;

    if (appState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للرفع بعد')),
      );
      return;
    }

    setState(() => _backupLoading = true);

    try {
      final email = user!.email!;
      final existingMeta = await BackupService.fetchMetadata(email);

      if (existingMeta != null && mounted) {
        final remoteTx =
            (existingMeta['recordsCount']?['transactions'] as int?) ?? 0;
        final remoteUpdatedAt = existingMeta['updatedAt'] is Timestamp
            ? (existingMeta['updatedAt'] as Timestamp).toDate()
            : null;

        final choice = await BackupConflictDialog.show(
          context,
          remoteTxCount: remoteTx,
          localTxCount: appState.transactions.length,
          remoteUpdatedAt: remoteUpdatedAt,
        );

        if (choice == BackupConflictChoice.cancel) return;

        if (choice == BackupConflictChoice.merge) {
          final remoteJson = await BackupService.fetchData(email);
          if (remoteJson != null) {
            await widget.cubit.mergeStateJson(remoteJson);
          }
        }
      }

      final currentState = widget.cubit.state;
      await BackupService.upload(
        email: email,
        displayName: user!.displayName ?? '',
        jsonData: widget.cubit.exportStateJson(),
        txCount: currentState.transactions.length,
        walletCount: currentState.wallets.length,
        recurringCount: currentState.recurringTransactions.length,
      );

      final now = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_cloud_backup_at', now);

      if (!mounted) return;
      setState(() => _lastBackupAt = now);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع النسخة بنجاح ✓')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل رفع النسخة')),
      );
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }
  }

  void _openBackupSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackupSettingsScreen(cubit: widget.cubit),
      ),
    ).then((_) => _loadLastBackupTime());
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;

    final customName = state.userName.trim();
    final googleName = user?.displayName ?? '';
    final name = customName.isNotEmpty
        ? customName
        : (googleName.isNotEmpty ? googleName : 'مستخدم ميزانية');
    final email = user?.email ?? state.googleEmail.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── بطاقة المستخدم ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF2F6F5E), Color(0xFF3C8973)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16,
                offset: Offset(0, 6),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white24,
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? Text(
                        name[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 15, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email.isEmpty
                                ? 'غير متصل بحساب Google'
                                : email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white),
              ),
            ],
          ),
        ),

        // ── شريط حالة الباك آب ─────────────────────────────────────
        _BackupStatusBar(
          lastBackupLabel: _formatBackupTime(_lastBackupAt),
          txCount: state.transactions.length,
          isLoggedIn: user != null,
          isLoading: _backupLoading,
          onUpload: _quickUpload,
          onManage: _openBackupSettings,
        ),

        const SizedBox(height: 14),

        // ── القوائم ────────────────────────────────────────────────
        _tile('إعداد الميزانية', Icons.tune_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعداد الميزانية',
                child: BudgetSetupScreen(
                  cubit: widget.cubit,
                  displayMonth: DateTime.now(),
                ),
              ),
            ),
          );
        }),

        _tile('الديون والاشتراكات', Icons.account_balance_wallet_rounded,
            onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtsAndSubscriptionsScreen(cubit: widget.cubit),
            ),
          );
        }),

        _tile('العمليات المتكررة', Icons.repeat_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'العمليات المتكررة',
                child: RecurringTransactionsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('إعداد الفئات', Icons.grid_view_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعداد الفئات',
                child: CategoriesScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('الأهداف', Icons.flag_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'الأهداف',
                child: GoalsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('السجلات', Icons.receipt_long_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LogsScreen(cubit: widget.cubit),
            ),
          );
        }),

        _tile('الإشعارات', Icons.notifications_none, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'الإشعارات',
                child: NotificationsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        _tile('إعدادات التطبيق', Icons.settings_rounded, onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionPageScaffold(
                title: 'إعدادات التطبيق',
                child: AppSettingsScreen(cubit: widget.cubit),
              ),
            ),
          );
        }),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _tile(String title, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x112F6F5E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _green),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_left),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backup Status Bar Widget
// ─────────────────────────────────────────────────────────────────────────────

class _BackupStatusBar extends StatelessWidget {
  const _BackupStatusBar({
    required this.lastBackupLabel,
    required this.txCount,
    required this.isLoggedIn,
    required this.isLoading,
    required this.onUpload,
    required this.onManage,
  });

  final String lastBackupLabel;
  final int txCount;
  final bool isLoggedIn;
  final bool isLoading;
  final VoidCallback onUpload;
  final VoidCallback onManage;

  static const _green = Color(0xFF2F6F5E);
  static const _orange = Color(0xFFC65D2E);

  @override
  Widget build(BuildContext context) {
    final hasBackup = lastBackupLabel != 'لم يتم النسخ بعد';
    final statusColor = isLoggedIn
        ? (hasBackup ? _green : _orange)
        : const Color(0xFF888888);
    final statusIcon = isLoggedIn
        ? (hasBackup ? Icons.cloud_done_rounded : Icons.cloud_off_rounded)
        : Icons.cloud_off_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف الأول — الحالة + زر رفع
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'النسخة الاحتياطية',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      isLoggedIn ? lastBackupLabel : 'سجل دخول لتفعيل النسخ السحابي',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              // زر رفع سريع
              if (isLoggedIn)
                isLoading
                    ? SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _green,
                        ),
                      )
                    : GestureDetector(
                        onTap: onUpload,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
            ],
          ),

          // الفاصل
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: statusColor.withValues(alpha: 0.15),
            ),
          ),

          // الصف الثاني — تفاصيل + رابط الإدارة
          Row(
            children: [
              _chip(
                icon: Icons.receipt_rounded,
                label: '$txCount معاملة',
                color: statusColor,
              ),
              const SizedBox(width: 8),
              if (isLoggedIn && hasBackup)
                _chip(
                  icon: Icons.check_circle_rounded,
                  label: 'محفوظة',
                  color: _green,
                ),
              if (!isLoggedIn || !hasBackup)
                _chip(
                  icon: Icons.warning_amber_rounded,
                  label: isLoggedIn ? 'لا يوجد نسخة' : 'غير مسجل',
                  color: _orange,
                ),
              const Spacer(),
              GestureDetector(
                onTap: onManage,
                child: Row(
                  children: [
                    Text(
                      'إدارة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
