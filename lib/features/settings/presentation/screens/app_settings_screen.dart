// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
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

  static const bg = Color(0xFFF7F7F4);

  static const card = Colors.white;

  static const primary = Color(0xFF2F6F5E);

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  GoogleSignInAccount? _account;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.cubit.state.userName,
    );

    _initGoogle();
  }

  Future<void> _initGoogle() async {
    final cached = _googleSignIn.currentUser;

    if (cached != null) {
      _account = cached;

      if (_nameController.text.trim().isEmpty) {
        _nameController.text = cached.displayName ?? '';
      }

      if (mounted) {
        setState(() {});
      }

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
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(
            height: 10,
          ),
          _sectionLabel(
            'الملف الشخصي',
          ),
          _card(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: primary.withOpacity(.12),
                      backgroundImage: _account?.photoUrl != null
                          ? NetworkImage(
                              _account!.photoUrl!,
                            )
                          : null,
                      child: _account?.photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 44,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 18,
                ),
                TextField(
                  controller: _nameController,
                  onChanged: (v) {
                    widget.cubit.updateSettings(
                      userName: v,
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                    ),
                    filled: true,
                    fillColor: const Color(
                      0xFFF4F6F4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF4F6F4,
                    ),
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          _account?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 22,
          ),
          _sectionLabel(
            'ربط الحساب',
          ),
          _card(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.07),
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حساب Google',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _account?.email ?? 'غير متصل',
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _account == null ? _signInGoogle : _signOutGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(
                        54,
                      ),
                    ),
                    icon: Icon(
                      _account == null ? Icons.login : Icons.logout,
                    ),
                    label: Text(
                      _account == null
                          ? 'تسجيل الدخول بجوجل'
                          : 'تسجيل الخروج من جوجل',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 22,
          ),
          _sectionLabel(
            'البيانات',
          ),
          _card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BackupSettingsScreen(
                      cubit: widget.cubit,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(.12),
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: const Icon(
                        Icons.backup_rounded,
                        color: primary,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة النسخ الاحتياطي',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(
                            height: 4,
                          ),
                          Text(
                            'نسخ محلي و Firebase',
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_left,
                    )
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          _card(
            child: InkWell(
              onTap: _showWipeSheet,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.10),
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_sweep,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مسح بيانات التطبيق',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'إعادة ضبط كاملة',
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_left,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 30,
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(
          26,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 5),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _signInGoogle() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return;
      }

      _nameController.text = account.displayName ?? '';

      widget.cubit.updateSettings(
        userName: _nameController.text,
        googleEmail: account.email,
      );

      setState(() {
        _account = account;
      });
    } catch (e) {
      log('$e');
    }
  }

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();

    widget.cubit.updateSettings(
      googleEmail: '',
    );

    setState(() {
      _account = null;
    });
  }

  Future<void> _showWipeSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        int count = 5;

        return StatefulBuilder(
          builder: (ctx, setState) {
            Future.doWhile(() async {
              if (count == 0) return false;

              await Future.delayed(
                const Duration(
                  seconds: 1,
                ),
              );

              count--;

              if (ctx.mounted) {
                setState(() {});
              }

              return count > 0;
            });

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Text(
                    'تحذير شديد',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'سيتم حذف كل البيانات.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: count > 0 ? null : _finalDeleteConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text(
                        count > 0 ? 'انتظر $count' : 'متابعة الحذف',
                      ),
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

    await Future.delayed(
      const Duration(
        seconds: 2,
      ),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'تأكيد أخير',
        ),
        content: const Text(
          'حذف جميع البيانات؟',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                false,
              );
            },
            child: const Text(
              'إلغاء',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                true,
              );
            },
            child: const Text(
              'حذف',
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await widget.cubit.resetAllData();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف جميع البيانات',
          ),
        ),
      );
    }
  }
}
