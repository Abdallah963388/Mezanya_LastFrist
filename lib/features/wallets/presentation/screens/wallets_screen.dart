import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/wallet_entity.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/wallets_empty_state_card.dart';
import '../widgets/wallets_inline_note.dart';
import '../widgets/wallets_overview_section.dart';
import '../widgets/wallets_transaction_tile.dart';
import 'jars_list_page.dart';
import 'jar_editor_screen.dart';
import 'wallets_list_page.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({
    super.key,
    required this.cubit,
    required this.walletController,
  });

  final AppCubit cubit;
  final WalletController walletController;

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  static const _green = Color(0xFF165B47);
  static const _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    widget.walletController.addListener(_handleWalletsChanged);
  }

  @override
  void dispose() {
    widget.walletController.removeListener(_handleWalletsChanged);
    super.dispose();
  }

  void _handleWalletsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final wallets = widget.walletController.wallets;
        final jars = _orderedJars(state.budgetSetup.linkedWallets);

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
          children: [
            const SizedBox(height: 16),
            // ── Wallets section ─────────────────────────────────────────
            WalletsOverviewSection(
              title: 'المحافظ',
              subtitle: 'الأماكن الحقيقية للفلوس: كاش، بنك، أو أي محفظة.',
              accent: _green,
              sectionIcon: Icons.account_balance_wallet_rounded,
              addTooltip: 'إضافة محفظة',
              transferTooltip: 'تحويل بين المحافظ',
              onAdd: () => _openWalletEditor(),
              onTransfer: wallets.length < 2 ? null : _openWalletTransferDialog,
              onMore: () => _openWalletsPage(state),
              child: wallets.isEmpty
                  ? const WalletsEmptyStateCard(
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
            const SizedBox(height: 16),

            // ── Jars section ────────────────────────────────────────────
            WalletsOverviewSection(
              title: 'الحصالات',
              subtitle: 'أوعية تنظيم ذهني للفلوس داخل المحافظ.',
              accent: _teal,
              sectionIcon: Icons.savings_rounded,
              addTooltip: 'إضافة حصالة',
              transferTooltip: 'تحويل بين الحصالات',
              onAdd: () => _openJarEditor(),
              onTransfer:
                  jars.length < 2 && state.budgetSetup.allocations.isEmpty
                      ? null
                      : () => _openInternalTransferDialog(),
              onMore: () => _openJarsPage(state),
              child: jars.isEmpty
                  ? const WalletsEmptyStateCard(
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
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _refreshLegacyState() async {
    await widget.cubit.refreshFromRepository();
    await widget.walletController.refresh();
  }

  Future<void> _addTransactionAndRefresh({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? toAllocationId,
    String? budgetScope,
    String? incomeSourceId,
    String? categoryId,
    String? transferType,
    String? notes,
    DateTime? createdAt,
    String? details,
  }) async {
    await widget.cubit.addTransaction(
      walletId: walletId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      type: type,
      allocationId: allocationId,
      toAllocationId: toAllocationId,
      budgetScope: budgetScope,
      incomeSourceId: incomeSourceId,
      categoryId: categoryId,
      transferType: transferType,
      notes: notes,
      createdAt: createdAt,
      details: details,
    );
    await widget.walletController.refresh();
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  icon,
                  color: accent,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: accent.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.chevron_left_rounded,
                  color: accent.withValues(alpha: 0.45),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openWalletsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletsListPage(
          cubit: widget.cubit,
          walletController: widget.walletController,
          onWalletsChanged: _refreshLegacyState,
          onWalletTap: (w) => _openWalletDetailsSheet(w),
        ),
      ),
    );
  }

  void _openJarsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JarsListPage(
          cubit: widget.cubit,
          onJarTap: (j) => _openJarDetailsSheet(j),
        ),
      ),
    );
  }

  Future<void> _openWalletDetailsSheet(WalletEntity wallet) async {
    final state = widget.cubit.state;
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final reservations =
        _walletReservations(state, wallet.id); // jarId -> amount
    final allocationReservations =
        _walletAllocationReservations(state, wallet.id);
    final reserved = _walletReservedAmount(state, wallet.id);
    final available = wallet.balance - reserved;

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
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
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
                                onTap: () =>
                                    _openWalletAllocateToJarDialog(wallet),
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
                                  label: 'الحجوزات',
                                  value: (reservations.length +
                                          allocationReservations.length)
                                      .toString(),
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
                                      ? 'إخفاء الحجوزات'
                                      : 'عرض حجوزات الفلوس',
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
                                      'حجوزات الفلوس',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (allocationReservations.isEmpty &&
                                    reservations.isEmpty)
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
                                      'لا يوجد أي مبلغ محجوز من هذه المحفظة حتى الآن.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF8A7F72),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else ...[
                                  if (allocationReservations.isNotEmpty) ...[
                                    _reservationGroupTitle(
                                      'المخصصات',
                                      accent,
                                    ),
                                    ...allocationReservations.entries.map((e) {
                                      final matchedAllocations = state
                                          .budgetSetup.allocations
                                          .where((a) => a.id == e.key)
                                          .toList();
                                      final allocationName =
                                          matchedAllocations.isEmpty
                                              ? 'مخصص'
                                              : matchedAllocations.first.name;
                                      final allocationIcon =
                                          matchedAllocations.isEmpty
                                              ? 'category'
                                              : matchedAllocations.first.icon;
                                      final allocationAccent =
                                          matchedAllocations.isEmpty
                                              ? accent
                                              : _parseColor(matchedAllocations
                                                  .first.iconColor);
                                      final ratio = reserved <= 0
                                          ? 0.0
                                          : (e.value / reserved)
                                              .clamp(0.0, 1.0);
                                      return _reservationTile(
                                        title: allocationName,
                                        amount: e.value,
                                        iconName: allocationIcon,
                                        accent: allocationAccent,
                                        ratio: ratio,
                                      );
                                    }),
                                  ],
                                  if (reservations.isNotEmpty) ...[
                                    _reservationGroupTitle(
                                      'الحصالات',
                                      accent,
                                    ),
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
                                          : _parseColor(
                                              matchedJars.first.iconColor);
                                      final ratio = reserved <= 0
                                          ? 0.0
                                          : (e.value / reserved)
                                              .clamp(0.0, 1.0);
                                      return _reservationTile(
                                        title: jarName,
                                        amount: e.value,
                                        iconName: jarIcon,
                                        accent: jarAccent,
                                        ratio: ratio,
                                      );
                                    }),
                                  ],
                                ],
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
                    const WalletsInlineNote(
                      text: 'لا توجد حركات مسجلة على هذه المحفظة حتى الآن.',
                    )
                  else
                    ...walletTx.take(30).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                          child: WalletsTransactionTile(
                              transaction: t,
                              state: state,
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
        .where((t) => t.toWalletId == jar.id || t.walletId == jar.id)
        .where((t) =>
            t.transferType == 'jar-allocation' ||
            t.transferType == 'jar-allocation-cancel' ||
            t.transferType == 'jar-allocation-spend' ||
            t.transferType == 'jar-funding' ||
            t.transferType == 'allocation-to-jar' ||
            t.transferType == 'jar-to-allocation')
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
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
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
                          onTap: () =>
                              setSheet(() => showWallets = !showWallets),
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
                                      ? 'إخفاء مصادر الحجز'
                                      : 'عرض مصادر حجز الفلوس',
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
                                      'مصادر حجز الفلوس',
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
                                      'لا يوجد حجز من أي محفظة لهذه الحصالة حتى الآن.',
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
                                        : (e.value / jar.balance)
                                            .clamp(0.0, 1.0);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBF1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                accent.withValues(alpha: 0.14),
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
                                                    color: accent.withValues(
                                                        alpha: 0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            11),
                                                  ),
                                                  child: Center(
                                                    child: AppIconPickerDialog
                                                        .iconWidgetForName(
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
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                                  onTap: () =>
                                                      _openJarAdjustmentDialog(
                                                    jar: jar,
                                                    mode: _JarAdjustmentMode
                                                        .cancel,
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: accent.withValues(
                                                          alpha: 0.10),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      'إلغاء',
                                                      style: TextStyle(
                                                        color: accent,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 5,
                                                backgroundColor: accent
                                                    .withValues(alpha: 0.12),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        accent),
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
                    const WalletsInlineNote(
                      text: 'لا توجد حركات مسجلة على هذه الحصالة حتى الآن.',
                    )
                  else
                    ...relevantTransactions.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                          child: WalletsTransactionTile(
                          transaction: t,
                          state: state,
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
          final title =
              isAllocate ? 'تخصيص مبلغ للحصالة' : 'إلغاء تخصيص من الحصالة';

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
                              borderSide: BorderSide(color: accent, width: 1.5),
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
                              borderSide: BorderSide(color: accent, width: 1.5),
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
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                    0;
                            if (amount <= 0) return;
                            if (!isAllocate && amount > selectedReserved) {
                              return;
                            }

                            await _addTransactionAndRefresh(
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
                    await _addTransactionAndRefresh(
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
                    await _addTransactionAndRefresh(
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
                    await _addTransactionAndRefresh(
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

                    await _addTransactionAndRefresh(
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
                await _addTransactionAndRefresh(
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
                await _addTransactionAndRefresh(
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
                  await widget.walletController.deleteWallet(current.id);
                  await _refreshLegacyState();
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
                  await widget.walletController.addWallet(
                    name: name,
                    openingBalance: balance,
                    icon: selectedIcon,
                    iconColor: selectedColor,
                  );
                } else {
                  await widget.walletController.updateWallet(
                    id: current.id,
                    name: name,
                    balance: balance,
                    icon: selectedIcon,
                    iconColor: selectedColor,
                  );
                }
                await _refreshLegacyState();
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

  Widget _reservationGroupTitle(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _reservationTile({
    required String title,
    required double amount,
    required String iconName,
    required Color accent,
    required double ratio,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      iconName,
                      color: accent,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    color: accent,
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
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _walletAllocationReservations(
    AppStateEntity state,
    String walletId,
  ) {
    final result = <String, double>{};
    final incomeSourceIds = state.budgetSetup.incomeSources
        .where((source) => source.targetWalletId == walletId)
        .map((source) => source.id)
        .toSet();

    for (final allocation in state.budgetSetup.allocations) {
      final planned = allocation.funding
          .where((fund) => incomeSourceIds.contains(fund.incomeSourceId))
          .fold<double>(0, (sum, fund) => sum + fund.plannedAmount);
      if (planned <= 0) continue;

      final spent = state.transactions
          .where((transaction) =>
              transaction.walletId == walletId &&
              transaction.allocationId == allocation.id &&
              transaction.type == 'expense')
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final remaining = planned - spent;
      if (remaining > 0) {
        result[allocation.id] = remaining;
      }
    }

    return result;
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
          transaction.transferType == 'allocation-to-jar') {
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
    final jarReserved = _walletReservations(state, walletId)
        .values
        .fold<double>(0, (sum, item) => sum + item);
    final allocationReserved = _walletAllocationReservations(state, walletId)
        .values
        .fold<double>(0, (sum, item) => sum + item);
    return jarReserved + allocationReserved;
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
