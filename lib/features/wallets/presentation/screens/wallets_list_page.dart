import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/wallet_entity.dart';
import '../controllers/wallet_controller.dart';

class WalletsListPage extends StatefulWidget {
  const WalletsListPage({
    super.key,
    required this.cubit,
    required this.walletController,
    required this.onWalletsChanged,
    this.onWalletTap,
  });

  final AppCubit cubit;
  final WalletController walletController;
  final Future<void> Function() onWalletsChanged;
  final void Function(WalletEntity)? onWalletTap;

  @override
  State<WalletsListPage> createState() => _WalletsListPageState();
}

class _WalletsListPageState extends State<WalletsListPage> {
  bool _reorderMode = false;
  final Set<String> _coloredWallets = {};

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
        color: isColored
            ? accent.withValues(alpha: 0.88)
            : accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border:
            Border.all(color: accent.withValues(alpha: isColored ? 0.0 : 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isColored ? 0.28 : 0.08),
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
                    : accent.withValues(alpha: 0.15),
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
                          : accent.withValues(alpha: 0.65),
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isColored
                            ? Colors.white.withValues(alpha: 0.22)
                            : accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isColored
                            ? Icons.invert_colors_off_rounded
                            : Icons.color_lens_rounded,
                        size: 16,
                        color: isColored ? Colors.white : accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: state.wallets.indexOf(wallet),
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
          title: const Text(
            'كل المحافظ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
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
          builder: (context, snapshot) {
            final state = snapshot.data ?? widget.cubit.state;
            final wallets = widget.walletController.wallets;

            if (_reorderMode) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF165B47).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_handle_rounded,
                          size: 16,
                          color: Color(0xFF165B47),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اسحب الكروت لتغيير الترتيب. اضغط أيقونة اللون لتبديل مظهر الكارت.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF165B47),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: wallets.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered = List<WalletEntity>.from(wallets);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);
                        await widget.walletController.reorderWallets(reordered);
                        await widget.onWalletsChanged();
                      },
                      itemBuilder: (context, index) =>
                          _buildCard(state, wallets[index]),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: wallets.length,
              itemBuilder: (context, index) =>
                  _buildCard(state, wallets[index]),
            );
          },
        ),
      ),
    );
  }
}
