import 'package:flutter/material.dart';

import 'wallets_action_button.dart';

class WalletsOverviewSection extends StatelessWidget {
  const WalletsOverviewSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.sectionIcon,
    required this.addTooltip,
    required this.transferTooltip,
    required this.onAdd,
    required this.onTransfer,
    required this.onMore,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData sectionIcon;
  final String addTooltip;
  final String transferTooltip;
  final VoidCallback onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onMore;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(sectionIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                WalletsActionButton(
                  icon: Icons.swap_horiz_rounded,
                  accent: accent,
                  enabled: onTransfer != null,
                  onTap: onTransfer ?? () {},
                  tooltip: transferTooltip,
                ),
                const SizedBox(width: 8),
                WalletsActionButton(
                  icon: Icons.add_rounded,
                  accent: accent,
                  enabled: true,
                  onTap: onAdd,
                  tooltip: addTooltip,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: accent.withValues(alpha: 0.10)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onMore,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: accent,
                    size: 11,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
