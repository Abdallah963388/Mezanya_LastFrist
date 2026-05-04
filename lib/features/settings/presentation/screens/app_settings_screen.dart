// ignore_for_file: use_build_context_synchronously
import 'dart:developer';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/backup/backup_service.dart';
import 'package:mezanya_app/features/backup/restore_prompt_dialog.dart';
import 'backup_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.cubit,
  });

  final AppCubit cubit;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late TextEditingController _nameController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const _bg = Color(0xFFFFFBF1);
  static const _green = Color(0xFF2F6F5E);
  static const _surface = Color(0xFFFFFFFF);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  GoogleSignInAccount? _account;

  User? _emailUser;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.cubit.state.userName,
    );
    _initGoogle();
    _emailUser = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _emailUser = u);
    });
  }

  Future<void> _initGoogle() async {
    final cached = _googleSignIn.currentUser;
    if (cached != null) {
      _account = cached;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = cached.displayName ?? '';
      }
      if (mounted) setState(() {});
      return;
    }
    final acc = await _googleSignIn.signInSilently();
    if (!mounted) return;
    if (acc != null) {
      _account = acc;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = acc.displayName ?? '';
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfileImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final Uint8List bytes = result.files.single.bytes!;
    final ext = result.files.single.extension ?? 'jpg';
    setState(() => _uploadingImage = true);
    try {
      final uid = _emailUser?.uid ??
          _account?.id ??
          widget.cubit.state.userName.hashCode.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images/$uid.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      await widget.cubit.updateSettings(profileImageUrl: url);
    } catch (e) {
      log('Image upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snap) {
        final state = snap.data ?? widget.cubit.state;
        final displayName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (_account?.displayName ?? 'مستخدم');
        final initials = displayName.isNotEmpty ? displayName[0] : 'م';
        final isGoogleConnected = _account != null;
        final isEmailConnected = _emailUser != null;

        return Scaffold(
          backgroundColor: _bg,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              const SizedBox(height: 8),

              // ── الملف الشخصي ─────────────────────────────────
              _SectionHeader(
                  label: 'الملف الشخصي', icon: Icons.person_rounded),
              _ProfileCard(
                profileImageUrl: state.profileImageUrl,
                googlePhotoUrl: _account?.photoUrl,
                initials: initials,
                nameController: _nameController,
                isGoogleConnected: isGoogleConnected,
                isEmailConnected: isEmailConnected,
                emailUser: _emailUser,
                googleAccount: _account,
                uploadingImage: _uploadingImage,
                onPickImage: _pickAndUploadProfileImage,
                onNameChanged: (v) =>
                    widget.cubit.updateSettings(userName: v),
              ),

              const SizedBox(height: 20),

              // ── ربط الحساب ────────────────────────────────────
              _SectionHeader(
                  label: 'ربط الحساب', icon: Icons.link_rounded),
              _AccountLinkCard(
                googleAccount: _account,
                emailUser: _emailUser,
                emailController: _emailController,
                passwordController: _passwordController,
                onGoogleSignIn: _signInGoogle,
                onGoogleSignOut: _signOutGoogle,
                onEmailRegister: _registerEmail,
                onEmailSignIn: _signInEmail,
                onEmailSignOut: _signOutEmail,
              ),

              const SizedBox(height: 20),

              // ── البيانات ──────────────────────────────────────
              _SectionHeader(
                  label: 'البيانات', icon: Icons.storage_rounded),
              _ActionTile(
                icon: Icons.backup_rounded,
                iconColor: _green,
                title: 'إدارة النسخ الاحتياطي',
                subtitle: 'نسخ محلي و Firebase',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BackupSettingsScreen(cubit: widget.cubit),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.delete_sweep_rounded,
                iconColor: const Color(0xFFC65D2E),
                iconBgColor:
                    const Color(0xFFC65D2E).withValues(alpha: 0.1),
                title: 'مسح بيانات التطبيق',
                subtitle: 'إعادة ضبط كاملة لجميع البيانات',
                titleColor: const Color(0xFFC65D2E),
                onTap: _showWipeSheet,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signInGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      _nameController.text = account.displayName ?? '';
      widget.cubit.updateSettings(
        userName: _nameController.text,
        googleEmail: account.email,
      );
      setState(() => _account = account);

      // بعد تسجيل الدخول — نتحقق من وجود نسخة على السحابة
      await _checkAndPromptRestore(account.email);
    } catch (e) {
      log('$e');
    }
  }

  Future<void> _checkAndPromptRestore(String email) async {
    try {
      // نتحقق إذا سبق وسألنا المستخدم لهذا الحساب
      final prefs = await SharedPreferences.getInstance();
      final promptKey = 'restore_prompt_shown_$email';
      final alreadyShown = prefs.getBool(promptKey) ?? false;
      if (alreadyShown) return;

      // البيانات المحلية فارغة؟
      if (!widget.cubit.state.isEmpty) {
        await prefs.setBool(promptKey, true);
        return;
      }

      // جلب الـ metadata بكول خفيف
      final meta = await BackupService.fetchMetadata(email);
      if (meta == null) {
        await prefs.setBool(promptKey, true);
        return;
      }

      final txCount =
          (meta['recordsCount']?['transactions'] as int?) ?? 0;
      final walletCount =
          (meta['recordsCount']?['wallets'] as int?) ?? 0;
      final updatedAt = meta['updatedAt'] is Timestamp
          ? (meta['updatedAt'] as Timestamp).toDate()
          : null;

      if (!mounted) return;

      final restore = await RestorePromptDialog.show(
        context,
        txCount: txCount,
        walletCount: walletCount,
        updatedAt: updatedAt,
      );

      await prefs.setBool(promptKey, true);

      if (restore) {
        final json = await BackupService.fetchData(email);
        if (json != null) {
          await widget.cubit.importStateJson(json);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم استعادة بياناتك بنجاح ✓')),
            );
          }
        }
      }
    } catch (e) {
      log('restore check error: $e');
    }
  }

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();
    widget.cubit.updateSettings(googleEmail: '');
    setState(() => _account = null);
  }

  Future<void> _registerEmail() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل الإيميل وكلمة السر')),
      );
      return;
    }
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      widget.cubit.updateSettings(googleEmail: cred.user?.email ?? '');
      setState(() => _emailUser = cred.user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الحساب بنجاح')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authError(e.code))),
      );
    }
  }

  Future<void> _signInEmail() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل الإيميل وكلمة السر')),
      );
      return;
    }
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      widget.cubit.updateSettings(googleEmail: cred.user?.email ?? '');
      setState(() => _emailUser = cred.user);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authError(e.code))),
      );
    }
  }

  Future<void> _signOutEmail() async {
    await FirebaseAuth.instance.signOut();
    setState(() => _emailUser = null);
  }

  String _authError(String code) {
    return switch (code) {
      'email-already-in-use' => 'الإيميل مستخدم بالفعل',
      'invalid-email' => 'إيميل غير صحيح',
      'weak-password' => 'كلمة السر ضعيفة جدًا (6 أحرف على الأقل)',
      'user-not-found' => 'لا يوجد حساب بهذا الإيميل',
      'wrong-password' => 'كلمة السر غير صحيحة',
      'too-many-requests' => 'محاولات كثيرة، حاول لاحقًا',
      _ => 'حدث خطأ، حاول مرة أخرى',
    };
  }

  Future<void> _showWipeSheet() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        int count = 5;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future.doWhile(() async {
              if (count == 0) return false;
              await Future.delayed(const Duration(seconds: 1));
              count--;
              if (ctx.mounted) setSheet(() {});
              return count > 0;
            });

            return Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC65D2E).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 36, color: Color(0xFFC65D2E)),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تحذير',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'سيتم حذف جميع البيانات بشكل نهائي\nولا يمكن التراجع عن هذا الإجراء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: count > 0 ? null : _finalDeleteConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC65D2E),
                        disabledBackgroundColor:
                            const Color(0xFFC65D2E).withValues(alpha: 0.4),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        count > 0
                            ? 'انتظر $count ثواني...'
                            : 'متابعة الحذف',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finalDeleteConfirm() async {
    Navigator.pop(context);
    await Future.delayed(const Duration(seconds: 2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Text('تأكيد أخير'),
        content: const Text('هل أنت متأكد من حذف جميع البيانات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC65D2E),
            ),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.cubit.resetAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف جميع البيانات')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profileImageUrl,
    required this.googlePhotoUrl,
    required this.initials,
    required this.nameController,
    required this.isGoogleConnected,
    required this.isEmailConnected,
    required this.emailUser,
    required this.googleAccount,
    required this.uploadingImage,
    required this.onPickImage,
    required this.onNameChanged,
  });

  final String profileImageUrl;
  final String? googlePhotoUrl;
  final String initials;
  final TextEditingController nameController;
  final bool isGoogleConnected;
  final bool isEmailConnected;
  final User? emailUser;
  final GoogleSignInAccount? googleAccount;
  final bool uploadingImage;
  final VoidCallback onPickImage;
  final ValueChanged<String> onNameChanged;

  static const _green = Color(0xFF2F6F5E);

  String? get _effectivePhoto =>
      profileImageUrl.isNotEmpty ? profileImageUrl : googlePhotoUrl;

  String get _connectedEmail =>
      emailUser?.email ?? googleAccount?.email ?? '';

  bool get _anyConnected => isGoogleConnected || isEmailConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2F6F5E).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: const Color(0xFF2F6F5E).withValues(alpha: 0.07),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Avatar header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF2F6F5E), Color(0xFF1A4A3A)],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: uploadingImage
                          ? const CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : CircleAvatar(
                              radius: 42,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              backgroundImage: _effectivePhoto != null
                                  ? NetworkImage(_effectivePhoto!)
                                  : null,
                              child: _effectivePhoto == null
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : null,
                            ),
                    ),
                    // Camera button overlay
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onPickImage,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _green.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 6,
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                    if (_anyConnected)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_anyConnected && _connectedEmail.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(
                          _connectedEmail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'غير متصل بأي حساب',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على أيقونة الكاميرا لتغيير الصورة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ─── Name field
          Padding(
            padding: const EdgeInsets.all(18),
            child: TextField(
              controller: nameController,
              onChanged: onNameChanged,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                labelStyle: TextStyle(
                  color: _green.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded,
                    color: _green),
                filled: true,
                fillColor: const Color(0xFFF5FAF8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: _green.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _green, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account Link Card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountLinkCard extends StatefulWidget {
  const _AccountLinkCard({
    required this.googleAccount,
    required this.emailUser,
    required this.emailController,
    required this.passwordController,
    required this.onGoogleSignIn,
    required this.onGoogleSignOut,
    required this.onEmailRegister,
    required this.onEmailSignIn,
    required this.onEmailSignOut,
  });

  final GoogleSignInAccount? googleAccount;
  final User? emailUser;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGoogleSignOut;
  final VoidCallback onEmailRegister;
  final VoidCallback onEmailSignIn;
  final VoidCallback onEmailSignOut;

  @override
  State<_AccountLinkCard> createState() => _AccountLinkCardState();
}

class _AccountLinkCardState extends State<_AccountLinkCard> {
  bool _showEmailForm = false;
  bool _showPassword = false;
  bool _isRegisterMode = true;

  static const _green = Color(0xFF2F6F5E);
  static const _blue = Color(0xFF2E5CC6);

  @override
  Widget build(BuildContext context) {
    final isGoogleConnected = widget.googleAccount != null;
    final isEmailConnected = widget.emailUser != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2F6F5E).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: const Color(0xFF2F6F5E).withValues(alpha: 0.07),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Google section ───────────────────────────────
          _providerRow(
            context,
            icon: _GoogleIcon(),
            title: 'حساب Google',
            subtitle: widget.googleAccount?.email ?? 'غير متصل',
            isConnected: isGoogleConnected,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: isGoogleConnected
                ? OutlinedButton.icon(
                    onPressed: widget.onGoogleSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج من جوجل'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(
                          color: const Color(0xFFC65D2E)
                              .withValues(alpha: 0.5)),
                      foregroundColor: const Color(0xFFC65D2E),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: widget.onGoogleSignIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول بجوجل'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),

          // ─── Email section ────────────────────────────────
          _providerRow(
            context,
            icon: _EmailIcon(),
            title: 'حساب بالإيميل',
            subtitle: widget.emailUser?.email ?? 'غير متصل',
            isConnected: isEmailConnected,
          ),
          const SizedBox(height: 10),

          if (isEmailConnected) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onEmailSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج من الحساب'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(
                      color: const Color(0xFFC65D2E).withValues(alpha: 0.5)),
                  foregroundColor: const Color(0xFFC65D2E),
                ),
              ),
            ),
          ] else ...[
            if (!_showEmailForm)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _showEmailForm = true;
                        _isRegisterMode = true;
                      }),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('إنشاء حساب'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(
                            color: _blue.withValues(alpha: 0.5)),
                        foregroundColor: _blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() {
                        _showEmailForm = true;
                        _isRegisterMode = false;
                      }),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('تسجيل دخول'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              // Email form
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRegisterMode
                              ? Icons.person_add_rounded
                              : Icons.login_rounded,
                          color: _blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRegisterMode
                              ? 'إنشاء حساب جديد'
                              : 'تسجيل الدخول',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _blue,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showEmailForm = false),
                          child: Icon(Icons.close_rounded,
                              size: 18,
                              color: Colors.grey.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'الإيميل',
                        prefixIcon:
                            const Icon(Icons.email_outlined, color: _blue),
                        filled: true,
                        fillColor: Colors.white,
                        labelStyle:
                            TextStyle(color: _blue.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: _blue.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: widget.passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة السر',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, color: _blue),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(
                              () => _showPassword = !_showPassword),
                          child: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        labelStyle:
                            TextStyle(color: _blue.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: _blue.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _isRegisterMode = !_isRegisterMode;
                            }),
                            child: Text(
                              _isRegisterMode
                                  ? 'عندي حساب بالفعل'
                                  : 'إنشاء حساب جديد',
                              style: TextStyle(
                                  color: _blue.withValues(alpha: 0.7),
                                  fontSize: 12),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: _isRegisterMode
                              ? widget.onEmailRegister
                              : widget.onEmailSignIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: Text(
                            _isRegisterMode ? 'إنشاء' : 'دخول',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (isGoogleConnected || isEmailConnected) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_rounded,
                      size: 16, color: _green.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بياناتك محمية ومُزامَنة تلقائيًا مع Firebase',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _green.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _providerRow(
    BuildContext context, {
    required Widget icon,
    required String title,
    required String subtitle,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isConnected
            ? _green.withValues(alpha: 0.06)
            : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConnected
              ? _green.withValues(alpha: 0.2)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isConnected
                        ? _green
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: isConnected
                      ? const Color(0xFF22C55E)
                      : Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? 'متصل' : 'غير متصل',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isConnected
                        ? const Color(0xFF22C55E)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, 2),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Arial',
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}

class _EmailIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF2E5CC6).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.email_rounded,
        color: Color(0xFF2E5CC6),
        size: 22,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBgColor,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    final bgColor = iconBgColor ?? _green.withValues(alpha: 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 4),
              color: iconColor.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
