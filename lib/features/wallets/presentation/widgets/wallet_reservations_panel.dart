import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import 'wallets_inline_note.dart';

class WalletReservationsPanel extends StatelessWidget {
  const WalletReservationsPanel({
    super.key,
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
              const WalletsInlineNote(
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
