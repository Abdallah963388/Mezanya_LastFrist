import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';

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
  static const Color primary = Color(0xFF2F6F5E);

  static const Color bg = Color(0xFFF6F7F5);

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

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
    setState(() {
      loading = true;
    });

    await _loadSettings();
    await _loadGoogle();

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        localFreq == BackupFrequency.onExit &&
        localPath != null) {
      _saveLocal(
        silent: true,
      );
    }
  }

  Future<void> _loadGoogle() async {
    _account = _googleSignIn.currentUser;

    _account ??= await _googleSignIn.signInSilently();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    localPath = prefs.getString(
      'backup_local_path',
    );

    final local = prefs.getString(
      'backup_local_freq',
    );

    final cloud = prefs.getString(
      'backup_cloud_freq',
    );

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

    await prefs.setString(
      'backup_local_path',
      localPath ?? '',
    );

    await prefs.setString(
      'backup_local_freq',
      localFreq.name,
    );

    await prefs.setString(
      'backup_cloud_freq',
      cloudFreq.name,
    );
  }

  bool _guardAuth() {
    if (_account == null) {
      _msg(
        'سجل دخول بجوجل أولًا',
      );
      return false;
    }

    return true;
  }

  void _msg(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  String label(
    BackupFrequency f,
  ) {
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
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      return true;
    }

    await openAppSettings();

    return false;
  }

  // ===================
  // LOCAL
  // ===================

  Future<void> _pickFolder() async {
    final ok = await _requestStoragePermission();

    if (!ok) return;

    final path = await FilePicker.getDirectoryPath();

    if (path == null) return;

    setState(() {
      localPath = path;
    });

    await _savePrefs();

    _msg(
      'تم حفظ مجلد النسخ',
    );
  }

  Future<void> _saveLocal({
    bool silent = false,
  }) async {
    if (localPath == null) {
      _msg(
        'حدد مكان الحفظ أولًا',
      );
      return;
    }

    final path = '$localPath${Platform.pathSeparator}mezanya_backup.json';

    final file = File(path);

    if (!await file.exists()) {
      await file.create(
        recursive: true,
      );
    }

    await file.writeAsString(
      widget.cubit.exportStateJson(),
      flush: true,
    );

    if (!silent) {
      _msg(
        'تم حفظ النسخة محليًا',
      );
    }
  }

  Future<void> _restoreLocal() async {
    final result = await FilePicker.pickFiles();

    if (result == null || result.files.single.path == null) {
      return;
    }

    final json = await File(
      result.files.single.path!,
    ).readAsString();

    await widget.cubit.importStateJson(json);

    _msg(
      'تم الاسترجاع المحلي',
    );
  }

  // ===================
  // FIREBASE
  // ===================

  Future<void> _backupFirestore() async {
    if (!_guardAuth()) return;

    try {
      setState(() {
        loading = true;
      });

      await FirebaseFirestore.instance
          .collection('backups')
          .doc(_account!.email)
          .set({
        'email': _account!.email,
        'name': _account!.displayName,
        'backup': widget.cubit.exportStateJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _msg(
        'تم رفع النسخة',
      );
    } catch (_) {
      _msg(
        'فشل رفع النسخة',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _restoreFirestore() async {
    if (!_guardAuth()) return;

    try {
      setState(() {
        loading = true;
      });

      final doc = await FirebaseFirestore.instance
          .collection('backups')
          .doc(
            _account!.email,
          )
          .get();

      if (!doc.exists || doc.data() == null) {
        _msg(
          'لا توجد نسخة',
        );
        return;
      }

      final json = doc.data()!['backup'];

      await widget.cubit.importStateJson(
        json.toString(),
      );

      _msg(
        'تم الاسترجاع',
      );
    } catch (_) {
      _msg(
        'فشل الاسترجاع',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.black,
        title: const Text(
          'النسخة الاحتياطية',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                title: 'النسخ المحلي',
                subtitle: 'حفظ واسترجاع على الجهاز',
                children: [
                  _infoTile(
                    icon: Icons.folder,
                    title: 'مكان الحفظ',
                    value: localPath ?? 'لم يتم الاختيار',
                    onTap: _pickFolder,
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  _frequencyDropdown(
                    localFreq,
                    (v) {
                      if (v == null) return;

                      setState(() {
                        localFreq = v;
                      });

                      _savePrefs();
                    },
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  _mainButton(
                    'حفظ الآن',
                    Icons.save,
                    () => _saveLocal(),
                  ),
                  _outlineButton(
                    'استرجاع نسخة',
                    Icons.restore,
                    _restoreLocal,
                  ),
                ],
              ),
              const SizedBox(
                height: 18,
              ),
              _section(
                title: 'Firebase Backup',
                subtitle: 'نسخ سحابي واسترجاع',
                children: [
                  _frequencyDropdown(
                    cloudFreq,
                    (v) {
                      if (v == null) return;

                      setState(() {
                        cloudFreq = v;
                      });

                      _savePrefs();
                    },
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  _mainButton(
                    'رفع الآن',
                    Icons.cloud_upload,
                    _backupFirestore,
                  ),
                  _outlineButton(
                    'استرجاع من Firebase',
                    Icons.cloud_download,
                    _restoreFirestore,
                  ),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
            ],
          ),
          if (loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 15,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(subtitle),
          const SizedBox(
            height: 18,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      tileColor: const Color(0xFFF4F6F4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(
        Icons.chevron_left,
      ),
    );
  }

  Widget _frequencyDropdown(
    BackupFrequency value,
    ValueChanged<BackupFrequency?> changed,
  ) {
    return DropdownButtonFormField<BackupFrequency>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'تكرار النسخ',
      ),
      items: BackupFrequency.values
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                label(e),
              ),
            ),
          )
          .toList(),
      onChanged: changed,
    );
  }

  Widget _mainButton(
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(
            54,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
        ),
        label: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _outlineButton(
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(
              54,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                18,
              ),
            ),
          ),
          icon: Icon(icon),
          label: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
