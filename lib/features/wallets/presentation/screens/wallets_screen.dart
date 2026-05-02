import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/wallet_entity.dart';
import 'jar_editor_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final wallets = state.wallets;
        final jars = _orderedJars(state.budgetSetup.linkedWallets);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            _overviewSection(
              title: 'المحافظ',
              subtitle: 'الأماكن الحقيقية للفلوس: كاش، بنك، أو أي محفظة فعلية.',
              height: 376,
              addTooltip: 'إضافة محفظة',
              transferTooltip: 'تحويل بين المحافظ',
              onAdd: () => _openWalletEditor(),
              onTransfer: wallets.length < 2 ? null : _openWalletTransferDialog,
              onMore: () => _openWalletsPage(state),
              child: wallets.isEmpty
                  ? const _EmptyStateCard(
                      title: 'لا توجد محافظ بعد',
                      subtitle: 'أضف محفظة فعلية لتسجيل الفلوس الحقيقية.',
                    )
                  : Column(
                      children: wallets.take(2).map((wallet) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _compactWalletTile(state, wallet),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 18),
            _overviewSection(
              title: 'الحصالات',
              subtitle: 'أوعية تنظيم ذهني للفلوس الموجودة أصلًا داخل المحافظ.',
              height: 360,
              addTooltip: 'إضافة حصالة',
              transferTooltip: 'تحويل بين الحصالات',
              onAdd: () => _openJarEditor(),
              onTransfer:
                  jars.length < 2 && state.budgetSetup.allocations.isEmpty
                      ? null
                      : () => _openInternalTransferDialog(),
              onMore: () => _openJarsPage(state),
              child: jars.isEmpty
                  ? const _EmptyStateCard(
                      title: 'لا توجد حصالات بعد',
                      subtitle:
                          'ابدأ بحصالة التوفير أو أنشئ حصالة لتنظيم جزء من فلوسك.',
                    )
                  : Column(
                      children: jars.take(2).map((jar) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _compactJarTile(state, jar),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewSection({
    required String title,
    required String subtitle,
    required double height,
    required String addTooltip,
    required String transferTooltip,
    required VoidCallback onAdd,
    required VoidCallback? onTransfer,
    required VoidCallback onMore,
    required Widget child,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE0D7C8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF165B47).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: addTooltip,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onTransfer,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      tooltip: transferTooltip,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6E6558),
                height: 1.35,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
            OutlinedButton(
              onPressed: onMore,
              child: const Text('المزيد'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _compactWalletTile(AppStateEntity state, WalletEntity wallet) {
    final reserved = _walletReservedAmount(state, wallet.id);
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    return _compactEntityTile(
      title: wallet.name,
      subtitle: reserved > 0
          ? 'محجوز للحصالات: ${reserved.toStringAsFixed(2)}'
          : 'الرصيد متاح بالكامل',
      amount: wallet.balance,
      icon: wallet.icon ?? 'account_balance_wallet',
      accent: accent,
      onTap: () => _openWalletDetailsSheet(wallet),
    );
  }

  Widget _compactJarTile(AppStateEntity state, LinkedWalletEntity jar) {
    final distribution = _jarDistribution(state, jar.id);
    final accent = _parseColor(jar.iconColor);
    return _compactEntityTile(
      title: jar.name,
      subtitle: distribution.isEmpty
          ? 'لم يتم توزيعها على محافظ بعد'
          : 'موزعة على ${distribution.length} محفظة',
      amount: jar.balance,
      icon: jar.icon,
      accent: accent,
      onTap: () => _openJarDetailsSheet(jar),
    );
  }

  Widget _compactEntityTile({
    required String title,
    required String subtitle,
    required double amount,
    required String icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            _iconBubble(
              iconName: icon,
              colorHex: _hexFromColor(accent),
              size: 44,
            ),
            const SizedBox(width: 10),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF756C5C),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _softMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: accent.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softIconAction(
    IconData icon, {
    required VoidCallback onTap,
    required String tooltip,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
      ),
    );
  }

  Widget _walletCard(AppStateEntity state, WalletEntity wallet) {
    final reserved = _walletReservedAmount(state, wallet.id);
    final available = wallet.balance - reserved;
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final hasMultipleWallets = state.wallets.length >= 2;

    return InkWell(
      onTap: () => _openWalletDetailsSheet(wallet),
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top row: icon + name + actions ──
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        wallet.icon ?? 'account_balance_wallet',
                        color: accent,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasMultipleWallets)
                        _softIconAction(
                          Icons.swap_horiz_rounded,
                          onTap: _openWalletTransferDialog,
                          tooltip: 'تحويل بين المحافظ',
                          accent: accent,
                        ),
                      const SizedBox(width: 6),
                      _softIconAction(
                        Icons.add_circle_outline_rounded,
                        onTap: () => _openWalletAllocateToJarDialog(wallet),
                        tooltip: 'تخصيص مبلغ',
                        accent: accent,
                      ),
                      const SizedBox(width: 6),
                      _softIconAction(
                        Icons.settings_outlined,
                        onTap: () => _openWalletEditor(current: wallet),
                        tooltip: 'تعديل',
                        accent: accent,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Balance row ──
              Row(
                children: [
                  Expanded(
                    child: _softMetric(
                      label: 'إجمالي الرصيد',
                      value: wallet.balance.toStringAsFixed(2),
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _softMetric(
                      label: 'الصافي المتاح',
                      value: available.toStringAsFixed(2),
                      accent: accent,
                    ),
                  ),
                  if (reserved > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _softMetric(
                        label: 'محجوز',
                        value: reserved.toStringAsFixed(2),
                        accent: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jarCard(AppStateEntity state, LinkedWalletEntity jar) {
    final accent = _parseColor(jar.iconColor);
    final distribution = _jarDistribution(state, jar.id);

    return InkWell(
      onTap: () => _openJarDetailsSheet(jar),
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top row: icon + name + actions ──
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        jar.icon,
                        color: accent,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      jar.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (distribution.isNotEmpty)
                        _softIconAction(
                          Icons.swap_horiz_rounded,
                          onTap: () =>
                              _openInternalTransferDialog(sourceJar: jar),
                          tooltip: 'تحويل داخلي',
                          accent: accent,
                        ),
                      const SizedBox(width: 6),
                      _softIconAction(
                        Icons.add_circle_outline_rounded,
                        onTap: () => _openJarAdjustmentDialog(
                          jar: jar,
                          mode: _JarAdjustmentMode.allocate,
                        ),
                        tooltip: 'تخصيص للحصالة',
                        accent: accent,
                      ),
                      const SizedBox(width: 6),
                      _softIconAction(
                        Icons.settings_outlined,
                        onTap: () => _openJarEditor(current: jar),
                        tooltip: 'تعديل',
                        accent: accent,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Metrics row ──
              Row(
                children: [
                  Expanded(
                    child: _softMetric(
                      label: 'رصيد الحصالة',
                      value: jar.balance.toStringAsFixed(2),
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _softMetric(
                      label: 'شهري مخطط',
                      value: jar.monthlyAmount.toStringAsFixed(2),
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _softMetric(
                      label: 'المحافظ المرتبطة',
                      value: distribution.length.toString(),
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWalletsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WalletsListPage(
          cubit: widget.cubit,
          onWalletTap: (w) => _openWalletDetailsSheet(w),
        ),
      ),
    );
  }

  void _openJarsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _JarsListPage(
          cubit: widget.cubit,
          onJarTap: (j) => _openJarDetailsSheet(j),
        ),
      ),
    );
  }

  Future<void> _openWalletDetailsSheet(WalletEntity wallet) async {
    final state = widget.cubit.state;
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final reserved = _walletReservedAmount(state, wallet.id);
    final available = wallet.balance - reserved;
    final reservations = _walletReservations(state, wallet.id); // jarId -> amount

    final walletTx = state.transactions
        .where((t) =>
            t.walletId == wallet.id ||
            t.toWalletId == wallet.id ||
            t.fromWalletId == wallet.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        var showJars = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // ── Hero Card ──────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.95),
                          accent.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top: icon + name + actions ──────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: AppIconPickerDialog.iconWidgetForName(
                                    wallet.icon ?? 'account_balance_wallet',
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wallet.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${wallet.balance.toStringAsFixed(2)} جنيه',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _iconAction(
                                Icons.settings_outlined,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _openWalletEditor(current: wallet);
                                },
                                tooltip: 'تعديل',
                              ),
                              const SizedBox(width: 6),
                              _iconAction(
                                Icons.add_circle_outline_rounded,
                                onTap: () => _openWalletAllocateToJarDialog(wallet),
                                tooltip: 'تخصيص للحصالة',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Metrics row ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: _glassMetric(
                                  label: 'الرصيد الكلي',
                                  value: wallet.balance.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'الصافي المتاح',
                                  value: available.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'الحصالات',
                                  value: reservations.length.toString(),
                                  accent: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Wide toggle button ───────────────────────────
                        GestureDetector(
                          onTap: () => setSheet(() => showJars = !showJars),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedRotation(
                                  turns: showJars ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 260),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  showJars
                                      ? 'إخفاء التخصيصات'
                                      : 'عرض التخصيصات للحصالات',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Jar allocations panel (below card) ─────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: showJars
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.savings_rounded,
                                        color: accent,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'التخصيصات للحصالات',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (reservations.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBF1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.10),
                                      ),
                                    ),
                                    child: const Text(
                                      'لا يوجد تخصيص لأي حصالة من هذه المحفظة حتى الآن.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF8A7F72),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else
                                  ...reservations.entries.map((e) {
                                    final matchedJars = state
                                        .budgetSetup.linkedWallets
                                        .where((j) => j.id == e.key)
                                        .toList();
                                    final jarName = matchedJars.isEmpty
                                        ? 'حصالة'
                                        : matchedJars.first.name;
                                    final jarIcon = matchedJars.isEmpty
                                        ? 'savings'
                                        : matchedJars.first.icon;
                                    final jarAccent = matchedJars.isEmpty
                                        ? accent
                                        : _parseColor(matchedJars.first.iconColor);
                                    final ratio = reserved <= 0
                                        ? 0.0
                                        : (e.value / reserved).clamp(0.0, 1.0);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBF1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: accent.withValues(alpha: 0.14),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: jarAccent.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(11),
                                                  ),
                                                  child: Center(
                                                    child: AppIconPickerDialog.iconWidgetForName(
                                                      jarIcon,
                                                      color: jarAccent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    jarName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  e.value.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    color: jarAccent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 5,
                                                backgroundColor: accent.withValues(alpha: 0.12),
                                                valueColor: AlwaysStoppedAnimation(jarAccent),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                  // ── Transactions ───────────────────────────────────────
                  _sectionHeader('المعاملات'),
                  const SizedBox(height: 10),
                  if (walletTx.isEmpty)
                    const _InlineNote(
                      text: 'لا توجد حركات مسجلة على هذه المحفظة حتى الآن.',
                    )
                  else
                    ...walletTx.take(30).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TransactionTile(
                              transaction: t,
                              onTap: () => openTransactionDetailsSheet(
                                ctx,
                                cubit: widget.cubit,
                                transaction: t,
                              ),
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

  Future<void> _openJarDetailsSheet(LinkedWalletEntity jar) async {
    final state = widget.cubit.state;
    final distribution = _jarDistribution(state, jar.id);
    final relevantTransactions = state.transactions
        .where((t) =>
            t.toWalletId == jar.id ||
            t.walletId == jar.id ||
            (t.type == 'income' && t.toWalletId == jar.id))
        .where((t) =>
            t.transferType == 'jar-allocation' ||
            t.transferType == 'jar-allocation-cancel' ||
            t.transferType == 'jar-allocation-spend' ||
            t.transferType == 'jar-funding' ||
            t.transferType == 'allocation-to-jar' ||
            t.transferType == 'jar-to-allocation' ||
            (t.type == 'income' && t.budgetScope == 'within-budget'))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final accent = _parseColor(jar.iconColor);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        var showWallets = false;
        return StatefulBuilder(
        builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                // ── Hero Card ──────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Top: icon + name + actions ──────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: AppIconPickerDialog.iconWidgetForName(
                                  jar.icon,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    jar.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r'${jar.balance.toStringAsFixed(2)} جنيه',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _iconAction(Icons.settings_outlined, onTap: () {
                              Navigator.of(ctx).pop();
                              _openJarEditor(current: jar);
                            }, tooltip: 'تعديل'),
                            const SizedBox(width: 6),
                            _iconAction(
                              Icons.add_circle_outline_rounded,
                              onTap: () => _openJarAdjustmentDialog(
                                jar: jar,
                                mode: _JarAdjustmentMode.allocate,
                              ),
                              tooltip: 'تخصيص للحصالة',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ── Metrics row ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: _glassMetric(
                                label: 'الرصيد الكلي',
                                value: jar.balance.toStringAsFixed(2),
                                accent: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _glassMetric(
                                label: 'شهري مخطط',
                                value: jar.monthlyAmount.toStringAsFixed(2),
                                accent: accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _glassMetric(
                                label: 'المحافظ',
                                value: distribution.length.toString(),
                                accent: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Wide toggle button ───────────────────────────
                      GestureDetector(
                        onTap: () => setSheet(() => showWallets = !showWallets),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedRotation(
                                turns: showWallets ? 0.5 : 0,
                                duration: const Duration(milliseconds: 260),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                showWallets
                                    ? 'إخفاء التخصيصات'
                                    : 'عرض التخصيصات من المحافظ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Wallet distribution panel (below card) ─────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: showWallets
                      ? Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: accent,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'التخصيصات من المحافظ',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (distribution.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBF1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.10),
                                    ),
                                  ),
                                  child: const Text(
                                    'لا يوجد تخصيص من أي محفظة لهذه الحصالة حتى الآن.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF8A7F72),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                ...distribution.entries.map((e) {
                                  final matchedWallets = state.wallets
                                      .where((w) => w.id == e.key)
                                      .toList();
                                  final walletName = matchedWallets.isEmpty
                                      ? 'محفظة'
                                      : matchedWallets.first.name;
                                  final walletIcon = matchedWallets.isEmpty
                                      ? 'account_balance_wallet'
                                      : (matchedWallets.first.icon ??
                                          'account_balance_wallet');
                                  final ratio = jar.balance <= 0
                                      ? 0.0
                                      : (e.value / jar.balance).clamp(0.0, 1.0);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBF1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.14),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: accent.withValues(alpha: 0.10),
                                                  borderRadius: BorderRadius.circular(11),
                                                ),
                                                child: Center(
                                                  child: AppIconPickerDialog.iconWidgetForName(
                                                    walletIcon,
                                                    color: accent,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  walletName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                e.value.toStringAsFixed(2),
                                                style: TextStyle(
                                                  color: accent,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _openJarAdjustmentDialog(
                                                  jar: jar,
                                                  mode: _JarAdjustmentMode.cancel,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: accent.withValues(alpha: 0.10),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'إلغاء',
                                                    style: TextStyle(
                                                      color: accent,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 5,
                                              backgroundColor: accent.withValues(alpha: 0.12),
                                              valueColor: AlwaysStoppedAnimation(accent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),
                // ── Transactions ───────────────────────────────────────
                _sectionHeader('المعاملات'),
                const SizedBox(height: 10),
                if (relevantTransactions.isEmpty)
                  const _InlineNote(
                    text: 'لا توجد حركات مسجلة على هذه الحصالة حتى الآن.',
                  )
                else
                  ...relevantTransactions.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TransactionTile(
                        transaction: t,
                        onTap: () => openTransactionDetailsSheet(
                          ctx,
                          cubit: widget.cubit,
                          transaction: t,
                        ),
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

  Future<void> _openJarAdjustmentDialog({
    required LinkedWalletEntity jar,
    required _JarAdjustmentMode mode,
  }) async {
    final state = widget.cubit.state;
    final sourceDistribution = _jarDistribution(state, jar.id);
    final availableWallets = mode == _JarAdjustmentMode.allocate
        ? state.wallets
        : state.wallets
            .where((wallet) => (sourceDistribution[wallet.id] ?? 0) > 0)
            .toList();
    if (availableWallets.isEmpty) return;

    final accent = _parseColor(jar.iconColor);
    var walletId = availableWallets.first.id;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedReserved = sourceDistribution[walletId] ?? 0;
          final isAllocate = mode == _JarAdjustmentMode.allocate;
          final title = isAllocate ? 'تخصيص مبلغ للحصالة' : 'إلغاء تخصيص من الحصالة';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4C9B8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.95),
                              accent.withValues(alpha: 0.70),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: AppIconPickerDialog.iconWidgetForName(
                            jar.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                            Text(
                              jar.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8A7F72),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Form card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Wallet picker
                        Text(
                          'المحفظة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.16),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: walletId,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(14),
                              items: availableWallets.map((w) {
                                return DropdownMenuItem<String>(
                                  value: w.id,
                                  child: Text(
                                    w.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => walletId = value);
                              },
                            ),
                          ),
                        ),
                        if (!isAllocate) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 14, color: accent),
                                const SizedBox(width: 6),
                                Text(
                                  'المتاح للإلغاء: ${selectedReserved.toStringAsFixed(2)} جنيه',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Amount field
                        Text(
                          'المبلغ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            filled: true,
                            fillColor: const Color(0xFFFFFBF1),
                            suffixText: 'جنيه',
                            suffixStyle: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.16)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.16)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: accent, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Notes field
                        Text(
                          'ملاحظات (اختياري)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'أضف ملاحظة...',
                            filled: true,
                            fillColor: const Color(0xFFFFFBF1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.16)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.16)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: accent, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: accent.withValues(alpha: 0.30)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            foregroundColor: const Color(0xFF8A7F72),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final amount = double.tryParse(
                                    amountController.text.trim()) ??
                                0;
                            if (amount <= 0) return;
                            if (!isAllocate && amount > selectedReserved) return;

                            await widget.cubit.addTransaction(
                              type: isAllocate ? 'transfer' : 'expense',
                              walletId: !isAllocate ? jar.id : null,
                              fromWalletId: walletId,
                              toWalletId: jar.id,
                              amount: amount,
                              transferType: isAllocate
                                  ? 'jar-allocation'
                                  : 'jar-allocation-cancel',
                              notes: notesController.text.trim().isEmpty
                                  ? (isAllocate
                                      ? 'تخصيص ${amount.toStringAsFixed(2)} إلى ${jar.name}'
                                      : 'إلغاء تخصيص ${amount.toStringAsFixed(2)} من ${jar.name}')
                                  : notesController.text.trim(),
                            );

                            if (jar.id == 'linked-savings-default') {
                              await widget.cubit.applySavingsReserve(
                                walletId: walletId,
                                amount: amount,
                                action: isAllocate ? 'allocate' : 'cancel',
                              );
                            }

                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            isAllocate ? 'تأكيد التخصيص' : 'تأكيد الإلغاء',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openInternalTransferDialog({
    LinkedWalletEntity? sourceJar,
  }) async {
    final state = widget.cubit.state;
    final jars = _orderedJars(state.budgetSetup.linkedWallets);
    final allocations = state.budgetSetup.allocations;
    if (jars.isEmpty) {
      return;
    }

    var mode = jars.length > 1
        ? _InternalTransferMode.jarToJar
        : allocations.isNotEmpty
            ? _InternalTransferMode.allocationToJar
            : _InternalTransferMode.jarToJar;
    var sourceJarId = sourceJar?.id ?? jars.first.id;
    var targetJarId = jars
        .firstWhere(
          (jar) => jar.id != sourceJarId,
          orElse: () => jars.first,
        )
        .id;
    var sourceAllocationId = allocations.isEmpty ? '' : allocations.first.id;
    var targetAllocationId = allocations.isEmpty ? '' : allocations.first.id;
    var walletId = state.wallets.isEmpty ? '' : state.wallets.first.id;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedSourceJar = jars.firstWhere(
            (jar) => jar.id == sourceJarId,
            orElse: () => jars.first,
          );
          final sourceDistribution = _jarDistribution(
            widget.cubit.state,
            selectedSourceJar.id,
          );
          final sourceWallets = widget.cubit.state.wallets
              .where((wallet) => (sourceDistribution[wallet.id] ?? 0) > 0)
              .toList();
          if (sourceWallets.isNotEmpty &&
              !sourceWallets.any((wallet) => wallet.id == walletId)) {
            walletId = sourceWallets.first.id;
          }
          final targetJars =
              jars.where((jar) => jar.id != sourceJarId).toList();
          if (targetJars.isNotEmpty &&
              !targetJars.any((jar) => jar.id == targetJarId)) {
            targetJarId = targetJars.first.id;
          }
          final availableAmount =
              mode == _InternalTransferMode.jarToAllocation ||
                      mode == _InternalTransferMode.jarToJar
                  ? (sourceDistribution[walletId] ?? 0)
                  : double.infinity;
          return AlertDialog(
            title: const Text('تحويل داخلي'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<_InternalTransferMode>(
                  segments: [
                    ButtonSegment(
                      value: _InternalTransferMode.jarToJar,
                      label: Text('حصالة لحصالة'),
                      enabled: jars.length > 1,
                    ),
                    ButtonSegment(
                      value: _InternalTransferMode.jarToAllocation,
                      label: Text('حصالة لمخصص'),
                      enabled: allocations.isNotEmpty,
                    ),
                    ButtonSegment(
                      value: _InternalTransferMode.allocationToJar,
                      label: Text('مخصص لحصالة'),
                      enabled: allocations.isNotEmpty,
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) {
                    setDialogState(() {
                      mode = value.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (mode == _InternalTransferMode.jarToJar ||
                    mode == _InternalTransferMode.jarToAllocation) ...[
                  DropdownButtonFormField<String>(
                    value: sourceJarId,
                    decoration: const InputDecoration(labelText: 'من حصالة'),
                    items: jars
                        .map(
                          (jar) => DropdownMenuItem<String>(
                            value: jar.id,
                            child: Text(jar.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => sourceJarId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (mode == _InternalTransferMode.allocationToJar) ...[
                  DropdownButtonFormField<String>(
                    value:
                        sourceAllocationId.isEmpty ? null : sourceAllocationId,
                    decoration: const InputDecoration(labelText: 'من مخصص'),
                    items: allocations
                        .map(
                          (allocation) => DropdownMenuItem<String>(
                            value: allocation.id,
                            child: Text(allocation.name),
                          ),
                        )
                        .toList(),
                    onChanged: allocations.isEmpty
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => sourceAllocationId = value);
                          },
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  value: walletId.isEmpty ? null : walletId,
                  decoration: const InputDecoration(
                    labelText: 'من أي محفظة فعلية؟',
                  ),
                  items: (mode == _InternalTransferMode.allocationToJar
                          ? widget.cubit.state.wallets
                          : sourceWallets)
                      .map(
                        (wallet) => DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Text(
                            mode == _InternalTransferMode.allocationToJar
                                ? wallet.name
                                : '${wallet.name} • ${(sourceDistribution[wallet.id] ?? 0).toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => walletId = value);
                  },
                ),
                const SizedBox(height: 10),
                if (mode == _InternalTransferMode.jarToAllocation) ...[
                  DropdownButtonFormField<String>(
                    value:
                        targetAllocationId.isEmpty ? null : targetAllocationId,
                    decoration: const InputDecoration(labelText: 'إلى مخصص'),
                    items: allocations
                        .map(
                          (allocation) => DropdownMenuItem<String>(
                            value: allocation.id,
                            child: Text(allocation.name),
                          ),
                        )
                        .toList(),
                    onChanged: allocations.isEmpty
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => targetAllocationId = value);
                          },
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    value: targetJarId,
                    decoration: const InputDecoration(
                      labelText: 'إلى أي حصالة؟',
                    ),
                    items: (mode == _InternalTransferMode.jarToJar
                            ? targetJars
                            : jars)
                        .map(
                          (jar) => DropdownMenuItem<String>(
                            value: jar.id,
                            child: Text(jar.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => targetJarId = value);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    mode == _InternalTransferMode.allocationToJar
                        ? 'اختر المحفظة الفعلية التي سيظهر عليها حجز الحصالة.'
                        : 'المتاح نقله من هذه المحفظة داخل الحصالة ${availableAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0;
                  if (amount <= 0 ||
                      walletId.isEmpty ||
                      (mode != _InternalTransferMode.allocationToJar &&
                          amount > availableAmount) ||
                      (mode == _InternalTransferMode.jarToAllocation &&
                          targetAllocationId.isEmpty) ||
                      (mode == _InternalTransferMode.allocationToJar &&
                          sourceAllocationId.isEmpty)) {
                    return;
                  }

                  final currentState = widget.cubit.state;
                  final transferSourceJar =
                      currentState.budgetSetup.linkedWallets.firstWhere(
                    (jar) => jar.id == sourceJarId,
                  );
                  final targetJar =
                      currentState.budgetSetup.linkedWallets.firstWhere(
                    (jar) => jar.id == targetJarId,
                  );
                  final note = notesController.text.trim().isEmpty
                      ? switch (mode) {
                          _InternalTransferMode.jarToJar =>
                            'تحويل داخلي من ${transferSourceJar.name} إلى ${targetJar.name}',
                          _InternalTransferMode.jarToAllocation =>
                            'تحويل من ${transferSourceJar.name} إلى مخصص',
                          _InternalTransferMode.allocationToJar =>
                            'تحويل من مخصص إلى ${targetJar.name}',
                        }
                      : notesController.text.trim();

                  if (mode == _InternalTransferMode.allocationToJar) {
                    await widget.cubit.addTransaction(
                      type: 'transfer',
                      fromWalletId: walletId,
                      toWalletId: targetJar.id,
                      allocationId: sourceAllocationId,
                      amount: amount,
                      transferType: 'allocation-to-jar',
                      notes: note,
                    );
                    if (targetJar.id == 'linked-savings-default') {
                      await widget.cubit.applySavingsReserve(
                        walletId: walletId,
                        amount: amount,
                        action: 'allocate',
                      );
                    }
                  } else if (mode == _InternalTransferMode.jarToAllocation) {
                    await widget.cubit.addTransaction(
                      type: 'transfer',
                      walletId: transferSourceJar.id,
                      fromWalletId: walletId,
                      allocationId: targetAllocationId,
                      amount: amount,
                      transferType: 'jar-to-allocation',
                      notes: note,
                    );
                    if (transferSourceJar.id == 'linked-savings-default') {
                      await widget.cubit.applySavingsReserve(
                        walletId: walletId,
                        amount: amount,
                        action: 'cancel',
                      );
                    }
                  } else {
                    await widget.cubit.addTransaction(
                      type: 'expense',
                      walletId: transferSourceJar.id,
                      fromWalletId: walletId,
                      toWalletId: transferSourceJar.id,
                      amount: amount,
                      transferType: 'jar-allocation-cancel',
                      notes: note,
                    );
                    if (transferSourceJar.id == 'linked-savings-default') {
                      await widget.cubit.applySavingsReserve(
                        walletId: walletId,
                        amount: amount,
                        action: 'cancel',
                      );
                    }

                    await widget.cubit.addTransaction(
                      type: 'transfer',
                      fromWalletId: walletId,
                      toWalletId: targetJar.id,
                      amount: amount,
                      transferType: 'jar-allocation',
                      notes: note,
                    );
                    if (targetJar.id == 'linked-savings-default') {
                      await widget.cubit.applySavingsReserve(
                        walletId: walletId,
                        amount: amount,
                        action: 'allocate',
                      );
                    }
                  }

                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('تنفيذ التحويل'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openWalletAllocateToJarDialog(WalletEntity wallet) async {
    final jars = _orderedJars(widget.cubit.state.budgetSetup.linkedWallets);
    if (jars.isEmpty) {
      return;
    }

    var jarId = jars.first.id;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تخصيص من المحفظة إلى حصالة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: jarId,
                decoration: const InputDecoration(labelText: 'الحصالة'),
                items: jars
                    .map(
                      (jar) => DropdownMenuItem<String>(
                        value: jar.id,
                        child: Text(jar.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => jarId = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  return;
                }
                final targetJar = jars.firstWhere((jar) => jar.id == jarId);
                await widget.cubit.addTransaction(
                  type: 'transfer',
                  fromWalletId: wallet.id,
                  toWalletId: targetJar.id,
                  amount: amount,
                  transferType: 'jar-allocation',
                  notes: notesController.text.trim().isEmpty
                      ? 'تخصيص ${amount.toStringAsFixed(2)} من ${wallet.name} إلى ${targetJar.name}'
                      : notesController.text.trim(),
                );
                if (targetJar.id == 'linked-savings-default') {
                  await widget.cubit.applySavingsReserve(
                    walletId: wallet.id,
                    amount: amount,
                    action: 'allocate',
                  );
                }
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWalletTransferDialog() async {
    final wallets = widget.cubit.state.wallets;
    if (wallets.length < 2) {
      return;
    }
    var fromId = wallets.first.id;
    var toId = wallets[1].id;
    final amountController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تحويل بين المحافظ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: fromId,
                decoration: const InputDecoration(labelText: 'من محفظة'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => fromId = value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: toId,
                decoration: const InputDecoration(labelText: 'إلى محفظة'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => toId = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0 || fromId == toId) {
                  return;
                }
                await widget.cubit.addTransaction(
                  type: 'transfer',
                  amount: amount,
                  fromWalletId: fromId,
                  toWalletId: toId,
                  transferType: 'wallet-to-wallet',
                  notes: 'تحويل بين المحافظ',
                );
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('تنفيذ'),
            ),
          ],
        ),
      ),
    );
  }

  void _openWalletEditor({WalletEntity? current}) {
    final nameController = TextEditingController(text: current?.name ?? '');
    final balanceController =
        TextEditingController(text: (current?.balance ?? 0).toStringAsFixed(0));
    var selectedColor = current?.iconColor ?? '#165b47';
    var selectedIcon = current?.icon ?? 'account_balance_wallet';

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? 'إضافة محفظة' : 'تعديل المحفظة'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم المحفظة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الفعلي',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await AppIconPickerDialog.show(
                        context,
                        initialIconName: selectedIcon,
                        initialColorHex: selectedColor,
                        title: 'اختيار أيقونة المحفظة',
                      );
                      if (picked == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedIcon = picked.iconName;
                        selectedColor = picked.colorHex;
                      });
                    },
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('اختيار الأيقونة واللون'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (current != null)
              TextButton(
                onPressed: () async {
                  await widget.cubit.deleteWallet(current.id);
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(this.context).pop();
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(color: Color(0xFFB3261E)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final balance =
                    double.tryParse(balanceController.text.trim()) ?? 0;
                if (name.isEmpty) {
                  return;
                }
                if (current == null) {
                  await widget.cubit.addWallet(
                    name: name,
                    openingBalance: balance,
                    icon: selectedIcon,
                    iconColor: selectedColor,
                  );
                } else {
                  await widget.cubit.updateWallet(
                    id: current.id,
                    name: name,
                    balance: balance,
                    icon: selectedIcon,
                    iconColor: selectedColor,
                  );
                }
                if (!mounted) {
                  return;
                }
                Navigator.of(this.context).pop();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _openJarEditor({LinkedWalletEntity? current}) {
    final incomes = widget.cubit.state.budgetSetup.incomeSources;
    Navigator.of(context)
        .push<JarEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: JarEditorScreen(
            current: current,
            incomeSources: incomes,
            idFactory: (prefix) =>
                '$prefix-${DateTime.now().millisecondsSinceEpoch}',
          ),
        ),
      ),
    )
        .then((result) async {
      if (result == null) {
        return;
      }
      if (result.deleteRequested && current != null) {
        if (current.id == 'linked-savings-default') {
          return;
        }
        await widget.cubit.deleteLinkedWallet(current.id);
        return;
      }
      final entity = result.entity;
      if (entity == null) {
        return;
      }
      if (current == null) {
        await widget.cubit.addLinkedWallet(entity);
      } else {
        await widget.cubit.updateLinkedWallet(entity);
      }
    });
  }

  Map<String, double> _walletReservations(
      AppStateEntity state, String walletId) {
    final result = <String, double>{};
    for (final transaction in state.transactions) {
      if (transaction.fromWalletId != walletId ||
          transaction.toWalletId == null) {
        continue;
      }
      final jarId = transaction.toWalletId!;
      if (transaction.transferType == 'jar-allocation' ||
          transaction.transferType == 'jar-funding' ||
          transaction.transferType == 'allocation-to-jar') {
        result[jarId] = (result[jarId] ?? 0) + transaction.amount;
      } else if (transaction.transferType == 'jar-allocation-cancel' ||
          transaction.transferType == 'jar-allocation-spend' ||
          transaction.transferType == 'jar-to-allocation') {
        result[jarId] = (result[jarId] ?? 0) - transaction.amount;
      }
    }
    for (final transaction in state.transactions) {
      if (transaction.type == 'income' &&
          transaction.budgetScope == 'within-budget' &&
          transaction.walletId == walletId &&
          transaction.toWalletId != null) {
        final jarId = transaction.toWalletId!;
        result[jarId] = (result[jarId] ?? 0) + transaction.amount;
      }
    }
    result.removeWhere((key, value) => value <= 0);
    return result;
  }

  Map<String, double> _jarDistribution(AppStateEntity state, String jarId) {
    final result = <String, double>{};
    for (final transaction in state.transactions) {
      if (transaction.toWalletId != jarId && transaction.walletId != jarId) {
        continue;
      }
      final walletId = transaction.fromWalletId ?? transaction.walletId;
      if (walletId == null) {
        continue;
      }
      if (transaction.transferType == 'jar-allocation' ||
          transaction.transferType == 'jar-funding' ||
          transaction.transferType == 'allocation-to-jar' ||
          (transaction.type == 'income' &&
              transaction.budgetScope == 'within-budget' &&
              transaction.toWalletId == jarId)) {
        result[walletId] = (result[walletId] ?? 0) + transaction.amount;
      } else if (transaction.transferType == 'jar-allocation-cancel' ||
          transaction.transferType == 'jar-allocation-spend' ||
          transaction.transferType == 'jar-to-allocation') {
        result[walletId] = (result[walletId] ?? 0) - transaction.amount;
      }
    }
    result.removeWhere((key, value) => value <= 0);
    return result;
  }

  double _walletReservedAmount(AppStateEntity state, String walletId) {
    return _walletReservations(state, walletId)
        .values
        .fold<double>(0, (sum, item) => sum + item);
  }

  bool _isVirtualJarTransaction(TransactionEntity transaction) {
    return transaction.transferType == 'jar-allocation' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend' ||
        transaction.transferType == 'jar-funding' ||
        transaction.transferType == 'allocation-to-jar' ||
        transaction.transferType == 'jar-to-allocation';
  }

  Widget _iconBubble({
    required String iconName,
    required String colorHex,
    double size = 48,
  }) {
    final color = _parseColor(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: AppIconPickerDialog.iconWidgetForName(
          iconName,
          color: color,
          size: size * 0.42,
        ),
      ),
    );
  }

  Widget _glassMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(
    IconData icon, {
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  MapEntry<String, String> _heroMetric(String label, String value) {
    return MapEntry(label, value);
  }

  Widget _heroCard({
    required String title,
    required String icon,
    required String colorHex,
    required VoidCallback onEdit,
    required List<MapEntry<String, String>> rows,
  }) {
    final accent = _parseColor(colorHex);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'تعديل',
              ),
              const Spacer(),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _iconBubble(iconName: icon, colorHex: colorHex, size: 64),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    row.key,
                    style: const TextStyle(
                      color: Color(0xFF6E6558),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }

  Color _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
    return Color(0xFF000000 | value);
  }

  String _hexFromColor(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  List<LinkedWalletEntity> _orderedJars(List<LinkedWalletEntity> jars) {
    final sorted = List<LinkedWalletEntity>.from(jars);
    sorted.sort((a, b) {
      if (a.id == 'linked-savings-default' &&
          b.id != 'linked-savings-default') {
        return -1;
      }
      if (b.id == 'linked-savings-default' &&
          a.id != 'linked-savings-default') {
        return 1;
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
}

enum _JarAdjustmentMode { allocate, cancel }

enum _InternalTransferMode { jarToJar, jarToAllocation, allocationToJar }

// ── Wallets full-page list with reorder + style toggle ─────────────────────

class _WalletsListPage extends StatefulWidget {
  const _WalletsListPage({required this.cubit, this.onWalletTap});
  final AppCubit cubit;
  final void Function(WalletEntity)? onWalletTap;
  @override
  State<_WalletsListPage> createState() => _WalletsListPageState();
}

class _WalletsListPageState extends State<_WalletsListPage> {
  bool _reorderMode = false;
  final Set<String> _coloredWallets = {};

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF165B47);
  }

  Widget _buildCard(AppStateEntity state, WalletEntity wallet) {
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final isColored = _coloredWallets.contains(wallet.id);
    final available = wallet.balance - wallet.reservedForSavings;

    final card = Container(
      key: ValueKey(wallet.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isColored ? accent.withValues(alpha: 0.88) : const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: isColored ? 0.0 : 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isColored ? 0.28 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: isColored
                    ? Colors.white.withValues(alpha: 0.22)
                    : accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  wallet.icon ?? 'account_balance_wallet',
                  color: isColored ? Colors.white : accent,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isColored ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${wallet.balance.toStringAsFixed(2)} • متاح ${available.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isColored
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF7A725F),
                    ),
                  ),
                ],
              ),
            ),
            if (_reorderMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (_coloredWallets.contains(wallet.id)) {
                        _coloredWallets.remove(wallet.id);
                      } else {
                        _coloredWallets.add(wallet.id);
                      }
                    }),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isColored
                            ? Colors.white.withValues(alpha: 0.22)
                            : accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isColored ? Icons.invert_colors_off_rounded : Icons.color_lens_rounded,
                        size: 16,
                        color: isColored ? Colors.white : accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: state.wallets.indexOf(wallet),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isColored
                            ? Colors.white.withValues(alpha: 0.15)
                            : accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 18,
                        color: isColored ? Colors.white : accent,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    return _reorderMode
        ? card
        : GestureDetector(
            onTap: () => widget.onWalletTap?.call(wallet),
            child: card,
          );
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBF1),
          surfaceTintColor: Colors.transparent,
          title: const Text('كل المحافظ', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_rounded : Icons.tune_rounded,
                color: _reorderMode ? const Color(0xFF165B47) : null,
              ),
              tooltip: _reorderMode ? 'تم' : 'إعدادات',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
            if (!_reorderMode)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'إضافة محفظة',
                onPressed: () {},
              ),
          ],
        ),
        body: StreamBuilder<AppStateEntity>(
          stream: widget.cubit.stream,
          initialData: widget.cubit.state,
          builder: (ctx, snap) {
            final state = snap.data ?? widget.cubit.state;
            final wallets = state.wallets;

            if (_reorderMode) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF165B47).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle_rounded, size: 16, color: Color(0xFF165B47)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اسحب الكروت لتغيير الترتيب. اضغط أيقونة اللون لتبديل مظهر الكارت.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF165B47)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: wallets.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered = List<WalletEntity>.from(wallets);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);
                        widget.cubit.reorderWallets(reordered);
                      },
                      itemBuilder: (ctx, i) => _buildCard(state, wallets[i]),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: wallets.length,
              itemBuilder: (ctx, i) => _buildCard(state, wallets[i]),
            );
          },
        ),
      ),
    );
  }
}

// ── Jars full-page list with reorder + style toggle ────────────────────────

class _JarsListPage extends StatefulWidget {
  const _JarsListPage({required this.cubit, this.onJarTap});
  final AppCubit cubit;
  final void Function(LinkedWalletEntity)? onJarTap;
  @override
  State<_JarsListPage> createState() => _JarsListPageState();
}

class _JarsListPageState extends State<_JarsListPage> {
  bool _reorderMode = false;
  final Set<String> _coloredJars = {};

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF0F766E);
  }

  List<LinkedWalletEntity> _orderedJars(List<LinkedWalletEntity> jars) {
    return jars;
  }

  Widget _buildCard(List<LinkedWalletEntity> allJars, LinkedWalletEntity jar) {
    final accent = _parseColor(jar.iconColor);
    final isColored = _coloredJars.contains(jar.id);
    final idx = allJars.indexOf(jar);

    final card = Padding(
      key: ValueKey(jar.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: Ink(
        decoration: BoxDecoration(
          color: isColored ? accent.withValues(alpha: 0.88) : const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: isColored ? 0.0 : 0.22)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isColored ? 0.28 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isColored
                      ? Colors.white.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    jar.icon,
                    color: isColored ? Colors.white : accent,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jar.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isColored ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${jar.balance.toStringAsFixed(2)} • شهري ${jar.monthlyAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isColored
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF7A725F),
                      ),
                    ),
                  ],
                ),
              ),
              if (_reorderMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_coloredJars.contains(jar.id)) {
                          _coloredJars.remove(jar.id);
                        } else {
                          _coloredJars.add(jar.id);
                        }
                      }),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.22)
                              : accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isColored ? Icons.invert_colors_off_rounded : Icons.color_lens_rounded,
                          size: 16,
                          color: isColored ? Colors.white : accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: idx,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.15)
                              : accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 18,
                          color: isColored ? Colors.white : accent,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    return _reorderMode
        ? card
        : GestureDetector(
            onTap: () => widget.onJarTap?.call(jar),
            child: card,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBF1),
          surfaceTintColor: Colors.transparent,
          title: const Text('كل الحصالات', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_rounded : Icons.tune_rounded,
                color: _reorderMode ? const Color(0xFF165B47) : null,
              ),
              tooltip: _reorderMode ? 'تم' : 'إعدادات',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
            if (!_reorderMode)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'إضافة حصالة',
                onPressed: () {},
              ),
          ],
        ),
        body: StreamBuilder<AppStateEntity>(
          stream: widget.cubit.stream,
          initialData: widget.cubit.state,
          builder: (ctx, snap) {
            final state = snap.data ?? widget.cubit.state;
            final jars = _orderedJars(state.budgetSetup.linkedWallets);

            if (_reorderMode) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle_rounded, size: 16, color: Color(0xFF0F766E)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اسحب الكروت لتغيير الترتيب. اضغط أيقونة اللون لتبديل مظهر الكارت.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: jars.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered = List<LinkedWalletEntity>.from(jars);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);
                        widget.cubit.reorderJars(reordered);
                      },
                      itemBuilder: (ctx, i) => _buildCard(jars, jars[i]),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: jars.length,
              itemBuilder: (ctx, i) => _buildCard(jars, jars[i]),
            );
          },
        ),
      ),
    );
  }
}

// class _SectionShell extends StatelessWidget {
//   const _SectionShell({
//     required this.title,
//     required this.subtitle,
//     required this.child,
//     required this.actionLabel,
//     required this.onAction,
//     this.trailing,
//   });

//   final String title;
//   final String subtitle;
//   final Widget child;
//   final String actionLabel;
//   final VoidCallback onAction;
//   final Widget? trailing;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFFBF1),
//         borderRadius: BorderRadius.circular(30),
//         border: Border.all(color: const Color(0xFFE0D7C8)),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF165B47).withValues(alpha: 0.05),
//             blurRadius: 20,
//             offset: const Offset(0, 12),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               if (trailing != null) trailing!,
//               const Spacer(),
//               Expanded(
//                 flex: 6,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     Text(
//                       title,
//                       textAlign: TextAlign.right,
//                       style: const TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     Text(
//                       subtitle,
//                       textAlign: TextAlign.right,
//                       style: const TextStyle(
//                         color: Color(0xFF6E6558),
//                         height: 1.5,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           child,
//           const SizedBox(height: 10),
//           SizedBox(
//             width: double.infinity,
//             child: OutlinedButton.icon(
//               onPressed: onAction,
//               icon: const Icon(Icons.add_rounded),
//               label: Text(actionLabel),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _DetailsSheetShell extends StatelessWidget {
//   const _DetailsSheetShell({required this.child});

//   final Widget child;

//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.56,
//       minChildSize: 0.42,
//       maxChildSize: 0.96,
//       snap: true,
//       snapSizes: const [0.56, 0.96],
//       builder: (context, controller) => Container(
//         decoration: const BoxDecoration(
//           color: Color(0xFFFCF7EC),
//           borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
//         ),
//         child: child,
//       ),
//     );
//   }
// }

class _SimpleValueTile extends StatelessWidget {
  const _SimpleValueTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.colorHex,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String icon;
  final String colorHex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      0xFF000000 |
          (int.tryParse(colorHex.replaceAll('#', ''), radix: 16) ?? 0x165B47),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7A725F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        icon,
                        color: color,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNegative = transaction.type == 'expense' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend';
    final label = switch (transaction.transferType) {
      'jar-allocation' => 'تخصيص للحصالة',
      'jar-allocation-cancel' => 'إلغاء تخصيص',
      'jar-allocation-spend' => 'سحب من المحجوز',
      'jar-funding' => 'تمويل تلقائي للحصالة',
      'wallet-to-wallet' => 'تحويل بين المحافظ',
      _ => transaction.notes ??
          switch (transaction.type) {
            'income' => 'دخل',
            'expense' => 'مصروف',
            _ => 'تحويل',
          },
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4DCCF)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isNegative ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: isNegative
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF165B47),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
                    style: const TextStyle(color: Color(0xFF7D7461)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}

class _WalletReservationsPanel extends StatelessWidget {
  const _WalletReservationsPanel({
    required this.totalReserved,
    required this.reservations,
    required this.jars,
    required this.onOpenJar,
  });

  final double totalReserved;
  final Map<String, double> reservations;
  final List<LinkedWalletEntity> jars;
  final void Function(LinkedWalletEntity jar) onOpenJar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DCCF)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            'مخصص للحصالات',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            totalReserved > 0
                ? totalReserved.toStringAsFixed(2)
                : 'لا يوجد مبلغ محجوز',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF756C5C),
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF165B47).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF165B47),
            ),
          ),
          children: [
            if (reservations.isEmpty)
              const _InlineNote(
                text:
                    'لا يوجد أي مبلغ محجوز من هذه المحفظة داخل الحصالات حتى الآن.',
              )
            else
              ...reservations.entries.map((entry) {
                final jar = jars.firstWhere(
                  (item) => item.id == entry.key,
                  orElse: () => LinkedWalletEntity(
                    id: entry.key,
                    name: 'حصالة',
                    balance: entry.value,
                    monthlyAmount: 0,
                    executionDay: 1,
                    fundingSource: '',
                    funding: const [],
                    icon: 'savings',
                    iconColor: '#0f766e',
                    automationType: 'confirm',
                    categories: const [],
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReservationRow(
                    title: jar.name,
                    amount: entry.value,
                    icon: jar.icon,
                    colorHex: jar.iconColor,
                    onTap: () => onOpenJar(jar),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ReservationRow extends StatelessWidget {
  const _ReservationRow({
    required this.title,
    required this.amount,
    required this.icon,
    required this.colorHex,
    required this.onTap,
  });

  final String title;
  final double amount;
  final String icon;
  final String colorHex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      0xFF000000 |
          (int.tryParse(colorHex.replaceAll('#', ''), radix: 16) ?? 0x165B47),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEDF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF72685A),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4DCCF)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 34, color: Color(0xFF7A725F)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF72685A),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
