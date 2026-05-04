import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../../features/backup/backup_service.dart';
import '../../../../features/backup/backup_conflict_dialog.dart';

class BackupSettingsScreen extends StatefulWidget {
  final AppCubit cubit;

  const BackupSettingsScreen({
    super.key,
    required this.cubit,
  });

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

enum BackupFrequency {
  onExit,
  daily,
  weekly,
  monthly,
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with WidgetsBindingObserver {
  static const Color _green = Color(0xFF2F6F5E);
  static const Color _bg = Color(0xFFFFFBF1);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  GoogleSignInAccount? _account;
  bool loading = false;
  String? localPath;
  BackupFrequency localFreq = BackupFrequency.onExit;
  BackupFrequency cloudFreq = BackupFrequency.weekly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => loading = true);
    await _loadSettings();
    await _loadGoogle();
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        localFreq == BackupFrequency.onExit &&
        localPath != null) {
      _saveLocal(silent: true);
    }
  }

  Future<void> _loadGoogle() async {
    _account = _googleSignIn.currentUser;
    _account ??= await _googleSignIn.signInSilently();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    localPath = prefs.getString('backup_local_path');
    final local = prefs.getString('backup_local_freq');
    final cloud = prefs.getString('backup_cloud_freq');
    if (local != null) {
      localFreq = BackupFrequency.values.firstWhere(
        (e) => e.name == local,
        orElse: () => BackupFrequency.onExit,
      );
    }
    if (cloud != null) {
      cloudFreq = BackupFrequency.values.firstWhere(
        (e) => e.name == cloud,
        orElse: () => BackupFrequency.weekly,
      );
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_local_path', localPath ?? '');
    await prefs.setString('backup_local_freq', localFreq.name);
    await prefs.setString('backup_cloud_freq', cloudFreq.name);
  }

  bool _guardAuth() {
    if (_account == null) {
      _msg('سجل دخول بجوجل أولًا');
      return false;
    }
    return true;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String _freqLabel(BackupFrequency f) {
    switch (f) {
      case BackupFrequency.onExit:
        return 'مع غلق التطبيق';
      case BackupFrequency.daily:
        return 'يوميًا 12 صباحًا';
      case BackupFrequency.weekly:
        return 'كل جمعة 12 صباحًا';
      case BackupFrequency.monthly:
        return '1 من كل شهر';
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<void> _pickFolder() async {
    final ok = await _requestStoragePermission();
    if (!ok) return;
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    setState(() => localPath = path);
    await _savePrefs();
    _msg('تم حفظ مجلد النسخ');
  }

  Future<void> _saveLocal({bool silent = false}) async {
    if (localPath == null) {
      _msg('حدد مكان الحفظ أولًا');
      return;
    }
    final path = '$localPath${Platform.pathSeparator}mezanya_backup.json';
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(widget.cubit.exportStateJson(), flush: true);
    if (!silent) _msg('تم حفظ النسخة محليًا');
  }

  Future<void> _restoreLocal() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final json = await File(result.files.single.path!).readAsString();
    await widget.cubit.importStateJson(json);
    _msg('تم الاسترجاع المحلي');
  }

  Future<void> _backupFirestore() async {
    if (!_guardAuth()) return;

    final appState = widget.cubit.state;

    // لا نرفع نسخة فارغة أبداً
    if (appState.isEmpty) {
      _msg('لا توجد بيانات للرفع بعد');
      return;
    }

    try {
      setState(() => loading = true);

      final email = _account!.email!;
      final existingMeta = await BackupService.fetchMetadata(email);

      if (existingMeta != null) {
        // يوجد نسخة قديمة — نسأل المستخدم
        if (!mounted) return;
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
          // نجلب البيانات الكاملة ونعمل merge
          final remoteJson = await BackupService.fetchData(email);
          if (remoteJson != null) {
            await widget.cubit.mergeStateJson(remoteJson);
          }
        }
        // في حالة overwrite أو بعد merge — نرفع الحالة الحالية
      }

      final currentState = widget.cubit.state;
      await BackupService.upload(
        email: email,
        displayName: _account!.displayName ?? '',
        jsonData: widget.cubit.exportStateJson(),
        txCount: currentState.transactions.length,
        walletCount: currentState.wallets.length,
        recurringCount: currentState.recurringTransactions.length,
      );

      // نحفظ وقت آخر رفع محلياً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_cloud_backup_at', DateTime.now().toIso8601String());

      _msg('تم رفع النسخة بنجاح ✓');
    } catch (e) {
      _msg('فشل رفع النسخة');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _restoreFirestore() async {
    if (!_guardAuth()) return;
    try {
      setState(() => loading = true);
      final json = await BackupService.fetchData(_account!.email!);
      if (json == null) {
        _msg('لا توجد نسخة محفوظة');
        return;
      }
      await widget.cubit.importStateJson(json);
      _msg('تم الاسترجاع بنجاح ✓');
    } catch (_) {
      _msg('فشل الاسترجاع');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: const Color(0xFF1C3A32),
        title: const Text(
          'النسخة الاحتياطية',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              // ── النسخ المحلي ────────────────────────────────
              _sectionHeader('النسخ المحلي', Icons.phone_android_rounded),
              _BackupCard(
                children: [
                  // مكان الحفظ
                  _pathTile(
                    icon: Icons.folder_rounded,
                    label: 'مكان الحفظ',
                    value: localPath ?? 'لم يتم الاختيار',
                    onTap: _pickFolder,
                  ),
                  const SizedBox(height: 14),
                  // تكرار النسخ
                  _FrequencySelector(
                    label: 'تكرار النسخ المحلي',
                    value: localFreq,
                    options: BackupFrequency.values,
                    labelOf: _freqLabel,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => localFreq = v);
                      _savePrefs();
                    },
                  ),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: 'حفظ الآن',
                    icon: Icons.save_rounded,
                    onTap: () => _saveLocal(),
                  ),
                  const SizedBox(height: 8),
                  _SecondaryButton(
                    label: 'استرجاع نسخة محلية',
                    icon: Icons.restore_rounded,
                    onTap: _restoreLocal,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── النسخ السحابي ────────────────────────────────
              _sectionHeader(
                  'النسخ السحابي', Icons.cloud_rounded),
              if (_account != null)
                _googleAccountBadge()
              else
                _googleNotConnectedBadge(),
              const SizedBox(height: 10),
              _BackupCard(
                children: [
                  _FrequencySelector(
                    label: 'تكرار النسخ السحابي',
                    value: cloudFreq,
                    options: BackupFrequency.values,
                    labelOf: _freqLabel,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => cloudFreq = v);
                      _savePrefs();
                    },
                  ),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: 'رفع نسخة الآن',
                    icon: Icons.cloud_upload_rounded,
                    onTap: _backupFirestore,
                  ),
                  const SizedBox(height: 8),
                  _SecondaryButton(
                    label: 'استرجاع من السحابة',
                    icon: Icons.cloud_download_rounded,
                    onTap: _restoreFirestore,
                  ),
                ],
              ),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _green),
                      SizedBox(height: 14),
                      Text(
                        'جارٍ التحميل...',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: _green),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C3A32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1C3A32),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _green.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                color: _green.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _googleAccountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.07),
                ),
              ],
            ),
            child: const Center(
              child: Text('G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Arial',
                    color: Color(0xFF4285F4),
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'متصل بجوجل',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _green,
                  ),
                ),
                Text(
                  _account?.email ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: _green.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
                SizedBox(width: 4),
                Text(
                  'متصل',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleNotConnectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: Color(0xFFF57C00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'سجّل دخولك بجوجل من إعدادات الحساب أولاً لتفعيل النسخ السحابي',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF57C00).withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF2F6F5E).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 5),
            color: const Color(0xFF2F6F5E).withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FrequencySelector<T> extends StatelessWidget {
  const _FrequencySelector({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _green.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withValues(alpha: 0.18)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.expand_more_rounded,
                  color: _green.withValues(alpha: 0.7)),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C3A32),
              ),
              items: options
                  .map((e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(labelOf(e)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2F6F5E),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2F6F5E),
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: const BorderSide(
            color: Color(0xFF2F6F5E),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
