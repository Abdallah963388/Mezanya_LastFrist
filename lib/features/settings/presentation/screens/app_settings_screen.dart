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

  static const _bg = Color(0xFFFFFBF1);
  static const _green = Color(0xFF2F6F5E);
  static const _greenLight = Color(0xFF165b47);
  static const _surface = Color(0xFFFFFFFF);

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _account != null;
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_account?.displayName ?? 'مستخدم');
    final initials = displayName.isNotEmpty ? displayName[0] : 'م';

    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SizedBox(height: 8),

          // ── الملف الشخصي ──────────────────────────────────────
          _SectionHeader(label: 'الملف الشخصي', icon: Icons.person_rounded),
          _ProfileCard(
            account: _account,
            initials: initials,
            nameController: _nameController,
            isConnected: isConnected,
            onNameChanged: (v) =>
                widget.cubit.updateSettings(userName: v),
          ),

          const SizedBox(height: 20),

          // ── ربط الحساب ────────────────────────────────────────
          _SectionHeader(label: 'ربط الحساب', icon: Icons.link_rounded),
          _AccountLinkCard(
            account: _account,
            onSignIn: _signInGoogle,
            onSignOut: _signOutGoogle,
          ),

          const SizedBox(height: 20),

          // ── البيانات ──────────────────────────────────────────
          _SectionHeader(label: 'البيانات', icon: Icons.storage_rounded),
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
            iconBgColor: const Color(0xFFC65D2E).withValues(alpha: 0.1),
            title: 'مسح بيانات التطبيق',
            subtitle: 'إعادة ضبط كاملة لجميع البيانات',
            titleColor: const Color(0xFFC65D2E),
            onTap: _showWipeSheet,
          ),
        ],
      ),
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
    } catch (e) {
      log('$e');
    }
  }

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();
    widget.cubit.updateSettings(googleEmail: '');
    setState(() => _account = null);
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
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 36,
                      color: Color(0xFFC65D2E),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'تحذير',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'سيتم حذف جميع البيانات بشكل نهائي\nولا يمكن التراجع عن هذا الإجراء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurfaceVariant,
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
                        count > 0 ? 'انتظر $count ثواني...' : 'متابعة الحذف',
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
    required this.account,
    required this.initials,
    required this.nameController,
    required this.isConnected,
    required this.onNameChanged,
  });

  final GoogleSignInAccount? account;
  final String initials;
  final TextEditingController nameController;
  final bool isConnected;
  final ValueChanged<String> onNameChanged;

  static const _green = Color(0xFF2F6F5E);

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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF2F6F5E), Color(0xFF1A4A3A)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        backgroundImage: account?.photoUrl != null
                            ? NetworkImage(account!.photoUrl!)
                            : null,
                        child: account?.photoUrl == null
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (isConnected)
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
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isConnected)
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
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          account?.email ?? '',
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
                      'غير متصل بحساب جوجل',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Fields
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
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  color: _green,
                ),
                filled: true,
                fillColor: const Color(0xFFF5FAF8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _green.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _green, width: 1.5),
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

class _AccountLinkCard extends StatelessWidget {
  const _AccountLinkCard({
    required this.account,
    required this.onSignIn,
    required this.onSignOut,
  });

  final GoogleSignInAccount? account;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  static const _green = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    final isConnected = account != null;

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
        children: [
          // Google status row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isConnected
                  ? _green.withValues(alpha: 0.06)
                  : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isConnected
                    ? _green.withValues(alpha: 0.2)
                    : const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  child: Center(
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'G',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Arial',
                              color: Color(0xFF4285F4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حساب Google',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account?.email ?? 'غير متصل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isConnected
                              ? _green
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
                        isConnected
                            ? Icons.circle
                            : Icons.circle_outlined,
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
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: isConnected
                ? OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج من جوجل'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: const Color(0xFFC65D2E).withValues(alpha: 0.5),
                      ),
                      foregroundColor: const Color(0xFFC65D2E),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول بجوجل'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
          ),

          if (isConnected) ...[
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
                  Icon(
                    Icons.cloud_done_rounded,
                    size: 16,
                    color: _green.withValues(alpha: 0.7),
                  ),
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
    final bgColor =
        iconBgColor ?? _green.withValues(alpha: 0.1);

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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
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
